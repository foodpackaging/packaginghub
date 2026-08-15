const express = require('express');
const Coupon = require('../models/Coupon');
const { requireAuth, requireAdmin } = require('../middleware/auth');
const { serializeCoupon } = require('../utils/serializers');
const { shallowCamelize } = require('../utils/caseConvert');

const router = express.Router();

function computeDiscount(coupon, orderAmount) {
  if (coupon.discountType === 'percent') {
    const raw = (orderAmount * coupon.discountValue) / 100;
    return coupon.maxDiscountAmount ? Math.min(raw, coupon.maxDiscountAmount) : raw;
  }
  return Math.min(coupon.discountValue, orderAmount);
}

router.get('/', requireAuth, requireAdmin, async (req, res) => {
  const coupons = await Coupon.find().sort({ createdAt: -1 });
  res.json({ coupons: coupons.map(serializeCoupon) });
});

router.post('/validate', requireAuth, async (req, res) => {
  const { code, order_amount: orderAmount } = req.body;
  if (!code || typeof orderAmount !== 'number') {
    return res.status(400).json({ error: 'code and order_amount are required' });
  }

  const coupon = await Coupon.findOne({ code: code.toUpperCase(), isActive: true });
  if (!coupon) return res.status(404).json({ error: 'Invalid or inactive coupon' });
  if (orderAmount < coupon.minOrderAmount) {
    return res.status(400).json({ error: `Minimum order amount is ${coupon.minOrderAmount}` });
  }

  res.json({ coupon: serializeCoupon(coupon), discount_amount: computeDiscount(coupon, orderAmount) });
});

router.post('/', requireAuth, requireAdmin, async (req, res) => {
  const coupon = await Coupon.create(shallowCamelize(req.body));
  res.status(201).json({ coupon: serializeCoupon(coupon) });
});

router.patch('/:id', requireAuth, requireAdmin, async (req, res) => {
  const coupon = await Coupon.findByIdAndUpdate(req.params.id, shallowCamelize(req.body), { new: true });
  if (!coupon) return res.status(404).json({ error: 'Coupon not found' });
  res.json({ coupon: serializeCoupon(coupon) });
});

router.delete('/:id', requireAuth, requireAdmin, async (req, res) => {
  await Coupon.findByIdAndDelete(req.params.id);
  res.json({ ok: true });
});

module.exports = router;
