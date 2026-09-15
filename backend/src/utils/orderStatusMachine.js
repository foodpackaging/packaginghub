// Which order.status values a status can legally move to next. Delivery and
// pickup orders follow different lifecycles after 'packed', so the allowed
// set depends on the order, not just the current status.

const DELIVERY_TRANSITIONS = {
  pending: ['processing', 'cancelled'],
  processing: ['packed', 'cancelled'],
  packed: ['out_for_delivery', 'cancelled'],
  out_for_delivery: ['delivered', 'cancelled'],
  delivered: [],
  cancelled: [],
};

const PICKUP_TRANSITIONS = {
  pending: ['processing', 'cancelled'],
  processing: ['packed', 'cancelled'],
  packed: ['picked_up', 'cancelled'],
  picked_up: [],
  cancelled: [],
};

function allowedNextStatuses(order) {
  const map = order.deliveryMethod === 'pickup' ? PICKUP_TRANSITIONS : DELIVERY_TRANSITIONS;
  return map[order.status] || [];
}

/** Null when the transition is allowed; otherwise a user-facing error message. */
function validateTransition(order, nextStatus) {
  if (!nextStatus || nextStatus === order.status) return null;
  const allowed = allowedNextStatuses(order);
  if (allowed.includes(nextStatus)) return null;
  return `Cannot move order from '${order.status}' to '${nextStatus}'`;
}

module.exports = { allowedNextStatuses, validateTransition };
