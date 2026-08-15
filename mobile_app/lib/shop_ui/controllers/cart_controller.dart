import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:b2b_store/shared/models/product.dart';
import 'package:b2b_store/core/services/api_client.dart' show ApiException;
import '../services/cms_service.dart';
import 'dart:async';

class CartController extends ChangeNotifier {
  List<CartItem> _items = [];
  final CmsService _cmsService = CmsService();

  bool showCartPopup = false;
  bool isCartActive = false; // Add this to track Cart screen visibility
  
  void setMenuCartActive(bool active) {
    if (isCartActive != active) {
      isCartActive = active;
      // We schedule the notification to avoid "setState or markNeedsBuild called during build" errors
      // if this is triggered from a build method.
      Future.microtask(() => notifyListeners());
    }
  }

  Timer? _popupTimer;

  void _triggerCartPopup() {
    showCartPopup = true;
    notifyListeners();
  }

  CartController() {
    debugPrint("--- CartController Initialized ---");
    loadCart();
  }

  List<CartItem> get items => _items;

  int get totalItems => _items.fold(0, (sum, item) => sum + item.quantity);

  double get subtotal => _items.fold(
      0, (sum, item) {
        final price = item.product.discountedPrice > 0 ? item.product.discountedPrice : item.product.price;
        return sum + price * item.quantity;
      });

  double get total => (subtotal - couponDiscount) + deliveryFee;

  double deliveryFee = 50; 
  double couponDiscount = 0;
  String? appliedCouponCode;
  bool isDelivery = true;

  /// Id of the saved Address chosen for this order. The backend snapshots the
  /// address from this id, so the order keeps the values it was placed with.
  String? selectedAddressId;

  String? customDeliveryAddress;
  String? customLocationUrl;
  double? customLatitude;
  double? customLongitude;
  String? customHouseNumber;
  String? customLandmark;
  String? customPhone;

  static const _cartPrefsKey = 'cart_items';

  Future<void> _saveCart() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _items.map((item) => item.toJson()).toList();
    await prefs.setString(_cartPrefsKey, json.encode(data));
  }

  Future<void> loadCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final content = prefs.getString(_cartPrefsKey);
      if (content != null) {
        debugPrint("Loading cart from storage: $content");
        final List<dynamic> data = json.decode(content);
        _items = data.map((item) => CartItem.fromJson(item)).toList();
        debugPrint("Cart loaded. Items count: ${_items.length}");
        notifyListeners();
      } else {
        debugPrint("No saved cart found.");
      }
    } catch (e) {
      debugPrint("Error loading cart: $e");
    }
  }

  void toggleDelivery(bool value) {
    isDelivery = value;
    deliveryFee = isDelivery ? 50 : 0;
    notifyListeners();
  }

  Future<String?> applyCoupon(String code) async {
    try {
      final result = await _cmsService.validateCoupon(code, orderAmount: subtotal);
      couponDiscount = (result['discount_amount'] as num?)?.toDouble() ?? 0;
      appliedCouponCode = code.toUpperCase();
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return "Invalid or expired coupon code";
    }
  }

  void removeCoupon() {
    couponDiscount = 0;
    appliedCouponCode = null;
    notifyListeners();
  }

  void addToCart(Product product) {
    debugPrint("ACTION: Adding product to cart: ${product.name} (ID: ${product.id})");
    final index = _items.indexWhere((item) => item.product.id == product.id || item.product.name == product.name);
    if (index >= 0) {
      _items[index] = _items[index].copyWith(quantity: _items[index].quantity + 1);
      debugPrint("Item already in cart. Incrementing quantity to: ${_items[index].quantity}");
    } else {
      _items.add(CartItem(product: product, quantity: 1));
      debugPrint("New item added to cart.");
    }
    debugPrint("Total items in cart memory now: ${_items.length}");
    if (appliedCouponCode != null) applyCoupon(appliedCouponCode!);
    _saveCart();
    _triggerCartPopup();
    debugPrint("notifyListeners() called.");
  }

  int indexOfProduct(Product product) {
    return _items.indexWhere((item) =>
        item.product.id == product.id || item.product.name == product.name);
  }

  int quantityForProduct(Product product) {
    final index = indexOfProduct(product);
    return index >= 0 ? _items[index].quantity : 0;
  }

  void incrementProduct(Product product) {
    final index = indexOfProduct(product);
    if (index >= 0) {
      incrementQuantity(index);
    } else {
      addToCart(product);
    }
  }

  void decrementProduct(Product product) {
    final index = indexOfProduct(product);
    if (index >= 0) {
      decrementQuantity(index);
    }
  }

  void removeFromCart(int index) {
    _items.removeAt(index);
    if (_items.isEmpty) removeCoupon();
    _saveCart();
    notifyListeners();
  }

  void incrementQuantity(int index) {
    _items[index] = _items[index].copyWith(quantity: _items[index].quantity + 1);
    if (appliedCouponCode != null) applyCoupon(appliedCouponCode!);
    _saveCart();
    notifyListeners();
  }

  void decrementQuantity(int index) {
    if (_items[index].quantity > 1) {
      _items[index] = _items[index].copyWith(quantity: _items[index].quantity - 1);
    } else {
      _items.removeAt(index);
    }
    if (appliedCouponCode != null) applyCoupon(appliedCouponCode!);
    _saveCart();
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    removeCoupon();
    selectedAddressId = null;
    customDeliveryAddress = null;
    customLocationUrl = null;
    customLatitude = null;
    customLongitude = null;
    customHouseNumber = null;
    customLandmark = null;
    customPhone = null;
    _saveCart();
    notifyListeners();
  }
}
