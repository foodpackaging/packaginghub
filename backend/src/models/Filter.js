const mongoose = require('mongoose');

const filterSchema = new mongoose.Schema(
  {
    key: { type: String, required: true },
    label: { type: String, required: true },
    scope: { type: String, enum: ['global', 'category', 'subcategory'], default: 'global' },
    categoryId: { type: mongoose.Schema.Types.ObjectId, ref: 'Category', default: null },
    subcategoryId: { type: mongoose.Schema.Types.ObjectId, ref: 'Category', default: null },
    uiType: {
      type: String,
      enum: ['single-select', 'multiselect', 'chip-selection', 'range', 'boolean', 'rating'],
      required: true,
    },
    dataType: { type: String, enum: ['string', 'number', 'boolean'], required: true },
    options: { type: mongoose.Schema.Types.Mixed, default: [] },
    sortOrder: { type: Number, default: 0 },
    isActive: { type: Boolean, default: true },
    isRequired: { type: Boolean, default: false },
    showInMobileFilters: { type: Boolean, default: true },
    isSearchable: { type: Boolean, default: false },
    defaultValue: { type: mongoose.Schema.Types.Mixed, default: null },
  },
  { timestamps: true }
);

filterSchema.index({ key: 1, scope: 1, categoryId: 1, subcategoryId: 1 }, { unique: true });

module.exports = mongoose.model('Filter', filterSchema);
