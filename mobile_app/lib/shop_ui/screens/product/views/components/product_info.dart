import 'package:flutter/material.dart';
import 'package:b2b_store/shared/models/product.dart';
import 'package:b2b_store/shop_ui/components/cart/cart_quantity_control.dart';
import 'package:b2b_store/shop_ui/constants.dart';

class ProductInfo extends StatelessWidget {
  const ProductInfo({
    super.key,
    required this.name,
    required this.brand,
    required this.description,
    required this.stockQuantity,
    required this.isAvailable,
    required this.price,
    required this.discountPercent,
    required this.discountedPrice,
    required this.informationSections,
    this.product,
    required this.onAddToCart,
    required this.onBuyNow,
  });

  final String name, brand, description;
  final int stockQuantity;
  final bool isAvailable;
  final double price, discountPercent, discountedPrice;
  final List<ProductInformationSection> informationSections;
  final Product? product;
  final VoidCallback onAddToCart;
  final VoidCallback onBuyNow;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Price Drop Alert
              Row(
                children: [
                  const Icon(Icons.local_offer, size: 14, color: Color(0xFF1E50FF)),
                  const SizedBox(width: 6),
                  const Text(
                    "Price drop alert",
                    style: TextStyle(color: Color(0xFF1E50FF), fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Title and Rating Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      "$brand - $name",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Rating Badge
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF166534), // Dark green
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.star, size: 12, color: Colors.white),
                            const SizedBox(width: 2),
                            const Text("4.7", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text("218 ratings", style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              
              // Unit Text
              Text(
                product?.unit ?? "50 pc",
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
              ),
              const SizedBox(height: 16),
              
              // Subtle Divider
              const Divider(color: Color(0xFFF1F5F9), thickness: 1.5, height: 1),
              const SizedBox(height: 16),
              
              // Price and ADD Button Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "₹${discountedPrice.toInt()}",
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                          ),
                          const SizedBox(width: 8),
                          if (discountPercent > 0)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2.0),
                              child: Text(
                                "₹${price.toInt()}",
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF94A3B8),
                                  decoration: TextDecoration.lineThrough,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (discountPercent > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF), // Light blue bg
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "${discountPercent.toInt()}% OFF",
                            style: const TextStyle(color: Color(0xFF2563EB), fontSize: 11, fontWeight: FontWeight.w800),
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  // Add Button
                  product != null // Removed cartQuantity check to match original logic
                      ? SizedBox(
                          width: 110,
                          height: 40,
                          child: CartQuantityControl(product: product!),
                        )
                      : InkWell(
                          onTap: onAddToCart,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 110,
                            height: 40,
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFF43F5E), width: 1),
                              borderRadius: BorderRadius.circular(8),
                              color: const Color(0xFFFFF1F2).withOpacity(0.5),
                            ),
                            child: const Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text("ADD", style: TextStyle(color: Color(0xFFE11D48), fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.5)),
                                  SizedBox(width: 4),
                                  Text("+", style: TextStyle(color: Color(0xFFE11D48), fontWeight: FontWeight.w400, fontSize: 16)),
                                ],
                              ),
                            ),
                          ),
                        ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
