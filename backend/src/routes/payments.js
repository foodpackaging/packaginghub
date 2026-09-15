const express = require('express');
const crypto = require('crypto');
const Order = require('../models/Order');
const { requireAuth } = require('../middleware/auth');
const { serializeOrder } = require('../utils/serializers');
const { notifyPaymentSuccess, notifyPaymentFailed } = require('../services/orderNotifications');
const { asyncHandler } = require('../utils/asyncHandler');
const env = require('../config/env');

const { dispatch } = require('../services/dispatch');

const router = express.Router();

function timingSafeEqualStrings(a, b) {
  const bufA = Buffer.from(String(a || ''), 'utf8');
  const bufB = Buffer.from(String(b || ''), 'utf8');
  return bufA.length === bufB.length && crypto.timingSafeEqual(bufA, bufB);
}

/**
 * Creates the Razorpay-side order for an existing app order. The amount comes
 * only from the order's own server-computed totalAmount — the client can no
 * longer decide what Razorpay charges. The Razorpay order id is written back
 * onto the app Order immediately, which is what lets the webhook (below)
 * resolve payment events even if the client never calls /verify.
 */
router.post('/razorpay/create-order', requireAuth, asyncHandler(async (req, res) => {
  const { app_order_id: appOrderId } = req.body;
  if (!appOrderId) return res.status(400).json({ error: 'app_order_id is required' });

  const order = await Order.findOne({ _id: appOrderId, userId: req.user._id });
  if (!order) return res.status(404).json({ error: 'Order not found' });
  if (order.paymentStatus === 'paid') return res.status(400).json({ error: 'This order has already been paid' });

  const { keyId, keySecret } = env.razorpay;
  if (!keyId || !keySecret) {
    return res.status(500).json({ error: 'Razorpay keys are not configured' });
  }

  const auth = Buffer.from(`${keyId}:${keySecret}`).toString('base64');
  const response = await fetch('https://api.razorpay.com/v1/orders', {
    method: 'POST',
    headers: { Authorization: `Basic ${auth}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      // order.totalAmount is server-computed (see routes/orders.js) — never a
      // client-supplied figure.
      amount: Math.round(order.totalAmount * 100),
      currency: 'INR',
      receipt: order.orderNumber,
    }),
  });

  const orderData = await response.json();
  if (!response.ok) {
    return res.status(400).json({ error: orderData.error?.description || 'Failed to create Razorpay order' });
  }

  order.razorpayOrderId = orderData.id;
  await order.save();

  res.json(orderData);
}));

router.post('/razorpay/verify', requireAuth, asyncHandler(async (req, res) => {
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

  if (!timingSafeEqualStrings(generatedSignature, signature)) {
    return res.status(400).json({ error: 'Invalid payment signature' });
  }

  // The signature alone proves *a* Razorpay order/payment pair is genuine —
  // it doesn't prove it belongs to *this* app order. Requiring orderId to
  // match the one this order's own /create-order call stored stops a
  // customer replaying a valid signature from one of their paid orders
  // against a different, unpaid one of theirs.
  const order = await Order.findOneAndUpdate(
    { _id: appOrderId, userId: req.user._id, razorpayOrderId: orderId },
    {
      paymentStatus: 'paid',
      razorpayPaymentId: paymentId,
      razorpaySignature: signature,
    },
    { new: true }
  );
  if (!order) return res.status(404).json({ error: 'Order not found' });

  await dispatch(() => notifyPaymentSuccess(order));

  res.json({ success: true, order: serializeOrder(order) });
}));

/**
 * Records a gateway-side payment failure for a prepaid order.
 *
 * The order row is created before Razorpay's sheet opens, so a failure leaves a
 * real order stuck at `pending`. Flagging it here is what lets the customer see
 * "payment failed, try again" instead of an order that silently never moves.
 * The app skips this call when the customer simply dismissed the sheet.
 */
router.post('/razorpay/failed', requireAuth, asyncHandler(async (req, res) => {
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
}));

/**
 * Authoritative payment reconciliation. The client-side /verify call above is
 * an immediate-UX convenience — this webhook is the source of truth: it fires
 * even if the app crashed, lost network, or was never given the chance to
 * call /verify after a successful charge.
 *
 * Idempotent by construction: both branches only update an order that isn't
 * already 'paid', so a redelivered event (Razorpay retries webhooks that
 * don't 2xx, and can occasionally redeliver regardless) is a harmless no-op
 * the second time — no duplicate notification, no double-processing.
 */
router.post('/razorpay/webhook', asyncHandler(async (req, res) => {
  const { webhookSecret } = env.razorpay;
  if (!webhookSecret) {
    console.error('[payments] RAZORPAY_WEBHOOK_SECRET is not configured — rejecting webhook delivery.');
    return res.status(500).json({ error: 'Webhook is not configured' });
  }

  const signature = req.headers['x-razorpay-signature'];
  if (!signature || !req.rawBody) {
    return res.status(400).json({ error: 'Missing signature' });
  }

  const expectedSignature = crypto.createHmac('sha256', webhookSecret).update(req.rawBody).digest('hex');
  if (!timingSafeEqualStrings(expectedSignature, signature)) {
    return res.status(400).json({ error: 'Invalid webhook signature' });
  }

  const event = req.body?.event;
  const paymentEntity = req.body?.payload?.payment?.entity;
  const razorpayOrderId = paymentEntity?.order_id;

  // Signature is valid but there's nothing to reconcile (a non-payment event,
  // or a malformed payload) — acknowledge so Razorpay doesn't keep retrying.
  if (!razorpayOrderId) return res.json({ ok: true });

  if (event === 'payment.captured') {
    const order = await Order.findOneAndUpdate(
      { razorpayOrderId, paymentStatus: { $ne: 'paid' } },
      { paymentStatus: 'paid', razorpayPaymentId: paymentEntity.id },
      { new: true }
    );
    if (order) await dispatch(() => notifyPaymentSuccess(order));
  } else if (event === 'payment.failed') {
    const order = await Order.findOneAndUpdate(
      { razorpayOrderId, paymentStatus: { $ne: 'paid' } },
      { paymentStatus: 'failed' },
      { new: true }
    );
    if (order) await dispatch(() => notifyPaymentFailed(order, paymentEntity.error_description));
  }

  res.json({ ok: true });
}));

module.exports = router;
