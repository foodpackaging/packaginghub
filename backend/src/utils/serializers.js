function serializeUser(user) {
  return {
    id: user._id.toString(),
    email: user.email,
    first_name: user.firstName,
    last_name: user.lastName,
    phone: user.phone,
    work_email: user.workEmail,
    company_type: user.companyType,
    role: user.businessRole,
    role_description: user.roleDescription,
    gst_number: user.gstNumber,
    address: user.address,
    latitude: user.latitude,
    longitude: user.longitude,
    location_url: user.locationUrl,
    avatar_url: user.avatarUrl,
    onboarding_complete: user.onboardingComplete,
    is_admin: user.role === 'admin',
    created_at: user.createdAt,
    updated_at: user.updatedAt,
  };
}

function serializeProduct(product) {
  return {
    id: product._id.toString(),
    name: product.name,
    slug: product.slug,
    description: product.description,
    brand: product.brand,
    sku: product.sku,
    category_id: product.categoryId ? product.categoryId.toString() : null,
    price: product.price,
    discounted_price: product.discountedPrice,
    discount_percent: product.discountPercent,
    stock_quantity: product.stockQuantity,
    unit: product.unit,
    min_order_qty: product.minOrderQty,
    images: product.images,
    attributes: product.attributes,
    is_active: product.isActive,
    is_featured: product.isFeatured,
    created_at: product.createdAt,
  };
}

function serializeCategory(category) {
  return {
    id: category._id.toString(),
    name: category.name,
    parent_id: category.parentId ? category.parentId.toString() : null,
    icon_url: category.iconUrl,
    slug: category.slug,
    description: category.description,
    sort_order: category.sortOrder,
    is_active: category.isActive,
  };
}

function serializeOrderItem(item, orderId) {
  return {
    id: item._id.toString(),
    order_id: orderId,
    product_id: item.productId ? item.productId.toString() : null,
    product_name: item.productName,
    product_image: item.productImage,
    quantity: item.quantity,
    unit_price: item.unitPrice,
    discount_percent: item.discountPercent,
    total_price: item.totalPrice,
  };
}

function serializeOrder(order) {
  const id = order._id.toString();
  return {
    id,
    order_number: order.orderNumber,
    user_id: order.userId.toString(),
    status: order.status,
    delivery_method: order.deliveryMethod,
    payment_method: order.paymentMethod,
    payment_status: order.paymentStatus,
    subtotal: order.subtotal,
    discount_amount: order.discountAmount,
    delivery_charge: order.deliveryCharge,
    total_amount: order.totalAmount,
    coupon_code: order.couponCode,
    delivery_address: order.deliveryAddress,
    estimated_delivery_time: order.estimatedDeliveryTime || null,
    eta_minutes: order.etaMinutes,
    notes: order.notes,
    razorpay_order_id: order.razorpayOrderId,
    razorpay_payment_id: order.razorpayPaymentId,
    items: (order.items || []).map((item) => serializeOrderItem(item, id)),
    created_at: order.createdAt,
    updated_at: order.updatedAt,
  };
}

function serializeReturnRequest(rr) {
  return {
    id: rr._id.toString(),
    order_id: rr.orderId.toString(),
    user_id: rr.userId.toString(),
    reason: rr.reason,
    status: rr.status,
    return_method: rr.returnMethod,
    pickup_date: rr.pickupDate,
    admin_notes: rr.adminNotes,
    return_items: (rr.returnItems || []).map((item) => ({
      order_item_id: item.orderItemId,
      product_name: item.productName,
      quantity: item.quantity,
      item_total: item.itemTotal,
      refund_amount: item.refundAmount,
    })),
    refund_amount: rr.refundAmount,
    created_at: rr.createdAt,
    updated_at: rr.updatedAt,
  };
}

function serializeFilter(f) {
  return {
    id: f._id.toString(),
    key: f.key,
    label: f.label,
    scope: f.scope,
    category_id: f.categoryId ? f.categoryId.toString() : null,
    subcategory_id: f.subcategoryId ? f.subcategoryId.toString() : null,
    ui_type: f.uiType,
    data_type: f.dataType,
    options: f.options,
    sort_order: f.sortOrder,
    is_active: f.isActive,
    is_required: f.isRequired,
    show_in_mobile_filters: f.showInMobileFilters,
    is_searchable: f.isSearchable,
    default_value: f.defaultValue,
  };
}

function serializeBanner(b) {
  return {
    id: b._id.toString(),
    image_url: b.imageUrl,
    placement: b.placement,
    created_at: b.createdAt,
  };
}

function serializeCoupon(c) {
  return {
    id: c._id.toString(),
    code: c.code,
    description: c.description,
    discount_type: c.discountType,
    discount_value: c.discountValue,
    min_order_amount: c.minOrderAmount,
    max_discount_amount: c.maxDiscountAmount,
    is_active: c.isActive,
  };
}

function formatAddressLine(a) {
  return [a.line1, a.area, a.city, a.state, a.pincode, a.country]
    .map((part) => (part || '').toString().trim())
    .filter(Boolean)
    .join(', ');
}

function serializeAddress(a) {
  return {
    id: a._id.toString(),
    user_id: a.userId ? a.userId.toString() : null,
    label: a.label,
    contact_name: a.contactName,
    contact_phone: a.contactPhone,
    line1: a.line1,
    area: a.area,
    city: a.city,
    state: a.state,
    pincode: a.pincode,
    country: a.country,
    landmark: a.landmark,
    latitude: a.latitude,
    longitude: a.longitude,
    is_default: a.isDefault,
    formatted: formatAddressLine(a),
    created_at: a.createdAt,
    updated_at: a.updatedAt,
  };
}

/**
 * Frozen copy of an address, embedded in an order at placement time.
 *
 * Orders must keep showing the address they were actually delivered to, so this
 * copies the values rather than referencing the Address document — editing or
 * deleting the address later cannot rewrite delivery history. `address_id` is
 * retained for traceability only; readers must never dereference it for display.
 */
function buildAddressSnapshot(a, extras = {}) {
  return {
    address_id: a._id ? a._id.toString() : null,
    label: a.label || '',
    contact_name: a.contactName || '',
    contact_phone: a.contactPhone || '',
    line1: a.line1 || '',
    area: a.area || '',
    city: a.city || '',
    state: a.state || '',
    pincode: a.pincode || '',
    country: a.country || '',
    landmark: a.landmark || '',
    ...(a.latitude != null ? { latitude: a.latitude } : {}),
    ...(a.longitude != null ? { longitude: a.longitude } : {}),
    ...(a.latitude != null && a.longitude != null
      ? { location_url: `https://www.google.com/maps?q=${a.latitude},${a.longitude}` }
      : {}),
    address: formatAddressLine(a),
    ...extras,
  };
}

function serializeNotification(n) {
  return {
    id: n._id.toString(),
    type: n.type,
    title: n.title,
    body: n.body,
    order_id: n.orderId ? n.orderId.toString() : null,
    data: n.data || {},
    is_read: !!n.readAt,
    read_at: n.readAt,
    created_at: n.createdAt,
  };
}

module.exports = {
  serializeNotification,
  serializeUser,
  serializeProduct,
  serializeCategory,
  serializeOrder,
  serializeOrderItem,
  serializeReturnRequest,
  serializeFilter,
  serializeBanner,
  serializeCoupon,
  serializeAddress,
  buildAddressSnapshot,
  formatAddressLine,
};
