import 'package:b2b_store/core/services/api_client.dart';
import '../models/app_notification.dart';
import '../models/user_profile.dart';
import '../models/product.dart';
import '../models/order.dart';
import '../models/return_request.dart';

class ApiService {
  final ApiClient _client = ApiClient.instance;

  // ==================== PROFILE ====================

  Future<UserProfile?> getProfile() async {
    try {
      final response = await _client.get('/auth/me');
      return UserProfile.fromJson(response['user'] as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  Future<UserProfile> updateProfile(Map<String, dynamic> data) async {
    final response = await _client.patch('/profile', body: data);
    return UserProfile.fromJson(response['profile'] as Map<String, dynamic>);
  }

  Future<UserProfile> completeOnboarding(Map<String, dynamic> data) async {
    final response = await _client.post('/profile/complete-onboarding', body: data);
    return UserProfile.fromJson(response['profile'] as Map<String, dynamic>);
  }

  // ==================== PRODUCTS ====================

  Future<List<Product>> getProducts({
    String? categoryId,
    String? search,
    bool? featured,
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _client.get('/products', query: {
      if (categoryId != null) 'category_id': categoryId,
      if (search != null) 'search': search,
      if (featured != null) 'featured': featured,
      'limit': limit,
      'skip': offset,
    });
    return ((response['products'] as List?) ?? []).map((json) => Product.fromJson(json)).toList();
  }

  Future<Product?> getProductById(String id) async {
    try {
      final response = await _client.get('/products/$id');
      return Product.fromJson(response['product'] as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  Future<List<Category>> getCategories() async {
    final response = await _client.get('/categories', query: {'parent_id': 'null'});
    return ((response['categories'] as List?) ?? []).map((json) => Category.fromJson(json)).toList();
  }

  // ==================== ORDERS ====================

  Future<Order> createOrder(Map<String, dynamic> orderData) async {
    final response = await _client.post('/orders', body: orderData);
    return Order.fromJson(response['order'] as Map<String, dynamic>);
  }

  Future<List<Order>> getMyOrders() async {
    final response = await _client.get('/orders/mine');
    return ((response['orders'] as List?) ?? []).map((json) => Order.fromJson(json)).toList();
  }

  Future<Order?> getOrderById(String orderId) async {
    try {
      final response = await _client.get('/orders/$orderId');
      return Order.fromJson(response['order'] as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  Stream<Order?> watchOrder(String orderId) async* {
    while (true) {
      final order = await getOrderById(orderId);
      if (order != null) yield order;
      await Future.delayed(const Duration(seconds: 5));
    }
  }

  // ==================== RETURNS ====================

  Future<ReturnRequest> createReturnRequest({
    required String orderId,
    required String reason,
    String? returnMethod,
    required List<Map<String, dynamic>> returnItems,
    required double refundAmount,
  }) async {
    final response = await _client.post('/returns', body: {
      'order_id': orderId,
      'reason': reason,
      if (returnMethod != null) 'return_method': returnMethod,
      'return_items': returnItems,
      'refund_amount': refundAmount,
    });
    return ReturnRequest.fromJson(response['return_request'] as Map<String, dynamic>);
  }

  Future<List<ReturnRequest>> getReturnRequestsForOrder(String orderId) async {
    try {
      final response = await _client.get('/returns/order/$orderId');
      return ((response['return_requests'] as List?) ?? [])
          .map((json) => ReturnRequest.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Live-streams all return requests for an order, polling every 5 seconds.
  Stream<List<ReturnRequest>> watchReturnRequestsForOrder(String orderId) async* {
    while (true) {
      yield await getReturnRequestsForOrder(orderId);
      await Future.delayed(const Duration(seconds: 5));
    }
  }

  Future<List<ReturnRequest>> getMyReturnRequests() async {
    try {
      final response = await _client.get('/returns/mine');
      return ((response['return_requests'] as List?) ?? [])
          .map((json) => ReturnRequest.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<ReturnRequest?> getReturnRequestById(String id) async {
    try {
      final response = await _client.get('/returns/$id');
      return ReturnRequest.fromJson(response['return_request'] as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  // ==================== COUPONS ====================

  Future<Coupon?> validateCoupon(String code, double orderAmount) async {
    try {
      final response = await _client.post('/coupons/validate', body: {
        'code': code,
        'order_amount': orderAmount,
      });
      return Coupon.fromJson(response['coupon'] as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  // ==================== NOTIFICATIONS ====================

  Future<NotificationFeed> getNotifications({int limit = 50}) async {
    final response = await _client.get('/notifications', query: {'limit': limit});
    return NotificationFeed(
      notifications: ((response['notifications'] as List?) ?? [])
          .map((json) => AppNotification.fromJson(json as Map<String, dynamic>))
          .toList(),
      unreadCount: (response['unread_count'] as num?)?.toInt() ?? 0,
    );
  }

  Future<int> getUnreadNotificationCount() async {
    try {
      final response = await _client.get('/notifications/unread-count');
      return (response['unread_count'] as num?)?.toInt() ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Future<void> markNotificationRead(String id) async {
    try {
      await _client.patch('/notifications/$id/read');
    } catch (_) {
      // Read state is a convenience; failing to sync it must not break the inbox.
    }
  }

  Future<void> markAllNotificationsRead() async {
    await _client.post('/notifications/read-all');
  }

  // ==================== PUSH DEVICE TOKENS ====================

  Future<void> registerDeviceToken({
    required String token,
    required String platform,
  }) async {
    await _client.post('/devices', body: {'token': token, 'platform': platform});
  }

  Future<void> unregisterDeviceToken(String token) async {
    await _client.delete('/devices', body: {'token': token});
  }
}

/// The inbox list plus its unread count, which the server returns together so
/// the badge and the list can never disagree.
class NotificationFeed {
  final List<AppNotification> notifications;
  final int unreadCount;

  const NotificationFeed({required this.notifications, required this.unreadCount});
}
