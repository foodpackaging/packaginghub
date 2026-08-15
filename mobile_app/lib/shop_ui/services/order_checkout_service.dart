import 'package:b2b_store/core/services/api_client.dart';
import 'package:b2b_store/shared/services/api_service.dart';
import 'package:b2b_store/shop_ui/controllers/cart_controller.dart';

class OrderCheckoutService {
  final ApiService _apiService = ApiService();
  final ApiClient _client = ApiClient.instance;

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

    final order = await _apiService.createOrder({
      'delivery_method': cart.isDelivery ? 'delivery' : 'pickup',
      'payment_method': paymentMethod,
      'payment_status': paymentStatus,
      'subtotal': cart.subtotal,
      'discount_amount': cart.couponDiscount,
      'delivery_charge': cart.isDelivery ? cart.deliveryFee : 0,
      'total_amount': cart.total,
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
      'items': cart.items.map((item) {
        final unitPrice = item.product.discountedPrice > 0 ? item.product.discountedPrice : item.product.price;
        return {
          'product_id': item.product.id,
          'product_name': item.product.name,
          'product_image': item.product.image,
          'quantity': item.quantity,
          'unit_price': unitPrice,
          'discount_percent': item.product.discountPercent,
          'total_price': unitPrice * item.quantity,
        };
      }).toList(),
    });

    if (clearCart) cart.clearCart();
    return order.id;
  }

  /// Creates a Razorpay order via the backend.
  Future<Map<String, dynamic>> createRazorpayOrder(double amount) async {
    try {
      final response = await _client.post('/payments/razorpay/create-order', body: {'amount': amount});
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
