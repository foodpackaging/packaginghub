import 'package:flutter/material.dart';

/// One entry in the customer's notification inbox, mirroring the server record
/// behind every push we send.
class AppNotification {
  final String id;
  final String type;
  final String title;
  final String body;
  final String? orderId;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.orderId,
    this.data = const {},
    this.isRead = false,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'].toString(),
      type: (json['type'] ?? 'general').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      orderId: json['order_id']?.toString(),
      data: (json['data'] as Map?)?.cast<String, dynamic>() ?? const {},
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        type: type,
        title: title,
        body: body,
        orderId: orderId,
        data: data,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
      );

  /// Icon shown in the inbox row, chosen to match the stage of the order.
  IconData get icon {
    switch (type) {
      case 'order_placed':
        return Icons.receipt_long_outlined;
      case 'payment_pending':
        return Icons.hourglass_bottom_outlined;
      case 'payment_success':
        return Icons.verified_outlined;
      case 'payment_failed':
        return Icons.error_outline;
      case 'order_accepted':
        return Icons.storefront_outlined;
      case 'order_packed':
        return Icons.inventory_2_outlined;
      case 'order_ready_for_pickup':
        return Icons.shopping_bag_outlined;
      case 'eta_set':
        return Icons.schedule_outlined;
      case 'order_delayed':
        return Icons.running_with_errors_outlined;
      case 'out_for_delivery':
        return Icons.local_shipping_outlined;
      case 'order_delivered':
      case 'order_picked_up':
        return Icons.check_circle_outline;
      case 'order_cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  /// Colour accent for the row icon. Problems read red, completions green.
  Color get accentColor {
    switch (type) {
      case 'payment_failed':
      case 'order_cancelled':
        return const Color(0xFFE53935);
      case 'order_delayed':
      case 'payment_pending':
        return const Color(0xFFF57C00);
      case 'order_delivered':
      case 'order_picked_up':
      case 'payment_success':
        return const Color(0xFF2E7D32);
      default:
        return const Color(0xFF1E3A5F);
    }
  }
}
