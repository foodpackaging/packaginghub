const express = require('express');
const mongoose = require('mongoose');
const Product = require('../models/Product');
const Category = require('../models/Category');
const Filter = require('../models/Filter');
const { requireAuth, requireAdmin } = require('../middleware/auth');
const { serializeProduct } = require('../utils/serializers');
const { shallowCamelize } = require('../utils/caseConvert');
const {
  SORT_OPTIONS,
  DEFAULT_SORT,
  searchMatch,
  resolvePaging,
  buildFacetedPipeline,
  shapeFacets,
} = require('../utils/productQuery');

const router = express.Router();

async function expandCategoryIds(categoryId) {
  const subCategories = await Category.find({ parentId: categoryId }, '_id');
  return [categoryId, ...subCategories.map((c) => c._id.toString())];
}

function toObjectId(id) {
  return mongoose.Types.ObjectId.isValid(id) ? new mongoose.Types.ObjectId(id) : null;
}

// The aggregation pipeline compares raw ObjectIds, so string ids from the client
// have to be cast — a string never matches an ObjectId field in Mongo.
function toObjectIds(ids) {
  return ids.map(toObjectId).filter(Boolean);
}

/**
 * Attribute keys that are exposed as filters for this category, so facet counts
 * are only computed for attributes the UI can actually render.
 */
async function filterableAttributeKeys(categoryId, subcategoryId) {
  const scope = [{ scope: 'global' }];
  if (categoryId) scope.push({ scope: 'category', categoryId });
  if (subcategoryId) scope.push({ scope: 'subcategory', subcategoryId });

  const filters = await Filter.find({ isActive: true, $or: scope }, 'key').lean();
  const reserved = new Set(['price', 'brand', 'discount', 'availability']);
  return [...new Set(filters.map((f) => f.key))].filter((k) => !reserved.has(k));
}

router.get('/', async (req, res) => {
  const { search, category_id, brand, featured, flash_sale, min_price, max_price, limit, skip, all, sort } = req.query;
  const filter = {};
  // The admin dashboard manages inactive products too, so it passes all=true;
  // the customer-facing app only ever wants active ones.
  if (all !== 'true') filter.isActive = true;

  // Matches name/brand/sku rather than name alone, and escapes the term so a
  // stray regex character from the search box can't break or stall the query.
  const searchCondition = searchMatch(search);
  if (searchCondition) Object.assign(filter, searchCondition);

  if (brand) filter.brand = brand;
  if (featured === 'true') filter.isFeatured = true;
  if (flash_sale === 'true') filter.discountPercent = { $gt: 15 };
  if (category_id) filter.categoryId = { $in: await expandCategoryIds(category_id) };
  if (min_price || max_price) {
    filter.price = {};
    if (min_price) filter.price.$gte = Number(min_price);
    if (max_price) filter.price.$lte = Number(max_price);
  }

  const effectiveLimit = limit ? Number(limit) : all === 'true' ? 1000 : 100;
  const effectiveSkip = skip ? Number(skip) : 0;

  // countDocuments runs alongside the page fetch so callers can paginate properly
  // instead of inferring "no more results" from a short page.
  const [products, total] = await Promise.all([
    Product.find(filter)
      .sort(SORT_OPTIONS[sort] || SORT_OPTIONS[DEFAULT_SORT])
      .skip(effectiveSkip)
      .limit(effectiveLimit),
    Product.countDocuments(filter),
  ]);

  res.json({
    products: products.map(serializeProduct),
    total,
    limit: effectiveLimit,
    skip: effectiveSkip,
    has_more: effectiveSkip + products.length < total,
  });
});

