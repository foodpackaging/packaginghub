const mongoose = require('mongoose');

/**
 * An FCM registration token for one install of the app.
 *
 * The token — not the user — is the identity here: FCM reassigns a token to a
 * different account when someone logs out and a colleague logs in on the same
 * phone, so `token` is unique and re-registering simply moves it to the new
 * user. Without that, the previous owner would keep receiving the new owner's
 * order updates.
 */
const deviceTokenSchema = new mongoose.Schema(
  {
    token: { type: String, required: true, unique: true },
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    platform: { type: String, enum: ['android', 'ios', 'web', 'other'], default: 'other' },
    deviceId: { type: String, default: '' },
    appVersion: { type: String, default: '' },
    lastSeenAt: { type: Date, default: Date.now },
  },
  { timestamps: true }
);

deviceTokenSchema.index({ userId: 1 });

module.exports = mongoose.model('DeviceToken', deviceTokenSchema);
