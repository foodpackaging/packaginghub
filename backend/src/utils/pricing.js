// Single source of truth for money math. Order creation and coupon validation
// both call into this module so there is exactly one place that decides what
// something costs — the client never gets the final say on a price.

const Coupon = require('../models/Coupon');

/** Flat delivery charge for a 'delivery' order. Pickup orders are always free. */
const DELIVERY_CHARGE = 50;

/** The price actually charged for one unit of a product, server-side. */
function resolveUnitPrice(product) {
  return product.discountedPrice > 0 ? product.discountedPrice : product.price;
}

function computeDeliveryCharge(deliveryMethod) {
  return deliveryMethod === 'delivery' ? DELIVERY_CHARGE : 0;
}

/** Discount a coupon yields against a given (server-computed) order amount. */
function computeDiscount(coupon, orderAmount) {
  if (coupon.discountType === 'percent') {
    const raw = (orderAmount * coupon.discountValue) / 100;
    return coupon.maxDiscountAmount ? Math.min(raw, coupon.maxDiscountAmount) : raw;
  }
  return Math.min(coupon.discountValue, orderAmount);
}

/**
 * Looks up an active coupon by code and validates it against a server-computed
 * order amount. Returns { coupon, discountAmount } on success, or
 * { error } (a user-facing message) when the code is invalid/ineligible —
 * callers decide what to do with a failure (order creation rejects the whole
 * order rather than silently charging full price).
 */
async function validateCouponForAmount(code, orderAmount) {
  if (!code) return { coupon: null, discountAmount: 0 };

  const coupon = await Coupon.findOne({ code: String(code).toUpperCase(), isActive: true });
  if (!coupon) return { error: 'Invalid or inactive coupon' };
  if (orderAmount < coupon.minOrderAmount) {
    return { error: `Minimum order amount is ${coupon.minOrderAmount}` };
  }

  return { coupon, discountAmount: computeDiscount(coupon, orderAmount) };
}

module.exports = {
  DELIVERY_CHARGE,
  resolveUnitPrice,
  computeDeliveryCharge,
  computeDiscount,
  validateCouponForAmount,
};
