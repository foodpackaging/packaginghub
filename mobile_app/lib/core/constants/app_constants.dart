class AppConstants {
  // App Info
  static const String appName = 'B2B Store';
  static const String appVersion = '1.0.0';
  
  // API & Storage
  static const int apiTimeout = 30; // seconds
  static const int cacheMaxAge = 3600; // 1 hour in seconds
  
  // Pagination
  static const int productsPerPage = 20;
  static const int ordersPerPage = 20;
  
  // Delivery
  static const double defaultDeliveryCharge = 50.0;
  static const double freeDeliveryAbove = 500.0;
  static const int defaultEtaMinutes = 45;
  
  // Cart
  static const String cartStorageKey = 'cart_items';
  
  // Order Status
  static const List<String> orderStatuses = [
    'pending',
    'confirmed',
    'preparing',
    'ready',
    'out_for_delivery',
    'delivered',
    'picked_up',
    'cancelled',
  ];
  
  // Company Types
  static const Map<String, String> companyTypes = {
    'restaurant': '🍽️ Restaurant',
    'factory': '🏭 Factory',
    'other': '🏢 Other',
  };
  
  // Roles
  static const Map<String, String> roles = {
    'owner': '👑 Owner',
    'manager': '💼 Manager',
    'staff': '👤 Staff',
  };
  
  // Support
  static const String supportEmail = 'support@b2bstore.com';
  static const String supportPhone = '+91 9999999999';
  static const String termsUrl = 'https://b2bstore.com/terms';
  static const String privacyUrl = 'https://b2bstore.com/privacy';
}
