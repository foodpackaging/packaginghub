// Shared query-building for the product catalog: turns the app's filter payload
// into Mongo match stages, and builds the faceted aggregation the browse screen uses.

const DEFAULT_PAGE_SIZE = 24;
const MAX_PAGE_SIZE = 100;

// Whitelist: a client-supplied sort key must never reach Mongo verbatim.
const SORT_OPTIONS = {
  newest: { createdAt: -1 },
  price_asc: { price: 1 },
  price_desc: { price: -1 },
  discount: { discountPercent: -1, createdAt: -1 },
  name_asc: { name: 1 },
};
const DEFAULT_SORT = 'newest';

// User input goes into a $regex, so escape it — an unescaped "(((" is a query
// error at best and catastrophic backtracking at worst.
function escapeRegex(input) {
  return String(input).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function searchMatch(search) {
  const term = typeof search === 'string' ? search.trim() : '';
  if (!term) return null;
  const rx = { $regex: escapeRegex(term), $options: 'i' };
  return { $or: [{ name: rx }, { brand: rx }, { sku: rx }] };
}

/**
 * Translates one entry of the app's `filters` object into a Mongo condition.
 * Returns null when the value isn't usable, so callers can skip it.
 */
function conditionFor(key, value) {
  if (value === null || value === undefined) return null;

  if (key === 'price' && typeof value === 'object' && !Array.isArray(value)) {
    const range = {};
    if (typeof value.min === 'number') range.$gte = value.min;
    if (typeof value.max === 'number') range.$lte = value.max;
    return Object.keys(range).length ? { price: range } : null;
  }

  if (key === 'availability') {
    return value === true ? { stockQuantity: { $gt: 0 } } : null;
  }

  if (key === 'brand') {
    if (Array.isArray(value) && value.length) return { brand: { $in: value } };
    if (typeof value === 'string' && value) return { brand: value };
    return null;
  }

  if (key === 'discount') {
    const min = Array.isArray(value) ? value[0] : value;
    return typeof min === 'number' ? { discountPercent: { $gte: min } } : null;
  }

  // Everything else lives under the free-form attributes subdocument.
  if (Array.isArray(value)) {
    return value.length ? { [`attributes.${key}`]: { $in: value } } : null;
  }
  if (typeof value === 'boolean' || typeof value === 'number' || typeof value === 'string') {
    return value === '' ? null : { [`attributes.${key}`]: value };
  }
  return null;
}

/**
 * Builds the $and conditions for every active filter, optionally skipping one key.
 *
 * Skipping matters for facet counts: a brand facet computed with the brand filter
 * still applied would report 0 for every brand the user hasn't picked, so the counts
 * for a given facet are always computed with that facet's own selection excluded.
 */
function filterConditions(filters = {}, { exclude } = {}) {
  const conditions = [];
  for (const [key, value] of Object.entries(filters)) {
    if (exclude !== undefined && key === exclude) continue;
    const condition = conditionFor(key, value);
    if (condition) conditions.push(condition);
  }
  return conditions;
}

function matchStage(conditions) {
  if (!conditions.length) return { $match: {} };
  return { $match: { $and: conditions } };
}

function resolveSort(sort) {
  return SORT_OPTIONS[sort] || SORT_OPTIONS[DEFAULT_SORT];
}

function resolvePaging({ page, limit }) {
  const safeLimit = Math.min(Math.max(Number(limit) || DEFAULT_PAGE_SIZE, 1), MAX_PAGE_SIZE);
  const safePage = Math.max(Number(page) || 1, 1);
  return { page: safePage, limit: safeLimit, skip: (safePage - 1) * safeLimit };
}

/**
 * One aggregation that returns the page of products, the true total, and the
 * facet counts. Doing it in a single round trip keeps the browse screen at one
 * request per interaction instead of one per facet.
 *
 * `attributeKeys` comes from the Filter collection for the current category, so
 * only attributes that are actually exposed as filters get counted.
 */
function buildFacetedPipeline({ baseMatch, filters, sort, skip, limit, attributeKeys = [] }) {
  const allConditions = filterConditions(filters);

  const facets = {
    results: [
      matchStage(allConditions),
      { $sort: resolveSort(sort) },
      { $skip: skip },
      { $limit: limit },
    ],
    total: [matchStage(allConditions), { $count: 'count' }],
    brands: [
      matchStage(filterConditions(filters, { exclude: 'brand' })),
      { $match: { brand: { $nin: [null, ''] } } },
      { $group: { _id: '$brand', count: { $sum: 1 } } },
      { $sort: { count: -1, _id: 1 } },
      { $limit: 50 },
    ],
    priceBounds: [
      matchStage(filterConditions(filters, { exclude: 'price' })),
      { $group: { _id: null, min: { $min: '$price' }, max: { $max: '$price' } } },
    ],
    availability: [
      matchStage(filterConditions(filters, { exclude: 'availability' })),
      { $group: { _id: null, inStock: { $sum: { $cond: [{ $gt: ['$stockQuantity', 0] }, 1, 0] } } } },
    ],
  };

  for (const key of attributeKeys) {
    facets[`attr_${key}`] = [
      matchStage(filterConditions(filters, { exclude: key })),
      { $match: { [`attributes.${key}`]: { $nin: [null, ''] } } },
      // An attribute may hold an array (e.g. sizes); unwind so each value counts once.
      { $unwind: { path: `$attributes.${key}`, preserveNullAndEmptyArrays: false } },
      { $group: { _id: `$attributes.${key}`, count: { $sum: 1 } } },
      { $sort: { count: -1, _id: 1 } },
      { $limit: 50 },
    ];
  }

  return [{ $match: baseMatch }, { $facet: facets }];
}

/** Reshapes the raw $facet output into the response body the app consumes. */
function shapeFacets(raw, attributeKeys = []) {
  const bounds = raw.priceBounds?.[0] || {};
  const facets = {
    brands: (raw.brands || []).map((b) => ({ value: b._id, count: b.count })),
    price: {
      min: typeof bounds.min === 'number' ? bounds.min : null,
      max: typeof bounds.max === 'number' ? bounds.max : null,
    },
    in_stock_count: raw.availability?.[0]?.inStock || 0,
    attributes: {},
  };

  for (const key of attributeKeys) {
    facets.attributes[key] = (raw[`attr_${key}`] || []).map((a) => ({ value: a._id, count: a.count }));
  }

  return facets;
}

module.exports = {
  DEFAULT_PAGE_SIZE,
  MAX_PAGE_SIZE,
  SORT_OPTIONS,
  DEFAULT_SORT,
  escapeRegex,
  searchMatch,
  conditionFor,
  filterConditions,
  matchStage,
  resolveSort,
  resolvePaging,
  buildFacetedPipeline,
  shapeFacets,
};
