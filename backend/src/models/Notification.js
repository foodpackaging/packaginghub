const mongoose = require('mongoose');

/**
 * A notification as the customer sees it in the in-app inbox.
 *
 * Every push is written here first and sent second, so the history survives a
 * phone that was offline, had notifications muted, or wasn't registered yet.
 */
const notificationSchema = new mongoose.Schema(
  {
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    type: {
      type: String,
      enum: [
        'order_placed',
        'payment_pending',
        'payment_success',
        'payment_failed',
        'order_accepted',
        'order_packed',
        'order_ready_for_pickup',
        'eta_set',
        'order_delayed',
        'out_for_delivery',
        'order_delivered',
        'order_picked_up',
        'order_cancelled',
        'general',
      ],
      default: 'general',
    },
    title: { type: String, required: true },
    body: { type: String, required: true },
    orderId: { type: mongoose.Schema.Types.ObjectId, ref: 'Order', default: null },
    // Extra key/value payload delivered with the push (route, order_number, …).
    data: { type: mongoose.Schema.Types.Mixed, default: {} },
    readAt: { type: Date, default: null },
    sentAt: { type: Date, default: null },
  },
  { timestamps: true }
);

notificationSchema.index({ userId: 1, createdAt: -1 });

module.exports = mongoose.model('Notification', notificationSchema);
