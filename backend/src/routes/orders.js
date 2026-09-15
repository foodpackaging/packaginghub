const express = require('express');
const mongoose = require('mongoose');
const Order = require('../models/Order');
const Address = require('../models/Address');
const Product = require('../models/Product');
const { requireAuth, requireAdmin } = require('../middleware/auth');
const { serializeOrder, buildAddressSnapshot } = require('../utils/serializers');
const { shallowCamelize } = require('../utils/caseConvert');
const { asyncHandler, HttpError } = require('../utils/asyncHandler');
const { resolvePaging } = require('../utils/productQuery');
const { resolveUnitPrice, computeDeliveryCharge, validateCouponForAmount } = require('../utils/pricing');
const { validateTransition } = require('../utils/orderStatusMachine');
const {
  notifyOrderPlaced,
  notifyPaymentSuccess,
  notifyPaymentFailed,
  notifyStatusChanged,
  notifyEtaChanged,
  notifyAdminNewOrder,
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

function normalizeRequestedItems(items) {
  return items.map((item) => ({
    productId: item.product_id || item.productId,
    quantity: Number(item.quantity),
  }));
}

/**
 * Creates the order inside a MongoDB transaction: every item's stock is
 * validated and atomically deducted, pricing is computed entirely from the
 * database, and the Order document is written — all as one unit, so a
 * mid-order failure (bad product, insufficient stock, invalid coupon) rolls
 * back every deduction made so far instead of leaving partial state behind.
 *
 * Never trusts client-supplied prices, totals, or product names/images —
 * those are only ever read back out of the Product documents fetched here.
 */
async function createOrderTransactionally({ user, requestedItems, deliveryMethod, paymentMethod, couponCode, addressSnapshot, estimatedDeliveryTime, etaMinutes, notes, idempotencyKey }) {
  const session = await mongoose.startSession();
  try {
    let order;
    await session.withTransaction(async () => {
      const orderItems = [];
      let subtotal = 0;

      for (const { productId, quantity } of requestedItems) {
        const product = await Product.findById(productId).session(session);
        if (!product || !product.isActive) {
          throw new HttpError(400, `One of the items in your cart is no longer available.`);
        }

        if (quantity < product.minOrderQty) {
          throw new HttpError(
            400,
            `${product.name} has a minimum order quantity of ${product.minOrderQty} ${product.unit || 'units'}.`
          );
        }

        // Atomic: only decrements if enough stock is still there. Two
        // concurrent requests for the last units can never both succeed —
        // the loser's conditional match simply fails.
        const updated = await Product.findOneAndUpdate(
          { _id: product._id, isActive: true, stockQuantity: { $gte: quantity } },
          { $inc: { stockQuantity: -quantity } },
          { session, new: true }
        );

        if (!updated) {
          const message = product.stockQuantity < product.minOrderQty
            ? `${product.name}'s current stock (${product.stockQuantity}) can't meet its minimum order quantity of ${product.minOrderQty}.`
            : `${product.name} doesn't have enough stock left for that quantity.`;
          throw new HttpError(400, message);
        }

        const unitPrice = resolveUnitPrice(product);
        const totalPrice = unitPrice * quantity;
        subtotal += totalPrice;

        orderItems.push({
          productId: product._id,
          productName: product.name,
          productImage: product.images?.[0] || '',
          quantity,
          unitPrice,
          discountPercent: product.discountPercent || 0,
          totalPrice,
        });
      }

      let discountAmount = 0;
      let appliedCouponCode = null;
      if (couponCode) {
        const result = await validateCouponForAmount(couponCode, subtotal);
        if (result.error) throw new HttpError(400, result.error);
        discountAmount = result.discountAmount;
        appliedCouponCode = result.coupon.code;
      }

      const deliveryCharge = computeDeliveryCharge(deliveryMethod);
      const totalAmount = subtotal + deliveryCharge - discountAmount;

      const [created] = await Order.create(
        [
          {
            orderNumber: generateOrderNumber(),
            userId: user._id,
            deliveryMethod,
            paymentMethod,
            subtotal,
            discountAmount,
            deliveryCharge,
            totalAmount,
            couponCode: appliedCouponCode,
            deliveryAddress: addressSnapshot,
            estimatedDeliveryTime,
            etaMinutes,
            notes,
            items: orderItems,
            idempotencyKey,
          },
        ],
        { session }
      );
      order = created;
    });
    return order;
  } finally {
    await session.endSession();
  }
}

router.post('/', requireAuth, asyncHandler(async (req, res) => {
  const {
    delivery_method,
    payment_method,
    coupon_code,
    address_id,
    delivery_address,
    estimated_delivery_time,
    eta_minutes,
    notes,
    items,
  } = req.body;

  const idempotencyKey = req.get('Idempotency-Key') || null;

  if (!delivery_method || !payment_method || !Array.isArray(items) || items.length === 0) {
    return res.status(400).json({ error: 'delivery_method, payment_method, and items are required' });
  }
  if (!['delivery', 'pickup'].includes(delivery_method)) {
    return res.status(400).json({ error: 'delivery_method must be delivery or pickup' });
  }

  // A retry (double tap, a request resent after a timeout) carrying the same
  // key returns the order already created for the first attempt rather than
  // creating a second one.
  if (idempotencyKey) {
    const existing = await Order.findOne({ userId: req.user._id, idempotencyKey });
    if (existing) return res.status(200).json({ order: serializeOrder(existing) });
  }

  const requestedItems = normalizeRequestedItems(items);
  for (const item of requestedItems) {
    if (!item.productId || !Number.isInteger(item.quantity) || item.quantity <= 0) {
      return res.status(400).json({ error: 'Each item requires a valid product_id and a positive integer quantity' });
    }
  }

  // Snapshot the address at placement time. Copying the values (rather than
  // storing a reference) is what keeps an old order showing the address it was
  // actually delivered to, even after the business edits or deletes that address.
  let addressSnapshot = delivery_address || {};
  if (address_id) {
    const address = await Address.findOne({ _id: address_id, userId: req.user._id });
    if (!address) return res.status(400).json({ error: 'Selected delivery address not found' });

    addressSnapshot = buildAddressSnapshot(address, {
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

  let order;
  try {
    order = await createOrderTransactionally({
      user: req.user,
      requestedItems,
      deliveryMethod: delivery_method,
      paymentMethod: payment_method,
      couponCode: coupon_code,
      addressSnapshot,
      estimatedDeliveryTime: estimated_delivery_time,
      etaMinutes: eta_minutes,
      notes,
      idempotencyKey,
    });
  } catch (err) {
    if (err instanceof HttpError) {
      return res.status(err.status).json({ error: err.message });
    }
    // Lost a race against our own retry: the other request's insert won,
    // return its order instead of surfacing a raw duplicate-key error.
    if (err.code === 11000 && idempotencyKey) {
      const existing = await Order.findOne({ userId: req.user._id, idempotencyKey });
      if (existing) return res.status(200).json({ order: serializeOrder(existing) });
    }
    throw err;
  }

  await dispatch(() => notifyOrderPlaced(order));
  await dispatch(() => notifyAdminNewOrder(order, req.user));

  res.status(201).json({ order: serializeOrder(order) });
}));

router.get('/mine', requireAuth, asyncHandler(async (req, res) => {
  const { page, limit, skip } = resolvePaging(req.query);
  const filter = { userId: req.user._id };

  const [orders, total] = await Promise.all([
    Order.find(filter).sort({ createdAt: -1 }).skip(skip).limit(limit),
    Order.countDocuments(filter),
  ]);

  res.json({
    orders: orders.map(serializeOrder),
    total,
    page,
    limit,
    has_more: skip + orders.length < total,
  });
}));

router.get('/admin/all', requireAuth, requireAdmin, asyncHandler(async (req, res) => {
  const { page, limit, skip } = resolvePaging(req.query);
  const filter = {};
  if (req.query.status) filter.status = req.query.status;

  const [orders, total] = await Promise.all([
    Order.find(filter).sort({ createdAt: -1 }).skip(skip).limit(limit),
    Order.countDocuments(filter),
  ]);

  res.json({
    orders: orders.map(serializeOrder),
    total,
    page,
    limit,
    has_more: skip + orders.length < total,
  });
}));

router.get('/:id', requireAuth, asyncHandler(async (req, res) => {
  const order = await Order.findById(req.params.id);
  if (!order) return res.status(404).json({ error: 'Order not found' });
  if (order.userId.toString() !== req.user._id.toString() && req.user.role !== 'admin') {
    return res.status(403).json({ error: 'Forbidden' });
  }
  res.json({ order: serializeOrder(order) });
}));

router.patch('/:id', requireAuth, requireAdmin, asyncHandler(async (req, res) => {
  // Read before writing so we can tell what actually changed. The customer only
  // wants to hear about real transitions, not every time the store re-saves a
  // form with the same values in it.
  const previous = await Order.findById(req.params.id);
  if (!previous) return res.status(404).json({ error: 'Order not found' });

  const { force_status_override: forceOverride, ...body } = req.body;

  if (body.status && body.status !== previous.status) {
    const violation = validateTransition(previous, body.status);
    if (violation) {
      if (!forceOverride) return res.status(400).json({ error: violation });
      console.warn(
        `[orders] status override by admin ${req.user._id}: order ${previous._id} '${previous.status}' -> '${body.status}'`
      );
    }
  }

  const before = {
    status: previous.status,
    paymentStatus: previous.paymentStatus,
    eta: previous.estimatedDeliveryTime,
    isDelayed: !!previous.deliveryAddress?.is_delayed,
  };

  const order = await Order.findByIdAndUpdate(req.params.id, shallowCamelize(body), { new: true });
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
}));

module.exports = router;
