import 'package:b2b_store/core/services/api_client.dart';
import 'package:b2b_store/shared/services/api_service.dart';
import 'package:b2b_store/shop_ui/controllers/cart_controller.dart';
import 'package:uuid/uuid.dart';

class OrderCheckoutService {
  final ApiService _apiService = ApiService();
  final ApiClient _client = ApiClient.instance;

  // One key per screen visit (this service is a State field, recreated only
  // when the checkout/payment screen itself is), reused across every
  // placeOrder() call made through this instance — so a double tap or a
  // retry after a timeout carries the SAME key, and the backend returns the
  // order already created the first time instead of creating a second one.
  // See POST /api/orders' Idempotency-Key handling.
  final String _idempotencyKey = const Uuid().v4();

  Future<String> placeOrder({
    required CartController cart,
    required String paymentMethod,
    String paymentStatus = 'pending',
    bool clearCart = true,
  }) async {
    if (cart.items.isEmpty) {
      throw Exception('Your cart is empty.');
    }

    final profile = await _apiService.getProfile();
    if (profile == null) {
      throw Exception('Please log in before placing an order.');
    }

    // Resolve coordinates — cart values take priority over saved profile values
    final lat = cart.customLatitude ?? profile.latitude;
    final lng = cart.customLongitude ?? profile.longitude;

    // Build a precise coordinate-based Google Maps URL
    String? locationUrl;
    if (lat != null && lng != null) {
      locationUrl = 'https://www.google.com/maps?q=$lat,$lng';
    } else if (cart.customLocationUrl != null) {
      locationUrl = cart.customLocationUrl;
    }

    if (cart.isDelivery && cart.selectedAddressId == null) {
      throw Exception('Please choose a delivery address before placing the order.');
    }

    // Only product id + quantity go to the server for pricing — the backend
    // fetches the real price, checks stock/MOQ, and computes every total
    // itself (see routes/orders.js). Nothing price-related sent from here is
    // trusted; it's kept out of the payload entirely rather than sent and ignored.
    final order = await _apiService.createOrder(
      {
        'delivery_method': cart.isDelivery ? 'delivery' : 'pickup',
        'payment_method': paymentMethod,
        'coupon_code': cart.appliedCouponCode,
        // The server snapshots the address from this id, so the order keeps the
        // values it was placed with even if the address is later edited or deleted.
        if (cart.isDelivery && cart.selectedAddressId != null)
          'address_id': cart.selectedAddressId,
        // Retained for pickup orders and as a fallback for older payloads.
        'delivery_address': {
          'name': ((profile.fullName).trim().isNotEmpty)
              ? profile.fullName
              : (profile.email.split('@').first),
          'email': profile.email,
          'phone': cart.customPhone ?? profile.phone,
          'company_type': profile.companyType,
          'gst_number': profile.gstNumber,
          if (cart.isDelivery)
            'address': cart.customDeliveryAddress ?? profile.address,
          if (cart.isDelivery && cart.customHouseNumber != null)
            'house_number': cart.customHouseNumber,
          if (cart.isDelivery && cart.customLandmark != null)
            'landmark': cart.customLandmark,
          if (lat != null) 'latitude': lat,
          if (lng != null) 'longitude': lng,
          if (locationUrl != null) 'location_url': locationUrl,
        },
        'items': cart.items
            .map((item) => {
                  'product_id': item.product.id,
                  'quantity': item.quantity,
                })
            .toList(),
      },
      idempotencyKey: _idempotencyKey,
    );

    if (clearCart) cart.clearCart();
    return order.id;
  }

  /// Creates the Razorpay-side order via the backend. The amount is never
  /// sent from here — the backend computes it from the order's own
  /// server-side total (order.totalAmount), so there's nothing for a client
  /// to tamper with in this call.
  Future<Map<String, dynamic>> createRazorpayOrder(String appOrderId) async {
    try {
      final response = await _client.post('/payments/razorpay/create-order', body: {'app_order_id': appOrderId});
      return response as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to communicate with payment gateway: $e');
    }
  }

  /// Verifies the Razorpay signature and marks the order paid via the backend.
  Future<bool> verifyRazorpayPayment({
    required String orderId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    try {
      final response = await _client.post('/payments/razorpay/verify', body: {
        'app_order_id': orderId,
        'order_id': razorpayOrderId,
        'payment_id': razorpayPaymentId,
        'signature': razorpaySignature,
      });
      return response['success'] == true;
    } catch (e) {
      throw Exception('Payment verification failed: $e');
    }
  }

  /// Flags a prepaid order whose gateway payment failed.
  ///
  /// The order row already exists by the time Razorpay's sheet opens, so
  /// without this it would sit at `pending` forever with nothing telling the
  /// customer why. The server marks it failed and notifies them to retry.
  Future<void> reportRazorpayFailure({required String orderId, String? reason}) async {
    try {
      await _client.post('/payments/razorpay/failed', body: {
        'app_order_id': orderId,
        if (reason != null) 'reason': reason,
      });
    } catch (_) {
      // Best-effort: the customer already saw the failure on screen.
    }
  }
}
