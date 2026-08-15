const express = require('express');
const DeviceToken = require('../models/DeviceToken');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();

const PLATFORMS = new Set(['android', 'ios', 'web', 'other']);

/**
 * Registers (or re-points) an FCM token for the signed-in user.
 *
 * Upserting on the token rather than on (user, token) is deliberate: when a
 * second account signs in on the same phone, FCM hands back the same token and
 * this moves it to the new user, so the previous one stops receiving pushes
 * meant for someone else.
 */
router.post('/', requireAuth, async (req, res) => {
  const { token, platform, device_id: deviceId, app_version: appVersion } = req.body;
  if (!token || typeof token !== 'string') {
    return res.status(400).json({ error: 'token is required' });
  }

  const device = await DeviceToken.findOneAndUpdate(
    { token },
    {
      token,
      userId: req.user._id,
      platform: PLATFORMS.has(platform) ? platform : 'other',
      deviceId: deviceId || '',
      appVersion: appVersion || '',
      lastSeenAt: new Date(),
    },
    { new: true, upsert: true, setDefaultsOnInsert: true }
  );

  res.json({ registered: true, platform: device.platform });
});

/** Called on logout so a shared device stops receiving the old user's orders. */
router.delete('/', requireAuth, async (req, res) => {
  const token = req.body?.token;
  if (!token) return res.status(400).json({ error: 'token is required' });

  await DeviceToken.deleteOne({ token, userId: req.user._id });
  res.json({ removed: true });
});

module.exports = router;
