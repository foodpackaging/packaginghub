const env = require('../config/env');
const { notifyUser } = require('./pushService');

/** Payment methods where money is collected up front, before the shop ships. */
const PREPAID_METHODS = new Set(['online', 'razorpay', 'upi', 'mock']);

function isPrepaid(order) {
  return PREPAID_METHODS.has(order.paymentMethod);
}

function formatAmount(amount) {
  try {
    return new Intl.NumberFormat('en-IN', {
      style: 'currency',
      currency: env.currency,
      maximumFractionDigits: 2,
    }).format(amount || 0);
  } catch (_) {
    return `${amount}`;
  }
}

/** "6:30 PM" in the store's timezone — an ISO string would be unreadable in a push. */
function formatTime(date) {
  if (!date) return null;
  const value = date instanceof Date ? date : new Date(date);
  if (Number.isNaN(value.getTime())) return null;
  try {
    return new Intl.DateTimeFormat('en-IN', {
      hour: 'numeric',
      minute: '2-digit',
      hour12: true,
      timeZone: env.timezone,
    })
      .format(value)
      // en-IN renders "8:17 pm"; uppercase reads better in a notification title.
      .replace(/\b(am|pm)\b/gi, (m) => m.toUpperCase());
  } catch (_) {
    return value.toISOString();
  }
}

/** Every push carries these, so a tap can open the exact order it refers to. */
function baseData(order) {
  return {
    route: 'order_details',
    order_id: order._id.toString(),
    order_number: order.orderNumber,
    order_status: order.status,
  };
}

function send(order, type, title, body, extraData = {}) {
  return notifyUser(order.userId, {
    type,
    title,
    body,
    orderId: order._id,
    data: { ...baseData(order), ...extraData },
  });
}

/** Fired the moment an order row exists, before any payment is attempted. */
function notifyOrderPlaced(order) {
  const amount = formatAmount(order.totalAmount);

  if (isPrepaid(order) && order.paymentStatus !== 'paid') {
    return send(
      order,
      'payment_pending',
      'Order created — payment pending',
      `Order ${order.orderNumber} for ${amount} is waiting for payment. Complete it to send the order to the store.`
    );
  }

  const closing = order.deliveryMethod === 'pickup'
    ? "We'll let you know as soon as it's ready to collect."
    : "We'll keep you posted as it moves.";

  return send(
    order,
    'order_placed',
    'Order placed 🎉',
    `Order ${order.orderNumber} for ${amount} has been sent to the store. ${closing}`
  );
}

function notifyPaymentSuccess(order) {
  return send(
    order,
    'payment_success',
    'Payment successful ✅',
    `We received ${formatAmount(order.totalAmount)} for order ${order.orderNumber}. It's now with the store for confirmation.`,
    { payment_status: 'paid' }
  );
}

function notifyPaymentFailed(order, reason) {
  return send(
    order,
    'payment_failed',
    'Payment failed',
    `We couldn't complete the payment for order ${order.orderNumber}${reason ? ` (${reason})` : ''}. Your order is on hold — please try paying again.`,
    { payment_status: 'failed' }
  );
}

/**
 * Copy for each status the store can move an order to.
 * Returns null for statuses that don't warrant interrupting the customer.
 */
function statusMessage(order) {
  const isPickup = order.deliveryMethod === 'pickup';

  switch (order.status) {
    case 'processing':
      return {
        type: 'order_accepted',
        title: 'Order accepted 👍',
        body: `The store has accepted order ${order.orderNumber} and started preparing it.`,
      };
    case 'packed':
      return isPickup
        ? {
            type: 'order_ready_for_pickup',
            title: 'Ready for pickup 🏬',
            body: `Order ${order.orderNumber} is packed and waiting at the store. Bring your order number when you collect it.`,
          }
        : {
            type: 'order_packed',
            title: 'Order packed 📦',
            body: `Order ${order.orderNumber} is packed and lined up for dispatch.`,
          };
    case 'out_for_delivery': {
      const eta = formatTime(order.estimatedDeliveryTime);
      return {
        type: 'out_for_delivery',
        title: 'Out for delivery 🚚',
        body: eta
          ? `Order ${order.orderNumber} is on its way — arriving by around ${eta}.`
          : `Order ${order.orderNumber} is on its way to you.`,
      };
    }
    case 'delivered':
      return {
        type: 'order_delivered',
        title: 'Delivered ✅',
        body: `Order ${order.orderNumber} has been delivered. Thanks for shopping with us!`,
      };
    case 'picked_up':
      return {
        type: 'order_picked_up',
        title: 'Picked up ✅',
        body: `Order ${order.orderNumber} was collected from the store. Thanks for shopping with us!`,
      };
    case 'cancelled':
      return {
        type: 'order_cancelled',
        title: 'Order cancelled',
        body: `Order ${order.orderNumber} has been cancelled.${
          order.paymentStatus === 'paid' ? ' Any amount paid will be refunded to the original payment method.' : ''
        }`,
      };
    default:
      // 'pending' is the creation state — notifyOrderPlaced already covered it.
      return null;
  }
}

function notifyStatusChanged(order, previousStatus) {
  if (order.status === previousStatus) return null;
  const message = statusMessage(order);
  if (!message) return null;
  return send(order, message.type, message.title, message.body);
}

/**
 * Fired when the store sets or moves the promised delivery time.
 *
 * A delay is worth its own, apologetic message: the customer already planned
 * around the old time, so silently overwriting the ETA would strand them.
 */
function notifyEtaChanged(order, { wasDelayed = false } = {}) {
  const eta = formatTime(order.estimatedDeliveryTime);
  if (!eta) return null;

  const isDelayed = !!order.deliveryAddress?.is_delayed;
  const isPickup = order.deliveryMethod === 'pickup';
  const noun = isPickup ? 'ready for pickup' : 'delivered';

  if (isDelayed) {
    // Re-saving an unchanged delayed ETA shouldn't nag the customer twice.
    if (wasDelayed) return null;
    return send(
      order,
      'order_delayed',
      'Delivery delayed ⏳',
      `Order ${order.orderNumber} is running late. It should now be ${noun} by around ${eta}. Sorry for the wait!`,
      { eta_time: eta, is_delayed: 'true' }
    );
  }

  return send(
    order,
    'eta_set',
    isPickup ? 'Pickup time set ⏰' : 'Delivery time set ⏰',
    `Order ${order.orderNumber} should be ${noun} by around ${eta}.`,
    { eta_time: eta, is_delayed: 'false' }
  );
}

module.exports = {
  notifyOrderPlaced,
  notifyPaymentSuccess,
  notifyPaymentFailed,
  notifyStatusChanged,
  notifyEtaChanged,
  isPrepaid,
};
