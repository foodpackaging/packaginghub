class ReturnItem {
  final String orderItemId;
  final String productName;
  final int quantity;
  final double itemTotal;
  final double refundAmount;

  ReturnItem({
    required this.orderItemId,
    required this.productName,
    required this.quantity,
    required this.itemTotal,
    required this.refundAmount,
  });

  factory ReturnItem.fromJson(Map<String, dynamic> json) {
    return ReturnItem(
      orderItemId: json['order_item_id'] as String? ?? '',
      productName: json['product_name'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      itemTotal: (json['item_total'] as num?)?.toDouble() ?? 0,
      refundAmount: (json['refund_amount'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'order_item_id': orderItemId,
        'product_name': productName,
        'quantity': quantity,
        'item_total': itemTotal,
        'refund_amount': refundAmount,
      };
}

class ReturnRequest {
  final String id;
  final String orderId;
  final String userId;
  final String reason;
  final String status;
  // 'pending' | 'approved' | 'rejected' | 'pickup_scheduled' | 'drop_off_pending' | 'received' | 'refunded'
  final String? returnMethod; // 'drop_off' | 'pickup'
  final DateTime? pickupDate;
  final String? adminNotes;
  final List<ReturnItem> returnItems;
  final double refundAmount;
  final DateTime createdAt;
  final DateTime updatedAt;

  ReturnRequest({
    required this.id,
    required this.orderId,
    required this.userId,
    required this.reason,
    required this.status,
    this.returnMethod,
    this.pickupDate,
    this.adminNotes,
    this.returnItems = const [],
    this.refundAmount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ReturnRequest.fromJson(Map<String, dynamic> json) {
    final rawItems = json['return_items'];
    List<ReturnItem> items = [];
    if (rawItems is List) {
      items = rawItems
          .whereType<Map<String, dynamic>>()
          .map((e) => ReturnItem.fromJson(e))
          .toList();
    }

    return ReturnRequest(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      userId: json['user_id'] as String,
      reason: json['reason'] as String,
      status: json['status'] as String,
      returnMethod: json['return_method'] as String?,
      pickupDate: json['pickup_date'] != null
          ? DateTime.parse(json['pickup_date'] as String)
          : null,
      adminNotes: json['admin_notes'] as String?,
      returnItems: items,
      refundAmount: (json['refund_amount'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
    );
  }

  /// IDs of order items included in this return request
  Set<String> get returnedItemIds =>
      returnItems.map((i) => i.orderItemId).toSet();

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isPickupScheduled => status == 'pickup_scheduled';
  bool get isDropOffPending => status == 'drop_off_pending';
  bool get isReceived => status == 'received';
  bool get isRefunded => status == 'refunded';

  String get statusLabel {
    switch (status) {
      case 'pending':         return 'Return Requested';
      case 'approved':        return 'Return Approved';
      case 'rejected':        return 'Return Rejected';
      case 'pickup_scheduled':return 'Pickup Scheduled';
      case 'drop_off_pending':return 'Drop-off Pending';
      case 'received':        return 'Item Received';
      case 'refunded':        return 'Refunded';
      default:                return status;
    }
  }
}
