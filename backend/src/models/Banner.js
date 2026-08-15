const mongoose = require('mongoose');

const bannerSchema = new mongoose.Schema(
  {
    imageUrl: { type: String, required: true },
    placement: { type: String, enum: ['hero', 'category'], default: 'hero' },
  },
  { timestamps: true }
);

bannerSchema.index({ placement: 1, createdAt: 1 });

module.exports = mongoose.model('Banner', bannerSchema);
