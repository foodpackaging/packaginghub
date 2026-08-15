const express = require('express');
const Filter = require('../models/Filter');
const Product = require('../models/Product');
const Category = require('../models/Category');
const { requireAuth, requireAdmin } = require('../middleware/auth');
const { serializeFilter } = require('../utils/serializers');
const { shallowCamelize } = require('../utils/caseConvert');

const router = express.Router();

const SAFE_KEY = /^[A-Za-z0-9_]+$/;
// Handled by dedicated product fields, not the free-form attributes object.
const RESERVED_KEYS = new Set(['price', 'brand', 'discount', 'availability']);

router.get('/', async (req, res) => {
  const { category_id, subcategory_id, all } = req.query;
  const filter = {};
  // FilterManager (admin) manages inactive filters too, so it passes all=true.
  if (all !== 'true') filter.isActive = true;

  if (category_id || subcategory_id) {
    filter.$or = [
      { scope: 'global' },
      ...(category_id ? [{ scope: 'category', categoryId: category_id }] : []),
      ...(subcategory_id ? [{ scope: 'subcategory', subcategoryId: subcategory_id }] : []),
    ];
  }

  const filters = await Filter.find(filter).sort({ sortOrder: 1 });
  res.json({ filters: filters.map(serializeFilter) });
});

/**
 * How many products each filter actually applies to.
 *
 * A filter is only useful once products carry the matching attribute, and the most
 * common failure is a filter that was defined but never populated — it renders in the
 * app and matches nothing. This surfaces that directly: products_in_scope vs
 * products_with_value, plus which configured options are unused.
 */
router.get('/coverage', requireAuth, requireAdmin, async (req, res) => {
  const filters = await Filter.find({}).sort({ sortOrder: 1 }).lean();

  // Resolve each category's own id plus its children once, rather than per filter.
  const childrenByParent = new Map();
  const allCategories = await Category.find({}, '_id parentId').lean();
  for (const c of allCategories) {
    const parent = c.parentId ? c.parentId.toString() : null;
    if (!parent) continue;
    if (!childrenByParent.has(parent)) childrenByParent.set(parent, []);
    childrenByParent.get(parent).push(c._id);
  }

  const coverage = await Promise.all(
    filters.map(async (f) => {
      const scopeMatch = {};
      if (f.scope === 'subcategory' && f.subcategoryId) {
        scopeMatch.categoryId = f.subcategoryId;
      } else if (f.scope === 'category' && f.categoryId) {
        const id = f.categoryId.toString();
        scopeMatch.categoryId = { $in: [f.categoryId, ...(childrenByParent.get(id) || [])] };
      }

      const inScope = await Product.countDocuments(scopeMatch);

      let withValue = 0;
      let usedOptions = [];
      if (SAFE_KEY.test(f.key) && !RESERVED_KEYS.has(f.key)) {
        const path = `attributes.${f.key}`;
        withValue = await Product.countDocuments({ ...scopeMatch, [path]: { $nin: [null, ''] } });

        const rows = await Product.aggregate([
          { $match: { ...scopeMatch, [path]: { $nin: [null, ''] } } },
          { $unwind: { path: `$${path}`, preserveNullAndEmptyArrays: false } },
          { $group: { _id: `$${path}` } },
        ]);
        usedOptions = rows
          .map((r) => r._id)
          .filter((v) => ['string', 'number', 'boolean'].includes(typeof v));
      }

      const configured = Array.isArray(f.options) ? f.options : [];
      const usedSet = new Set(usedOptions.map(String));

      return {
        id: f._id.toString(),
        key: f.key,
        label: f.label,
        scope: f.scope,
        is_active: f.isActive,
        products_in_scope: inScope,
        products_with_value: withValue,
        // Options defined in the admin UI that no product actually uses — these
        // render as filter choices that always return zero results.
        unused_options: configured.filter((o) => !usedSet.has(String(o))),
        // Values present on products but missing from the filter's option list —
        // these are silently unfilterable.
        missing_options: usedOptions.filter((v) => !configured.map(String).includes(String(v))),
      };
    })
  );

  res.json({ coverage });
});

router.post('/', requireAuth, requireAdmin, async (req, res) => {
  const filter = await Filter.create(shallowCamelize(req.body));
  res.status(201).json({ filter: serializeFilter(filter) });
});

router.patch('/:id', requireAuth, requireAdmin, async (req, res) => {
  const filter = await Filter.findByIdAndUpdate(req.params.id, shallowCamelize(req.body), { new: true });
  if (!filter) return res.status(404).json({ error: 'Filter not found' });
  res.json({ filter: serializeFilter(filter) });
});

router.delete('/:id', requireAuth, requireAdmin, async (req, res) => {
  await Filter.findByIdAndDelete(req.params.id);
  res.json({ ok: true });
});

module.exports = router;
