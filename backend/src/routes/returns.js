const express = require('express');
const ReturnRequest = require('../models/ReturnRequest');
const Order = require('../models/Order');
const { requireAuth, requireAdmin } = require('../middleware/auth');
const { serializeReturnRequest } = require('../utils/serializers');
const { shallowCamelize, camelizeArray } = require('../utils/caseConvert');

const router = express.Router();

router.post('/', requireAuth, async (req, res) => {
  const { order_id, reason, return_method, pickup_date, return_items, refund_amount } = req.body;
  if (!order_id || !reason || !Array.isArray(return_items)) {
    return res.status(400).json({ error: 'order_id, reason, and return_items are required' });
  }

  const order = await Order.findById(order_id);
  if (!order || order.userId.toString() !== req.user._id.toString()) {
    return res.status(404).json({ error: 'Order not found' });
  }

  const returnRequest = await ReturnRequest.create({
    orderId: order_id,
    userId: req.user._id,
    reason,
    returnMethod: return_method,
    pickupDate: pickup_date,
    returnItems: camelizeArray(return_items),
    refundAmount: refund_amount,
  });

  res.status(201).json({ return_request: serializeReturnRequest(returnRequest) });
});

router.get('/mine', requireAuth, async (req, res) => {
  const returns = await ReturnRequest.find({ userId: req.user._id }).sort({ createdAt: -1 });
  res.json({ return_requests: returns.map(serializeReturnRequest) });
});

router.get('/order/:orderId', requireAuth, async (req, res) => {
  const returns = await ReturnRequest.find({ orderId: req.params.orderId, userId: req.user._id }).sort({
    createdAt: -1,
  });
  res.json({ return_requests: returns.map(serializeReturnRequest) });
});

router.get('/admin/all', requireAuth, requireAdmin, async (req, res) => {
  const filter = {};
  if (req.query.status) filter.status = req.query.status;
  const returns = await ReturnRequest.find(filter).sort({ createdAt: -1 });
  res.json({ return_requests: returns.map(serializeReturnRequest) });
});

router.get('/:id', requireAuth, async (req, res) => {
  const returnRequest = await ReturnRequest.findById(req.params.id);
  if (!returnRequest) return res.status(404).json({ error: 'Return request not found' });
  if (returnRequest.userId.toString() !== req.user._id.toString() && req.user.role !== 'admin') {
    return res.status(403).json({ error: 'Forbidden' });
  }
  res.json({ return_request: serializeReturnRequest(returnRequest) });
});

router.patch('/:id', requireAuth, requireAdmin, async (req, res) => {
  const returnRequest = await ReturnRequest.findByIdAndUpdate(req.params.id, shallowCamelize(req.body), {
    new: true,
  });
  if (!returnRequest) return res.status(404).json({ error: 'Return request not found' });
  res.json({ return_request: serializeReturnRequest(returnRequest) });
});

module.exports = router;
