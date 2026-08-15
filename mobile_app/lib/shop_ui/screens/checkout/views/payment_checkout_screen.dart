import 'package:b2b_store/shop_ui/constants.dart';
import 'package:b2b_store/shop_ui/controllers/cart_controller.dart';
import 'package:b2b_store/shop_ui/route/route_constants.dart';
import 'package:b2b_store/shop_ui/services/order_checkout_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PaymentCheckoutScreen extends StatefulWidget {
  const PaymentCheckoutScreen({super.key});

  @override
  State<PaymentCheckoutScreen> createState() => _PaymentCheckoutScreenState();
}

class _PaymentCheckoutScreenState extends State<PaymentCheckoutScreen> {
  final OrderCheckoutService _orderCheckoutService = OrderCheckoutService();
  String _paymentMethod = 'online';
  bool _isPlacingOrder = false;
  late Razorpay _razorpay;
  String? _currentPendingOrderId;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    if (_currentPendingOrderId == null) return;
    setState(() => _isPlacingOrder = true);
    
    try {
      final success = await _orderCheckoutService.verifyRazorpayPayment(
        orderId: _currentPendingOrderId!,
        razorpayOrderId: response.orderId!,
        razorpayPaymentId: response.paymentId!,
        razorpaySignature: response.signature!,
      );

      if (success && mounted) {
        final cart = context.read<CartController>();
        cart.clearCart();
        Navigator.pushNamedAndRemoveUntil(
          context,
          thanksForOrderScreenRoute,
          (route) => false,
          arguments: _currentPendingOrderId,
        );
      } else {
        throw Exception('Signature verification failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment verification failed: $e'), backgroundColor: errorColor),
        );
      }
    } finally {
      if (mounted) setState(() => _isPlacingOrder = false);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    // Backing out of the payment sheet isn't a failure worth flagging on the
    // order or pushing a notification about — the customer chose to stop.
    final userCancelled = response.code == Razorpay.PAYMENT_CANCELLED;
    if (!userCancelled && _currentPendingOrderId != null) {
      _orderCheckoutService.reportRazorpayFailure(
        orderId: _currentPendingOrderId!,
        reason: response.message,
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment failed: ${response.message ?? "User cancelled"}'),
          backgroundColor: errorColor,
        ),
      );
      setState(() => _isPlacingOrder = false);
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('External Wallet Selected: ${response.walletName}')),
      );
      // Wait for user to actually complete payment via the wallet, so we don't drop loading state yet
    }
  }

  Future<void> _placeOrder(CartController cart) async {
    setState(() => _isPlacingOrder = true);
    try {
      cart.toggleDelivery(true);

      // Snapshot total BEFORE anything async clears the cart
      final totalAmount = cart.total;
      
      if (_paymentMethod == 'online') {
        // 1. Create the order with 'pending' status — do NOT clear cart yet
        final orderId = await _orderCheckoutService.placeOrder(
          cart: cart,
          paymentMethod: 'online',
          paymentStatus: 'pending',
          clearCart: false, // Cart cleared only after successful payment
        );
        _currentPendingOrderId = orderId;

        // 2. Create Razorpay order via Edge Function using snapshotted total
        final razorpayOrder = await _orderCheckoutService.createRazorpayOrder(totalAmount);
        
        // 3. Open Razorpay UI
        var options = {
          'key': dotenv.env['RAZORPAY_KEY_ID'] ?? '',
          'amount': (totalAmount * 100).round(),
          'name': 'B2B Store',
          'description': 'Order Payment',
          'order_id': razorpayOrder['id'],
          'prefill': {
            'contact': '',
            'email': ''
          }
        };
        _razorpay.open(options);
        // Do not set _isPlacingOrder = false here, wait for callbacks
      } else {
        // Cash on Delivery — clear cart as usual
        final orderId = await _orderCheckoutService.placeOrder(
          cart: cart,
          paymentMethod: 'cod',
          paymentStatus: 'pending',
        );
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(
          context,
          thanksForOrderScreenRoute,
          (route) => false,
          arguments: orderId,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: errorColor),
        );
        setState(() => _isPlacingOrder = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: Consumer<CartController>(
        builder: (context, cart, child) {
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(defaultPadding),
                  children: [
                    Text(
                      'How would you like to pay?',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: defaultPadding),
                    _PaymentOption(
                      value: 'online',
                      groupValue: _paymentMethod,
                      icon: Icons.payments_outlined,
                      title: 'Online Payment',
                      subtitle: 'UPI, Cards, Netbanking, Wallets',
                      onChanged: (value) => setState(() => _paymentMethod = value),
                    ),
                    _PaymentOption(
                      value: 'cod',
                      groupValue: _paymentMethod,
                      icon: Icons.currency_rupee,
                      title: 'Cash on delivery',
                      subtitle: 'Pay when your order arrives',
                      onChanged: (value) => setState(() => _paymentMethod = value),
                    ),
                    const SizedBox(height: defaultPadding * 2),
                    _SummaryCard(cart: cart),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(defaultPadding),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5)),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isPlacingOrder ? null : () => _placeOrder(cart),
                      child: _isPlacingOrder
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Place Order', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

class _PaymentOption extends StatelessWidget {
  const _PaymentOption({
    required this.value,
    required this.groupValue,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onChanged,
  });

  final String value;
  final String groupValue;
  final IconData icon;
  final String title;
  final String subtitle;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: selected ? primaryColor.withOpacity(0.06) : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(defaultBorderRadious),
        border: Border.all(color: selected ? primaryColor : Theme.of(context).dividerColor),
      ),
      child: RadioListTile<String>(
        value: value,
        groupValue: groupValue,
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        secondary: Icon(icon, color: primaryColor),
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
          _SummaryRow(label: 'Items Total', value: '\u20B9${cart.subtotal.toStringAsFixed(2)}'),
          const SizedBox(height: 8),
          _SummaryRow(label: 'Delivery Fee', value: '\u20B9${cart.deliveryFee.toStringAsFixed(2)}'),
          if (cart.couponDiscount > 0) ...[
            const SizedBox(height: 8),
            _SummaryRow(label: 'Discount', value: '- \u20B9${cart.couponDiscount.toStringAsFixed(2)}'),
          ],
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
  const _SummaryRow({required this.label, required this.value, this.isTotal = false});

  final String label;
  final String value;
  final bool isTotal;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
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
