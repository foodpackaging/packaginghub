const express = require('express');
const crypto = require('crypto');
const Order = require('../models/Order');
const { requireAuth } = require('../middleware/auth');
const { serializeOrder } = require('../utils/serializers');
const { notifyPaymentSuccess, notifyPaymentFailed } = require('../services/orderNotifications');
const env = require('../config/env');

const { dispatch } = require('../services/dispatch');

const router = express.Router();

router.post('/razorpay/create-order', requireAuth, async (req, res) => {
  const { amount, receipt } = req.body;
  if (!amount) return res.status(400).json({ error: 'amount is required' });

  const { keyId, keySecret } = env.razorpay;
  if (!keyId || !keySecret) {
    return res.status(500).json({ error: 'Razorpay keys are not configured' });
  }

  const auth = Buffer.from(`${keyId}:${keySecret}`).toString('base64');
  const response = await fetch('https://api.razorpay.com/v1/orders', {
    method: 'POST',
    headers: { Authorization: `Basic ${auth}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      amount: Math.round(amount * 100),
      currency: 'INR',
      receipt: receipt || `rcpt_${Date.now()}`,
    }),
  });

  const orderData = await response.json();
  if (!response.ok) {
    return res.status(400).json({ error: orderData.error?.description || 'Failed to create Razorpay order' });
  }

  res.json(orderData);
});

router.post('/razorpay/verify', requireAuth, async (req, res) => {
  const { order_id: orderId, payment_id: paymentId, signature, app_order_id: appOrderId } = req.body;
  if (!orderId || !paymentId || !signature || !appOrderId) {
    return res.status(400).json({ error: 'order_id, payment_id, signature, and app_order_id are required' });
  }

  const { keySecret } = env.razorpay;
  if (!keySecret) return res.status(500).json({ error: 'Razorpay keys are not configured' });

  const generatedSignature = crypto
    .createHmac('sha256', keySecret)
    .update(`${orderId}|${paymentId}`)
    .digest('hex');

  if (generatedSignature !== signature) {
    return res.status(400).json({ error: 'Invalid payment signature' });
  }

  const order = await Order.findOneAndUpdate(
    { _id: appOrderId, userId: req.user._id },
    {
      paymentStatus: 'paid',
      razorpayOrderId: orderId,
      razorpayPaymentId: paymentId,
      razorpaySignature: signature,
    },
    { new: true }
  );
  if (!order) return res.status(404).json({ error: 'Order not found' });

  await dispatch(() => notifyPaymentSuccess(order));

  res.json({ success: true, order: serializeOrder(order) });
});

/**
 * Records a gateway-side payment failure for a prepaid order.
 *
 * The order row is created before Razorpay's sheet opens, so a failure leaves a
 * real order stuck at `pending`. Flagging it here is what lets the customer see
 * "payment failed, try again" instead of an order that silently never moves.
 * The app skips this call when the customer simply dismissed the sheet.
 */
router.post('/razorpay/failed', requireAuth, async (req, res) => {
  const { app_order_id: appOrderId, reason } = req.body;
  if (!appOrderId) return res.status(400).json({ error: 'app_order_id is required' });

  const order = await Order.findOneAndUpdate(
    { _id: appOrderId, userId: req.user._id, paymentStatus: { $ne: 'paid' } },
    { paymentStatus: 'failed' },
    { new: true }
  );
  if (!order) return res.status(404).json({ error: 'Order not found' });

  await dispatch(() => notifyPaymentFailed(order, reason));

  res.json({ success: true, order: serializeOrder(order) });
});

module.exports = router;
