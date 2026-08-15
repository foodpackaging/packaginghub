const express = require('express');
const User = require('../models/User');
const { requireAuth, requireAdmin } = require('../middleware/auth');
const { serializeUser } = require('../utils/serializers');

const router = express.Router();

router.get('/', requireAuth, requireAdmin, async (req, res) => {
  const customers = await User.find({ role: 'customer' }).sort({ createdAt: -1 });
  res.json({ customers: customers.map(serializeUser) });
});

router.delete('/:id', requireAuth, requireAdmin, async (req, res) => {
  await User.findByIdAndDelete(req.params.id);
  res.json({ ok: true });
});

module.exports = router;
