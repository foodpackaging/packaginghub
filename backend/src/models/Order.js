const mongoose = require('mongoose');

const orderItemSchema = new mongoose.Schema(
  {
    productId: { type: mongoose.Schema.Types.ObjectId, ref: 'Product', default: null },
    productName: { type: String, required: true },
    productImage: { type: String, default: '' },
    quantity: { type: Number, required: true },
    unitPrice: { type: Number, required: true },
    discountPercent: { type: Number, default: 0 },
    totalPrice: { type: Number, required: true },
  }
);

const orderSchema = new mongoose.Schema(
  {
    orderNumber: { type: String, required: true, unique: true },
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    status: {
      type: String,
      enum: [
        'pending',
        'processing',
        'packed',
        'out_for_delivery',
        'delivered',
        'picked_up',
        'cancelled',
      ],
      default: 'pending',
    },
    deliveryMethod: { type: String, enum: ['delivery', 'pickup'], required: true },
    paymentMethod: {
      type: String,
      enum: ['pay_at_store', 'cod', 'online', 'mock', 'razorpay', 'upi'],
      required: true,
    },
    paymentStatus: { type: String, enum: ['pending', 'paid', 'failed'], default: 'pending' },
    subtotal: { type: Number, required: true },
    discountAmount: { type: Number, default: 0 },
    deliveryCharge: { type: Number, default: 0 },
    totalAmount: { type: Number, required: true },
    couponCode: { type: String, default: null },
    deliveryAddress: { type: mongoose.Schema.Types.Mixed, default: {} },
    estimatedDeliveryTime: { type: String, default: null },
    etaMinutes: { type: Number },
    notes: { type: String, default: '' },
    razorpayOrderId: { type: String },
    razorpayPaymentId: { type: String },
    razorpaySignature: { type: String },
    items: { type: [orderItemSchema], default: [] },
  },
  { timestamps: true }
);

orderSchema.index({ userId: 1, createdAt: -1 });

module.exports = mongoose.model('Order', orderSchema);
