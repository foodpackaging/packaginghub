const express = require('express');
const Category = require('../models/Category');
const { requireAuth, requireAdmin } = require('../middleware/auth');
const { serializeCategory } = require('../utils/serializers');
const { shallowCamelize } = require('../utils/caseConvert');

const router = express.Router();

router.get('/', async (req, res) => {
  const filter = {};
  // The admin dashboard manages inactive categories too, so it passes all=true;
  // the customer-facing app only ever wants active ones.
  if (req.query.all !== 'true') filter.isActive = true;
  if (req.query.parent_id === 'null') filter.parentId = null;
  else if (req.query.parent_id) filter.parentId = req.query.parent_id;

  const categories = await Category.find(filter).sort({ sortOrder: 1, name: 1 });
  res.json({ categories: categories.map(serializeCategory) });
});

router.get('/:id', async (req, res) => {
  const category = await Category.findById(req.params.id);
  if (!category) return res.status(404).json({ error: 'Category not found' });
  res.json({ category: serializeCategory(category) });
});

router.post('/', requireAuth, requireAdmin, async (req, res) => {
  const category = await Category.create(shallowCamelize(req.body));
  res.status(201).json({ category: serializeCategory(category) });
});

router.patch('/:id', requireAuth, requireAdmin, async (req, res) => {
  const category = await Category.findByIdAndUpdate(req.params.id, shallowCamelize(req.body), { new: true });
  if (!category) return res.status(404).json({ error: 'Category not found' });
  res.json({ category: serializeCategory(category) });
});

router.delete('/:id', requireAuth, requireAdmin, async (req, res) => {
  await Category.findByIdAndDelete(req.params.id);
  await Category.deleteMany({ parentId: req.params.id });
  res.json({ ok: true });
});

module.exports = router;
