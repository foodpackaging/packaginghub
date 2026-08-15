const express = require('express');
const Banner = require('../models/Banner');
const { requireAuth, requireAdmin } = require('../middleware/auth');
const { serializeBanner } = require('../utils/serializers');
const { shallowCamelize } = require('../utils/caseConvert');

const router = express.Router();

router.get('/', async (req, res) => {
  const filter = {};
  if (req.query.placement) filter.placement = req.query.placement;
  const banners = await Banner.find(filter).sort({ createdAt: 1 });
  res.json({ banners: banners.map(serializeBanner) });
});

router.post('/', requireAuth, requireAdmin, async (req, res) => {
  const banner = await Banner.create(shallowCamelize(req.body));
  res.status(201).json({ banner: serializeBanner(banner) });
});

router.patch('/:id', requireAuth, requireAdmin, async (req, res) => {
  const banner = await Banner.findByIdAndUpdate(req.params.id, shallowCamelize(req.body), { new: true });
  if (!banner) return res.status(404).json({ error: 'Banner not found' });
  res.json({ banner: serializeBanner(banner) });
});

router.delete('/:id', requireAuth, requireAdmin, async (req, res) => {
  await Banner.findByIdAndDelete(req.params.id);
  res.json({ ok: true });
});

module.exports = router;
