const mongoose = require('mongoose');

const returnItemSchema = new mongoose.Schema(
  {
    orderItemId: { type: String, default: null },
    productName: { type: String, required: true },
    quantity: { type: Number, required: true },
    itemTotal: { type: Number, required: true },
    refundAmount: { type: Number, required: true },
  },
  { _id: false }
);

const returnRequestSchema = new mongoose.Schema(
  {
    orderId: { type: mongoose.Schema.Types.ObjectId, ref: 'Order', required: true },
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    reason: { type: String, required: true },
    status: {
      type: String,
      enum: [
        'pending',
        'approved',
        'rejected',
        'pickup_scheduled',
        'drop_off_pending',
        'received',
        'refunded',
      ],
      default: 'pending',
    },
    returnMethod: { type: String, enum: ['drop_off', 'pickup'], default: null },
    pickupDate: { type: Date },
    adminNotes: { type: String, default: '' },
    returnItems: { type: [returnItemSchema], default: [] },
    refundAmount: { type: Number, default: 0 },
  },
  { timestamps: true }
);

returnRequestSchema.index({ orderId: 1 });
returnRequestSchema.index({ userId: 1, createdAt: -1 });

module.exports = mongoose.model('ReturnRequest', returnRequestSchema);
