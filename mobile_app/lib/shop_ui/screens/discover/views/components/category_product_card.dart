import 'package:b2b_store/shop_ui/constants.dart';
import 'package:b2b_store/shop_ui/components/cart/cart_quantity_control.dart';
import 'package:flutter/material.dart';
import 'package:b2b_store/shared/models/product.dart';

class CategoryProductCard extends StatelessWidget {
  const CategoryProductCard({
    super.key,
    required this.product,
    required this.press,
  });

  final Product product;
  final VoidCallback press;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: press,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: blackColor10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top row: price drop alert + % off badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (product.hasDiscount)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F0FE),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_circle_down, size: 12, color: alertBlue),
                        SizedBox(width: 3),
                        Text(
                          "Price drop alert",
                          style: TextStyle(color: alertBlue, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  )
                else
                  const SizedBox.shrink(),
                if (product.hasDiscount)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: alertBlue,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      "${product.discountPercent.toInt()}% OFF",
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  )
                else
                  const SizedBox.shrink(),
              ],
            ),
            const SizedBox(height: 8),
            // Main content row: info + image
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "${product.brand ?? "Glen"} - ${product.name}",
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: navyDark,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${product.minOrderQty} ${product.unit}",
                        style: const TextStyle(color: mutedText, fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      // Star rating
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A7A3B),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star, size: 10, color: Colors.white),
                                SizedBox(width: 2),
                                Text("4.7",
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Text("(218)",
                              style: TextStyle(color: mutedText, fontSize: 10)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Price row
                      Row(
                        children: [
                          Text(
                            "₹${product.discountedPrice.toInt()}",
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: navyDark),
                          ),
                          if (product.hasDiscount) ...[
                            const SizedBox(width: 5),
                            Text(
                              "₹${product.price.toStringAsFixed(1)}",
                              style: const TextStyle(
                                fontSize: 12,
                                color: mutedText,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                          const Spacer(),
                          CartQuantityControl(product: product, compact: true),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "at ₹${(product.discountedPrice / (product.minOrderQty > 0 ? product.minOrderQty : 1)).toStringAsFixed(2)}/${product.unit}",
                        style: const TextStyle(color: mutedText, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Product image (no Stack — use a simple Container)
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: product.images.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            product.images[0],
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.image_not_supported,
                                    color: mutedText),
                          ),
                        )
                      : const Icon(Icons.image_not_supported, color: mutedText),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
