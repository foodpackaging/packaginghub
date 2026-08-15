import 'package:b2b_store/shop_ui/constants.dart';
import 'package:b2b_store/shop_ui/controllers/cart_controller.dart';
import 'package:b2b_store/shop_ui/route/route_constants.dart';
import 'package:b2b_store/shop_ui/services/order_checkout_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:b2b_store/shop_ui/components/address/delivery_address_selector.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final OrderCheckoutService _orderCheckoutService = OrderCheckoutService();

  bool _isPlacingOrder = false;

  // Address loading, GPS capture and manual entry now live in
  // DeliveryAddressSelector / AddressForm, which read the saved address book
  // directly — this screen no longer pre-fills anything from the profile.

  Future<void> _placePickupOrder(CartController cart) async {
    setState(() => _isPlacingOrder = true);
    try {
      cart.toggleDelivery(false);
      final orderId = await _orderCheckoutService.placeOrder(
        cart: cart,
        paymentMethod: 'pay_at_store',
      );
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        thanksForOrderScreenRoute,
        (route) => false,
        arguments: orderId,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: errorColor),
        );
      }
    } finally {
      if (mounted) setState(() => _isPlacingOrder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: Consumer<CartController>(
        builder: (context, cart, child) {
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(defaultPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'How would you like to receive your order?',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: defaultPadding),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius:
                              BorderRadius.circular(defaultBorderRadious),
                          border:
                              Border.all(color: Theme.of(context).dividerColor),
                        ),
                        child: Column(
                          children: [
                            RadioListTile<bool>(
                              value: true,
                              groupValue: cart.isDelivery,
                              onChanged: (_) => cart.toggleDelivery(true),
                              title: const Text('Delivery to your address'),
                              subtitle: const Text(
                                  'Get it delivered to your doorstep'),
                              secondary: const Icon(Icons.delivery_dining,
                                  color: primaryColor),
                            ),
                            if (cart.isDelivery)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(defaultPadding, 0, defaultPadding, defaultPadding),
                                // Saved addresses only — the user never retypes an
                                // address they already have on file.
                                child: DeliveryAddressSelector(
                                  selectedId: cart.selectedAddressId,
                                  onSelected: (address) {
                                    setState(() {
                                      cart.selectedAddressId = address?.id;
                                      // Mirror into the legacy fields so the order
                                      // summary and pickup path keep working.
                                      cart.customDeliveryAddress = address?.formatted;
                                      cart.customLandmark = address?.landmark;
                                      cart.customPhone = address?.contactPhone;
                                      cart.customLatitude = address?.latitude;
                                      cart.customLongitude = address?.longitude;
                                    });
                                  },
                                ),
                              ),
                            const Divider(height: 1),
                            RadioListTile<bool>(
                              value: false,
                              groupValue: cart.isDelivery,
                              onChanged: (_) => cart.toggleDelivery(false),
                              title: const Text('Pickup from store'),
                              subtitle: const Text(
                                  'Pick it up yourself from our location'),
                              secondary:
                                  const Icon(Icons.store, color: primaryColor),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: defaultPadding * 2),
                      Text(
                        'Order Summary',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: defaultPadding),
                      _SummaryCard(cart: cart),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(defaultPadding),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -5)),
                  ],
                ),
                child: SafeArea(
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isPlacingOrder
                          ? null
                          : () {
                              if (cart.isDelivery) {
                                Navigator.pushNamed(
                                    context, paymentMethodScreenRoute);
                              } else {
                                _placePickupOrder(cart);
                              }
                            },
                      child: _isPlacingOrder
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              cart.isDelivery
                                  ? 'Continue to Payment'
                                  : 'Place Pickup Order',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.cart});

  final CartController cart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(defaultPadding),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(defaultBorderRadious),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          _SummaryRow(
              label: 'Items Total',
              value: '\u20B9${cart.subtotal.toStringAsFixed(2)}'),
          if (cart.couponDiscount > 0) ...[
            const SizedBox(height: 8),
            _SummaryRow(
                label: 'Coupon Discount',
                value:
                    '- \u20B9${cart.couponDiscount.toStringAsFixed(2)}'),
          ],
          const SizedBox(height: 8),
          _SummaryRow(
              label: 'Delivery Fee',
              value: cart.isDelivery
                  ? '\u20B9${cart.deliveryFee.toStringAsFixed(2)}'
                  : 'FREE'),
          const Divider(height: 24),
          _SummaryRow(
            label: 'Total Amount',
            value: '\u20B9${cart.total.toStringAsFixed(2)}',
            isTotal: true,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(
      {required this.label, required this.value, this.isTotal = false});

  final String label;
  final String value;
  final bool isTotal;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontWeight:
                    isTotal ? FontWeight.bold : FontWeight.normal)),
        Text(
          value,
          style: TextStyle(
            color: isTotal ? primaryColor : null,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            fontSize: isTotal ? 18 : null,
          ),
        ),
      ],
    );
  }
}
