const Notification = require('../models/Notification');
const DeviceToken = require('../models/DeviceToken');
const { getMessaging } = require('../config/firebase');

// Must match the channel the Flutter app creates, or Android 8+ silently drops
// the heads-up presentation and the notification only appears in the shade.
const ANDROID_CHANNEL_ID = 'order_updates';

/** FCM data payloads are string-only; anything else is rejected by the API. */
function stringifyData(data = {}) {
  const result = {};
  for (const [key, value] of Object.entries(data)) {
    if (value === null || value === undefined) continue;
    result[key] = typeof value === 'string' ? value : String(value);
  }
  return result;
}

/**
 * Tokens FCM tells us are dead — the app was uninstalled, or the token was
 * reissued. Keeping them means every later send burns a request on a device
 * that can never receive it, so they are deleted on sight.
 */
const DEAD_TOKEN_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
  'messaging/invalid-argument',
]);

/**
 * Records a notification for `userId` and pushes it to their devices.
 *
 * The inbox row is written even when Firebase is unconfigured or every device
 * send fails — the customer should still be able to open the app and see what
 * happened to their order.
 */
async function notifyUser(userId, { type = 'general', title, body, orderId = null, data = {} }) {
  if (!userId || !title || !body) return null;

  const payloadData = stringifyData({
    type,
    ...(orderId ? { order_id: orderId.toString() } : {}),
    ...data,
  });

  let notification;
  try {
    notification = await Notification.create({
      userId,
      type,
      title,
      body,
      orderId,
      data: payloadData,
    });
  } catch (err) {
    console.error('[push] Failed to store notification:', err.message);
    return null;
  }

  try {
    // iOS shows this number on the app icon, so it has to be the real unread
    // total rather than a constant — a permanent "1" trains people to ignore it.
    const badge = await Notification.countDocuments({ userId, readAt: null });

    await sendToDevices(userId, {
      title,
      body,
      badge,
      data: { ...payloadData, notification_id: notification._id.toString() },
    });
    notification.sentAt = new Date();
    await notification.save();
  } catch (err) {
    // A failed push must never fail the order/payment request that triggered it.
    console.error('[push] Failed to deliver notification:', err.message);
  }

  return notification;
}

async function sendToDevices(userId, { title, body, data, badge = 1 }) {
  const messaging = getMessaging();
  if (!messaging) return { successCount: 0, failureCount: 0, skipped: true };

  const devices = await DeviceToken.find({ userId }).select('token');
  const tokens = devices.map((d) => d.token);
  if (tokens.length === 0) return { successCount: 0, failureCount: 0, skipped: true };

  const response = await messaging.sendEachForMulticast({
    tokens,
    notification: { title, body },
    data,
    android: {
      priority: 'high',
      notification: {
        channelId: ANDROID_CHANNEL_ID,
        sound: 'default',
        // Collapsing by order keeps a busy order from stacking six cards in the shade.
        tag: data.order_id || undefined,
      },
    },
    apns: {
      payload: {
        aps: {
          sound: 'default',
          badge,
          'content-available': 1,
          'thread-id': data.order_id || undefined,
        },
      },
    },
  });

  const dead = [];
  response.responses.forEach((result, index) => {
    if (result.success) return;
    const code = result.error?.code;
    if (DEAD_TOKEN_CODES.has(code)) dead.push(tokens[index]);
    else console.error(`[push] Send failed for one device: ${code || result.error?.message}`);
  });

  if (dead.length > 0) {
    await DeviceToken.deleteMany({ token: { $in: dead } });
  }

  return response;
}

module.exports = { notifyUser, sendToDevices, ANDROID_CHANNEL_ID };