// POST because the active-filters shape (ranges, lists, arbitrary attribute keys) doesn't
// serialize cleanly into query params.
//
// Returns the page of products, the true total, and facet counts in one round trip.
// `products` is kept at the top level so existing clients keep working.
router.post('/filtered', async (req, res) => {
  const {
    category_id: categoryId,
    subcategory_id: subcategoryId,
    filters = {},
    search,
    sort,
    page,
    limit,
    include_facets: includeFacets = true,
  } = req.body;

  const baseConditions = [{ isActive: true }];

  if (subcategoryId) {
    const id = toObjectId(subcategoryId);
    if (!id) return res.status(400).json({ error: 'Invalid subcategory_id' });
    baseConditions.push({ categoryId: id });
  } else if (categoryId) {
    const ids = toObjectIds(await expandCategoryIds(categoryId));
    if (!ids.length) return res.status(400).json({ error: 'Invalid category_id' });
    baseConditions.push({ categoryId: { $in: ids } });
  }

  const searchCondition = searchMatch(search);
  if (searchCondition) baseConditions.push(searchCondition);

  const { page: safePage, limit: safeLimit, skip } = resolvePaging({ page, limit });
  const attributeKeys = includeFacets ? await filterableAttributeKeys(categoryId, subcategoryId) : [];

  const pipeline = buildFacetedPipeline({
    baseMatch: { $and: baseConditions },
    filters,
    sort,
    skip,
    limit: safeLimit,
    attributeKeys,
  });

  const [raw] = await Product.aggregate(pipeline).allowDiskUse(true);
  const total = raw?.total?.[0]?.count || 0;
  const products = (raw?.results || []).map(serializeProduct);

  res.json({
    products,
    total,
    page: safePage,
    limit: safeLimit,
    has_more: skip + products.length < total,
    sort: SORT_OPTIONS[sort] ? sort : DEFAULT_SORT,
    sort_options: Object.keys(SORT_OPTIONS),
    ...(includeFacets ? { facets: shapeFacets(raw || {}, attributeKeys) } : {}),
  });
});

router.get('/brands', async (req, res) => {
  const brands = await Product.distinct('brand', { isActive: true, brand: { $ne: '' } });
  res.json({ brands: brands.sort() });
});

// Attribute keys are interpolated into a query path, so anything outside this set
// (notably '.' and '$') must be rejected rather than escaped.
const SAFE_KEY = /^[A-Za-z0-9_]+$/;

/**
 * Which values does a given attribute actually hold, and how many products use each?
 *
 * Lets the admin Filter Manager fill a filter's options from real catalog data
 * instead of the author guessing and typing them by hand — a filter whose options
 * don't match the stored values silently matches nothing.
 */
router.get('/attribute-values', requireAuth, requireAdmin, async (req, res) => {
  const { key, category_id: categoryId } = req.query;
  if (!key || !SAFE_KEY.test(key)) {
    return res.status(400).json({ error: 'A valid attribute key (letters, numbers, underscore) is required' });
  }

  const path = `attributes.${key}`;
  const match = { [path]: { $nin: [null, ''] } };
  if (categoryId) {
    const ids = toObjectIds(await expandCategoryIds(categoryId));
    if (ids.length) match.categoryId = { $in: ids };
  }

  const rows = await Product.aggregate([
    { $match: match },
    // $unwind treats a non-array as a single-element array, so this handles
    // both multi-value attributes and plain scalars.
    { $unwind: { path: `$${path}`, preserveNullAndEmptyArrays: false } },
    { $group: { _id: `$${path}`, count: { $sum: 1 } } },
    { $sort: { count: -1, _id: 1 } },
    { $limit: 200 },
  ]);

  // Only scalars can be rendered as filter options; skip nested objects.
  const values = rows
    .filter((r) => ['string', 'number', 'boolean'].includes(typeof r._id))
    .map((r) => ({ value: r._id, count: r.count }));

  res.json({ key, values, total_products: values.reduce((sum, v) => sum + v.count, 0) });
});

router.get('/:id', async (req, res) => {
  const product = await Product.findById(req.params.id);
  if (!product) return res.status(404).json({ error: 'Product not found' });
  res.json({ product: serializeProduct(product) });
});

router.post('/', requireAuth, requireAdmin, async (req, res) => {
  const product = await Product.create(shallowCamelize(req.body));
  res.status(201).json({ product: serializeProduct(product) });
});

router.patch('/:id', requireAuth, requireAdmin, async (req, res) => {
  const product = await Product.findByIdAndUpdate(req.params.id, shallowCamelize(req.body), { new: true });
  if (!product) return res.status(404).json({ error: 'Product not found' });
  res.json({ product: serializeProduct(product) });
});

router.delete('/:id', requireAuth, requireAdmin, async (req, res) => {
  await Product.findByIdAndDelete(req.params.id);
  res.json({ ok: true });
});

module.exports = router;
