import 'package:b2b_store/shop_ui/route/route_constants.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:b2b_store/shop_ui/controllers/cart_controller.dart';
import 'package:b2b_store/shop_ui/constants.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final TextEditingController _couponController = TextEditingController();
  bool _isApplying = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  Future<void> _handleApplyCoupon(CartController cart) async {
    if (_couponController.text.trim().isEmpty) return;
    
    setState(() => _isApplying = true);
    final error = await cart.applyCoupon(_couponController.text.trim());
    setState(() => _isApplying = false);

    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        )
      );
    } else {
      _couponController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color accentColor = accentRed;
    const Color primaryText = navyDark;
    const Color bgColor = Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: primaryText),
        title: const Text("View Cart", style: TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
      ),
      body: Consumer<CartController>(
        builder: (context, cart, child) {
          if (cart.items.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text("Your cart is empty", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  itemCount: cart.items.length,
                  separatorBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Divider(color: Colors.grey[300], height: 1),
                  ),
                  itemBuilder: (context, index) {
                    final item = cart.items[index];
                    final price = item.product.discountedPrice > 0 ? item.product.discountedPrice : item.product.price;
                    final originalPrice = item.product.price;
                    final hasDiscount = item.product.discountedPrice > 0 && item.product.discountedPrice < originalPrice;

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 70,
                              height: 70,
                              color: const Color(0xFFF5F5F5),
                              child: item.product.image.isNotEmpty
                                  ? Image.network(item.product.image, fit: BoxFit.cover)
                                  : const Icon(Icons.image_not_supported, color: Colors.grey),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.product.name,
                                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15, color: primaryText),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () => cart.removeFromCart(index),
                                      child: const Icon(Icons.delete_outline, color: accentColor, size: 22),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          "₹${price.toStringAsFixed(2)}",
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryText),
                                        ),
                                        if (hasDiscount) ...[
                                          const SizedBox(width: 6),
                                          Text(
                                            "₹${originalPrice.toStringAsFixed(2)}",
                                            style: TextStyle(
                                              color: Colors.grey[400],
                                              fontSize: 13,
                                              decoration: TextDecoration.lineThrough,
                                            ),
                                          ),
                                        ]
                                      ],
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        GestureDetector(
                                          onTap: () => cart.decrementQuantity(index),
                                          child: Icon(Icons.remove_circle_outline, color: accentColor, size: 24),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          child: Text(
                                            "${item.quantity}",
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: primaryText),
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () => cart.incrementQuantity(index),
                                          child: Icon(Icons.add_circle_outline, color: accentColor, size: 24),
                                        ),
                                      ],
                                    )
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              
              // Bottom Section
              Container(
                decoration: BoxDecoration(
                  color: bgColor,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))
                  ],
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Coupon Section
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        child: cart.appliedCouponCode == null
                            ? Row(
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      height: 40,
                                      child: TextField(
                                        controller: _couponController,
                                        style: const TextStyle(fontSize: 14),
                                        decoration: InputDecoration(
                                          hintText: "Avail Offers/ Coupons",
                                          hintStyle: TextStyle(color: primaryText.withOpacity(0.6), fontSize: 14, fontWeight: FontWeight.w500),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(color: Colors.grey[300]!),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(color: Colors.grey[300]!),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: const BorderSide(color: accentColor),
                                          ),
                                        ),
                                        onSubmitted: (value) => _handleApplyCoupon(cart),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton(
                                    onPressed: _isApplying ? null : () => _handleApplyCoupon(cart),
                                    style: TextButton.styleFrom(foregroundColor: accentColor),
                                    child: _isApplying 
                                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: accentColor))
                                      : const Text("Apply", style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: accentColor.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: accentColor.withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.local_offer_outlined, color: accentColor, size: 18),
                                        const SizedBox(width: 8),
                                        Text("Coupon: ${cart.appliedCouponCode}",
                                            style: const TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    GestureDetector(
                                      onTap: () => cart.removeCoupon(),
                                      child: const Icon(Icons.close, color: accentColor, size: 20),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                      
                      // Summary Box
                      Container(
                        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Item Amount", style: TextStyle(color: primaryText.withOpacity(0.8), fontSize: 14)),
                                Text("₹${cart.subtotal.toStringAsFixed(2)}", style: const TextStyle(color: primaryText, fontWeight: FontWeight.w600, fontSize: 14)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Discount", style: TextStyle(color: primaryText.withOpacity(0.8), fontSize: 14)),
                                Text("₹${cart.couponDiscount.toStringAsFixed(2)}", style: const TextStyle(color: primaryText, fontWeight: FontWeight.w600, fontSize: 14)),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Divider(color: Colors.grey[300], height: 1),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("Total Amount", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryText)),
                                Text("₹${(cart.subtotal - cart.couponDiscount).toStringAsFixed(2)}",
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: primaryText)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: accentColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                onPressed: () {
                                  Navigator.pushNamed(context, checkoutScreenRoute);
                                },
                                child: const Text("PROCEED TO CHECKOUT", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            ],
          );
        },
      ),
    );
  }
}
