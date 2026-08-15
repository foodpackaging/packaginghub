const mongoose = require('mongoose');

/**
 * A business delivery location. A business (User) owns many of these.
 *
 * Deliberately NOT the phone's GPS position: this is where goods are sent, which
 * is frequently nowhere near where the person placing the order is sitting.
 * latitude/longitude are optional metadata captured only when the user opts into
 * "use my current location", and are never authoritative over the typed fields.
 */
const addressSchema = new mongoose.Schema(
  {
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },

    // Free-form name the business gives this location, e.g. "Main Warehouse".
    label: { type: String, default: '', trim: true },

    // Who receives the delivery here — may differ per location.
    contactName: { type: String, default: '', trim: true },
    contactPhone: { type: String, default: '', trim: true },

    line1: { type: String, required: true, trim: true }, // Address / Street
    area: { type: String, default: '', trim: true }, // Area / Locality
    city: { type: String, required: true, trim: true },
    state: { type: String, required: true, trim: true },
    pincode: { type: String, required: true, trim: true },
    country: { type: String, default: 'India', trim: true },
    landmark: { type: String, default: '', trim: true },

    // Only set when the user used GPS assistance; purely supplementary.
    latitude: { type: Number },
    longitude: { type: Number },

    isDefault: { type: Boolean, default: false },
  },
  { timestamps: true }
);

// Default address first, then most recently touched.
addressSchema.index({ userId: 1, isDefault: -1, updatedAt: -1 });

/** Single-line rendering used for list rows and legacy free-text fields. */
addressSchema.methods.formatted = function formatted() {
  return [this.line1, this.area, this.city, this.state, this.pincode, this.country]
    .map((part) => (part || '').trim())
    .filter(Boolean)
    .join(', ');
};

module.exports = mongoose.model('Address', addressSchema);
