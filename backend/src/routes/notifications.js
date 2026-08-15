const express = require('express');
const Notification = require('../models/Notification');
const { requireAuth } = require('../middleware/auth');
const { serializeNotification } = require('../utils/serializers');

const router = express.Router();

router.get('/', requireAuth, async (req, res) => {
  const limit = Math.min(Number(req.query.limit) || 50, 100);
  const filter = { userId: req.user._id };
  if (req.query.unread === 'true') filter.readAt = null;

  const [notifications, unreadCount] = await Promise.all([
    Notification.find(filter).sort({ createdAt: -1 }).limit(limit),
    Notification.countDocuments({ userId: req.user._id, readAt: null }),
  ]);

  res.json({ notifications: notifications.map(serializeNotification), unread_count: unreadCount });
});

router.get('/unread-count', requireAuth, async (req, res) => {
  const count = await Notification.countDocuments({ userId: req.user._id, readAt: null });
  res.json({ unread_count: count });
});

router.post('/read-all', requireAuth, async (req, res) => {
  await Notification.updateMany(
    { userId: req.user._id, readAt: null },
    { $set: { readAt: new Date() } }
  );
  res.json({ unread_count: 0 });
});

router.patch('/:id/read', requireAuth, async (req, res) => {
  const notification = await Notification.findOneAndUpdate(
    { _id: req.params.id, userId: req.user._id },
    { $set: { readAt: new Date() } },
    { new: true }
  );
  if (!notification) return res.status(404).json({ error: 'Notification not found' });

  const unreadCount = await Notification.countDocuments({ userId: req.user._id, readAt: null });
  res.json({ notification: serializeNotification(notification), unread_count: unreadCount });
});

module.exports = router;
