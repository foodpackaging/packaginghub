const mongoose = require('mongoose');

const userSchema = new mongoose.Schema(
  {
    email: { type: String, required: true, unique: true, lowercase: true, trim: true },
    passwordHash: { type: String, required: true },
    role: { type: String, enum: ['customer', 'admin'], default: 'customer' },

    firstName: { type: String, default: '' },
    lastName: { type: String, default: '' },
    phone: { type: String, default: '' },
    workEmail: { type: String, default: '' },
    companyType: { type: String, default: '' },
    businessRole: { type: String, default: '' },
    roleDescription: { type: String, default: '' },
    gstNumber: { type: String, default: '' },
    address: { type: String, default: '' },
    latitude: { type: Number },
    longitude: { type: Number },
    locationUrl: { type: String, default: '' },
    avatarUrl: { type: String, default: '' },
    onboardingComplete: { type: Boolean, default: false },

    passwordResetTokenHash: { type: String },
    passwordResetExpiresAt: { type: Date },
    passwordResetSentAt: { type: Date },
    passwordResetAttempts: { type: Number, default: 0 },
  },
  { timestamps: true }
);

module.exports = mongoose.model('User', userSchema);
