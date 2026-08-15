import 'user_profile.dart';

class Order {
  final String id;
  final String orderNumber;
  final String userId;
  final UserProfile? profile;
  final String status;
  final String deliveryMethod; // 'delivery' or 'pickup'
  final String paymentMethod; // 'cod' or 'upi'
  final String paymentStatus;
  final double subtotal;
  final double discountAmount;
  final double deliveryCharge;
  final double totalAmount;
  final String? couponCode;
  final Map<String, dynamic>? deliveryAddress;
  final DateTime? estimatedDeliveryTime;
  final int? etaMinutes;
  final bool isDelayed;
  final String? notes;
  final DateTime createdAt;
  final List<OrderItem>? items;
  
  Order({
    required this.id,
    required this.orderNumber,
    required this.userId,
    this.profile,
    required this.status,
    required this.deliveryMethod,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.subtotal,
    this.discountAmount = 0,
    this.deliveryCharge = 0,
    required this.totalAmount,
    this.couponCode,
    this.deliveryAddress,
    this.estimatedDeliveryTime,
    this.etaMinutes,
    this.isDelayed = false,
    this.notes,
    required this.createdAt,
    this.items,
  });
  
  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'].toString(),
      orderNumber: json['order_number'].toString(),
      userId: json['user_id'] as String,
      profile: json['profile'] != null 
        ? UserProfile.fromJson(json['profile'] as Map<String, dynamic>)
        : null,
      status: json['status'] as String,
      deliveryMethod: json['delivery_method'] as String,
      paymentMethod: json['payment_method'] as String,
      paymentStatus: json['payment_status'] as String,
      subtotal: (json['subtotal'] as num).toDouble(),
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0,
      deliveryCharge: (json['delivery_charge'] as num?)?.toDouble() ?? 0,
      totalAmount: (json['total_amount'] as num).toDouble(),
      couponCode: json['coupon_code'] as String?,
      deliveryAddress: json['delivery_address'] as Map<String, dynamic>?,
      estimatedDeliveryTime: json['estimated_delivery_time'] != null 
        ? DateTime.parse(json['estimated_delivery_time'] as String).toLocal()
        : null,
      etaMinutes: json['eta_minutes'] as int?,
      isDelayed: json['delivery_address'] != null 
          ? (json['delivery_address']['is_delayed'] as bool? ?? false)
          : false,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      items: json['items'] != null
        ? (json['items'] as List<dynamic>)
            .map((item) => OrderItem.fromJson(item as Map<String, dynamic>))
            .toList()
        : null,
    );
  }
  
  bool get isDelivery => deliveryMethod == 'delivery';
  bool get isPickup => deliveryMethod == 'pickup';
  bool get isCOD => paymentMethod == 'cod';
  bool get isPending => status == 'pending';
  bool get isCompleted => status == 'delivered' || status == 'picked_up';
  bool get isPacked => status == 'packed';
  bool get isCancelled => status == 'cancelled';
}

class OrderItem {
  final String id;
  final String orderId;
  final String productId;
  final String productName;
  final String? productImage;
  final int quantity;
  final double unitPrice;
  final double discountPercent;
  final double totalPrice;
  
  OrderItem({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.productName,
    this.productImage,
    required this.quantity,
    required this.unitPrice,
    this.discountPercent = 0,
    required this.totalPrice,
  });
  
  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'].toString(),
      orderId: json['order_id'].toString(),
      productId: json['product_id'].toString(),
      productName: json['product_name'].toString(),
      productImage: json['product_image'] as String?,
      quantity: json['quantity'] as int,
      unitPrice: (json['unit_price'] as num).toDouble(),
      discountPercent: (json['discount_percent'] as num?)?.toDouble() ?? 0,
      totalPrice: (json['total_price'] as num).toDouble(),
    );
  }
}

class DeliveryAddress {
  final String line1;
  final String? line2;
  final String city;
  final String state;
  final String pincode;
  final String? landmark;
  
  DeliveryAddress({
    required this.line1,
    this.line2,
    required this.city,
    required this.state,
    required this.pincode,
    this.landmark,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'line1': line1,
      'line2': line2,
      'city': city,
      'state': state,
      'pincode': pincode,
      'landmark': landmark,
    };
  }
  
  factory DeliveryAddress.fromJson(Map<String, dynamic> json) {
    return DeliveryAddress(
      line1: json['line1'] as String,
      line2: json['line2'] as String?,
      city: json['city'] as String,
      state: json['state'] as String,
      pincode: json['pincode'] as String,
      landmark: json['landmark'] as String?,
    );
  }
  
  String get fullAddress {
    final parts = [line1, line2, city, state, pincode].where((p) => p != null && p.isNotEmpty);
    return parts.join(', ');
  }
}

class Coupon {
  final String id;
  final String code;
  final String? description;
  final String discountType; // 'percent' or 'flat'
  final double discountValue;
  final double minOrderAmount;
  final double? maxDiscountAmount;
  
  Coupon({
    required this.id,
    required this.code,
    this.description,
    required this.discountType,
    required this.discountValue,
    this.minOrderAmount = 0,
    this.maxDiscountAmount,
  });
  
  factory Coupon.fromJson(Map<String, dynamic> json) {
    return Coupon(
      id: json['id'] as String,
      code: json['code'] as String,
      description: json['description'] as String?,
      discountType: json['discount_type'] as String,
      discountValue: (json['discount_value'] as num).toDouble(),
      minOrderAmount: (json['min_order_amount'] as num?)?.toDouble() ?? 0,
      maxDiscountAmount: (json['max_discount_amount'] as num?)?.toDouble(),
    );
  }
  
  double calculateDiscount(double subtotal) {
    if (subtotal < minOrderAmount) return 0;
    
    double discount;
    if (discountType == 'percent') {
      discount = (subtotal * discountValue) / 100;
      if (maxDiscountAmount != null) {
        discount = discount > maxDiscountAmount! ? maxDiscountAmount! : discount;
      }
    } else {
      discount = discountValue;
    }
    
    return discount > subtotal ? subtotal : discount;
  }
}
