import 'package:b2b_store/shop_ui/components/cart/cart_quantity_control.dart';
import 'package:b2b_store/shop_ui/constants.dart';
import 'package:b2b_store/shop_ui/controllers/cart_controller.dart';
import 'package:b2b_store/shop_ui/route/navigator_key.dart';
import 'package:b2b_store/shop_ui/route/route_constants.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:b2b_store/shop_ui/components/cart_bottom_sheet.dart' as b2b_cart_sheet;

class CartSummaryBar extends StatelessWidget {
  const CartSummaryBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CartController>(
      builder: (context, cart, child) {
        // Show the bar whenever there are items in the cart
        if (cart.items.isEmpty) return const SizedBox.shrink();

        // Get up to 3 product images from cart
        final images = cart.items
            .map((item) => item.product.image)
            .where((img) => img.isNotEmpty)
            .take(3)
            .toList();

        return SafeArea(
          minimum: const EdgeInsets.fromLTRB(0, 0, 0, 16),
          child: GestureDetector(
            onTap: () => _showCartSheet(context),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              height: 56,
              decoration: BoxDecoration(
                color: accentRed,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(color: accentRed.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))
                ],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  // Overlapping Images
                  if (images.isNotEmpty)
                    SizedBox(
                      width: 40.0 + (images.length - 1) * 24.0,
                      height: 40,
                      child: Stack(
                        children: List.generate(images.length, (index) {
                          return Positioned(
                            left: index * 24.0,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: accentRed, width: 2), // matching pill bg for cutout effect
                                color: Colors.white,
                              ),
                              child: ClipOval(
                                child: Image.network(
                                  images[index]!, 
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, e, s) => const Icon(Icons.shopping_bag, size: 20, color: Colors.grey),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    )
                  else
                     const SizedBox(width: 16),
                  const SizedBox(width: 12),
                  // Text Details
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "View cart",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Text(
                          "${cart.totalItems} items",
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  // Arrow
                  const Padding(
                    padding: EdgeInsets.only(right: 16),
                    child: Icon(Icons.chevron_right, color: Colors.white, size: 24),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showCartSheet(BuildContext context) {
    final navigatorContext = shopNavigatorKey.currentContext ?? context;
    showModalBottomSheet(
      context: navigatorContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return const b2b_cart_sheet.CartBottomSheet();
      },
    );
  }
}
