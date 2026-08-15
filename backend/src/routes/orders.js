const express = require('express');
const Order = require('../models/Order');
const Address = require('../models/Address');
const { requireAuth, requireAdmin } = require('../middleware/auth');
const { serializeOrder, buildAddressSnapshot } = require('../utils/serializers');
const { shallowCamelize, camelizeArray } = require('../utils/caseConvert');
const {
  notifyOrderPlaced,
  notifyPaymentSuccess,
  notifyPaymentFailed,
  notifyStatusChanged,
  notifyEtaChanged,
} = require('../services/orderNotifications');

const { dispatch } = require('../services/dispatch');

const router = express.Router();

function generateOrderNumber() {
  const now = new Date();
  const y = now.getFullYear();
  const m = String(now.getMonth() + 1).padStart(2, '0');
  const d = String(now.getDate()).padStart(2, '0');
  return `ORD-${y}${m}${d}-${now.getTime()}`;
}

router.post('/', requireAuth, async (req, res) => {
  const {
    delivery_method,
    payment_method,
    subtotal,
    discount_amount,
    delivery_charge,
    total_amount,
    coupon_code,
    address_id,
    delivery_address,
    estimated_delivery_time,
    eta_minutes,
    notes,
    items,
  } = req.body;

  if (!delivery_method || !payment_method || !Array.isArray(items) || items.length === 0) {
    return res.status(400).json({ error: 'delivery_method, payment_method, and items are required' });
  }

  // Snapshot the address at placement time. Copying the values (rather than
  // storing a reference) is what keeps an old order showing the address it was
  // actually delivered to, even after the business edits or deletes that address.
  let addressSnapshot = delivery_address || {};
  if (address_id) {
    const address = await Address.findOne({ _id: address_id, userId: req.user._id });
    if (!address) return res.status(400).json({ error: 'Selected delivery address not found' });

    addressSnapshot = buildAddressSnapshot(address, {
      // Contact details fall back to the account when the address doesn't override them.
      contact_name: address.contactName || [req.user.firstName, req.user.lastName].filter(Boolean).join(' ').trim(),
      contact_phone: address.contactPhone || req.user.phone || '',
      email: req.user.email,
      company_type: req.user.companyType,
      gst_number: req.user.gstNumber,
    });
  }

  if (delivery_method === 'delivery' && !addressSnapshot.line1 && !addressSnapshot.address) {
    return res.status(400).json({ error: 'A delivery address is required for delivery orders' });
  }

  const order = await Order.create({
    orderNumber: generateOrderNumber(),
    userId: req.user._id,
    deliveryMethod: delivery_method,
    paymentMethod: payment_method,
    subtotal,
    discountAmount: discount_amount,
    deliveryCharge: delivery_charge,
    totalAmount: total_amount,
    couponCode: coupon_code,
    deliveryAddress: addressSnapshot,
    estimatedDeliveryTime: estimated_delivery_time,
    etaMinutes: eta_minutes,
    notes,
    items: camelizeArray(items),
  });

  await dispatch(() => notifyOrderPlaced(order));

  res.status(201).json({ order: serializeOrder(order) });
});

router.get('/mine', requireAuth, async (req, res) => {
  const orders = await Order.find({ userId: req.user._id }).sort({ createdAt: -1 });
  res.json({ orders: orders.map(serializeOrder) });
});

router.get('/admin/all', requireAuth, requireAdmin, async (req, res) => {
  const filter = {};
  if (req.query.status) filter.status = req.query.status;
  const orders = await Order.find(filter).sort({ createdAt: -1 });
  res.json({ orders: orders.map(serializeOrder) });
});

router.get('/:id', requireAuth, async (req, res) => {
  const order = await Order.findById(req.params.id);
  if (!order) return res.status(404).json({ error: 'Order not found' });
  if (order.userId.toString() !== req.user._id.toString() && req.user.role !== 'admin') {
    return res.status(403).json({ error: 'Forbidden' });
  }
  res.json({ order: serializeOrder(order) });
});

router.patch('/:id', requireAuth, requireAdmin, async (req, res) => {
  // Read before writing so we can tell what actually changed. The customer only
  // wants to hear about real transitions, not every time the store re-saves a
  // form with the same values in it.
  const previous = await Order.findById(req.params.id);
  if (!previous) return res.status(404).json({ error: 'Order not found' });

  const before = {
    status: previous.status,
    paymentStatus: previous.paymentStatus,
    eta: previous.estimatedDeliveryTime,
    isDelayed: !!previous.deliveryAddress?.is_delayed,
  };

  const order = await Order.findByIdAndUpdate(req.params.id, shallowCamelize(req.body), { new: true });
  if (!order) return res.status(404).json({ error: 'Order not found' });

  const statusChanged = order.status !== before.status;
  const paymentChanged = order.paymentStatus !== before.paymentStatus;
  const etaChanged = String(order.estimatedDeliveryTime ?? '') !== String(before.eta ?? '');
  const delayedChanged = !!order.deliveryAddress?.is_delayed !== before.isDelayed;

  await dispatch(async () => {
    // Marking a pickup order 'picked_up' also flips payment to paid; sending
    // "Payment received" alongside "Picked up" would be two pings for one event,
    // so the status message wins when both change together.
    if (paymentChanged && !statusChanged) {
      if (order.paymentStatus === 'paid') await notifyPaymentSuccess(order);
      else if (order.paymentStatus === 'failed') await notifyPaymentFailed(order);
    }
    if (statusChanged) await notifyStatusChanged(order, before.status);
    if (etaChanged || delayedChanged) {
      await notifyEtaChanged(order, { wasDelayed: before.isDelayed && !etaChanged });
    }
  });

  res.json({ order: serializeOrder(order) });
});

module.exports = router;
