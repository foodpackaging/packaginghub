const mongoose = require('mongoose');

const productSchema = new mongoose.Schema(
  {
    name: { type: String, required: true },
    slug: { type: String, default: '' },
    description: { type: String, default: '' },
    brand: { type: String, default: '' },
    sku: { type: String, default: '' },
    categoryId: { type: mongoose.Schema.Types.ObjectId, ref: 'Category' },
    price: { type: Number, required: true },
    discountedPrice: { type: Number },
    discountPercent: { type: Number, default: 0 },
    stockQuantity: { type: Number, default: 0 },
    unit: { type: String, default: '' },
    minOrderQty: { type: Number, default: 1 },
    images: { type: [String], default: [] },
    attributes: { type: mongoose.Schema.Types.Mixed, default: {} },
    isActive: { type: Boolean, default: true },
    isFeatured: { type: Boolean, default: false },
  },
  { timestamps: true }
);

// A plain { attributes: 1 } index only covers queries on the whole subdocument —
// it does nothing for the `attributes.<key>` lookups the filter endpoint actually
// issues. A wildcard index covers every attribute key, including ones added later.
productSchema.index({ 'attributes.$**': 1 });

// Catalog browse: active products in a category, default (newest) ordering.
productSchema.index({ isActive: 1, categoryId: 1, createdAt: -1 });
// Same browse path, but sorted by price — lets the sort run off the index
// instead of a blocking in-memory sort.
productSchema.index({ isActive: 1, categoryId: 1, price: 1 });
// "Shop by brand" and the brand facet.
productSchema.index({ isActive: 1, brand: 1 });
// Flash sale / discount sort.
productSchema.index({ isActive: 1, discountPercent: -1 });

productSchema.index({ name: 'text', brand: 'text', sku: 'text' });

module.exports = mongoose.model('Product', productSchema);
