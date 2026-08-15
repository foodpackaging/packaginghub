import 'package:b2b_store/shared/models/product.dart';
import 'package:b2b_store/shop_ui/constants.dart';
import 'package:b2b_store/shop_ui/controllers/cart_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class CartQuantityControl extends StatelessWidget {
  const CartQuantityControl({
    super.key,
    required this.product,
    this.compact = false,
  });

  final Product product;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Consumer<CartController>(
      builder: (context, cart, child) {
        final quantity = cart.quantityForProduct(product);
        if (quantity == 0) {
          return _CartActionShell(
            compact: compact,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                cart.addToCart(product);
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 10 : 16,
                  vertical: compact ? 7 : 10,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "ADD",
                      style: TextStyle(
                        color: accentRed,
                        fontWeight: FontWeight.bold,
                        fontSize: compact ? 11 : 14,
                      ),
                    ),
                    SizedBox(width: compact ? 2 : 6),
                    Icon(Icons.add, size: compact ? 12 : 16, color: accentRed),
                  ],
                ),
              ),
            ),
          );
        }

        return _CartActionShell(
          compact: compact,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _QuantityIconButton(
                icon: Icons.remove,
                compact: compact,
                onTap: () {
                  HapticFeedback.lightImpact();
                  cart.decrementProduct(product);
                },
              ),
              SizedBox(
                width: compact ? 22 : 30,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return ScaleTransition(scale: animation, child: child);
                  },
                  child: Text(
                    "$quantity",
                    key: ValueKey<int>(quantity),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: accentRed,
                      fontWeight: FontWeight.bold,
                      fontSize: compact ? 12 : 15,
                    ),
                  ),
                ),
              ),
              _QuantityIconButton(
                icon: Icons.add,
                compact: compact,
                onTap: () {
                  HapticFeedback.lightImpact();
                  cart.incrementProduct(product);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CartActionShell extends StatelessWidget {
  const _CartActionShell({
    required this.child,
    required this.compact,
  });

  final Widget child;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFF5F5),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: BoxConstraints(minHeight: compact ? 30 : 42),
        decoration: BoxDecoration(
          border: Border.all(color: accentRed),
          borderRadius: BorderRadius.circular(8),
        ),
        child: child,
      ),
    );
  }
}

class _QuantityIconButton extends StatelessWidget {
  const _QuantityIconButton({
    required this.icon,
    required this.compact,
    required this.onTap,
  });

  final IconData icon;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 28.0 : 36.0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: size,
        height: compact ? 30 : 40,
        child: Icon(icon, size: compact ? 14 : 18, color: accentRed),
      ),
    );
  }
}
