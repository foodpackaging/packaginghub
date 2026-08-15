import 'package:flutter/material.dart';
import 'package:b2b_store/shared/models/product.dart';
import 'package:b2b_store/shop_ui/services/cms_service.dart';
import 'package:b2b_store/shop_ui/components/network_image_with_loader.dart';
import 'package:b2b_store/shop_ui/route/route_constants.dart';
import 'package:provider/provider.dart';
import 'package:b2b_store/shop_ui/controllers/cart_controller.dart';
import 'package:b2b_store/shop_ui/components/cart/cart_quantity_control.dart';
import 'package:b2b_store/shop_ui/constants.dart';

class CompareSimilarItems extends StatefulWidget {
  final Product currentProduct;

  const CompareSimilarItems({super.key, required this.currentProduct});

  @override
  State<CompareSimilarItems> createState() => _CompareSimilarItemsState();
}

class _CompareSimilarItemsState extends State<CompareSimilarItems> {
  final CmsService _cmsService = CmsService();
  bool _isLoading = true;
  List<Product> _similarProducts = [];

  @override
  void initState() {
    super.initState();
    _loadSimilarProducts();
  }

  Future<void> _loadSimilarProducts() async {
    try {
      final catId = widget.currentProduct.categoryId;
      if (catId != null) {
        final products = await _cmsService.getProductsByCategory(catId);
        final filtered = products
            .where((p) => p.id != widget.currentProduct.id)
            .take(5)
            .toList();
        if (mounted) {
          setState(() {
            _similarProducts = filtered;
            _isLoading = false;
          });
        }
        return;
      }
    } catch (e) {
      debugPrint('Error loading similar products: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

    if (_similarProducts.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: Text(
              "Compare similar items",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sticky Left Column
                  Container(
                    width: 80,
                    decoration: const BoxDecoration(
                      border: Border(right: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 270), // Empty space matching product card height
                        const Divider(color: Color(0xFFF1F5F9), thickness: 1, height: 1),
                        Container(
                          height: 50,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          alignment: Alignment.centerLeft,
                          child: const Text("Rating", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
                        ),
                        const Divider(color: Color(0xFFF1F5F9), thickness: 1, height: 1),
                        Container(
                          height: 50,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          alignment: Alignment.centerLeft,
                          child: const Text("Price", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
                        ),
                      ],
                    ),
                  ),
                  
                  // Scrollable Products Area
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: _similarProducts.map((p) => _buildProductColumn(context, p)).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildProductColumn(BuildContext context, Product product) {
    final cartController = Provider.of<CartController>(context);
    final int cartQuantity = cartController.quantityForProduct(product);

    // We hardcode a rating to match the UI screenshot format, or try to read from attributes if available
    final rating = product.attributes['rating'] ?? (4.0 + (product.name.length % 10) / 10).toStringAsFixed(1);

    return Container(
      width: 150,
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
      ),
      child: Column(
        children: [
          // Top Block (Product Info)
          SizedBox(
            height: 270,
            child: InkWell(
              onTap: () {
                Navigator.pushNamed(context, productDetailsScreenRoute, arguments: product);
              },
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image
                    AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: NetworkImageWithLoader(
                          product.images.isNotEmpty ? product.images.first : "https://i.imgur.com/K41Mj7C.png",
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Title
                    Expanded(
                      child: Text(
                        "${product.brand ?? ''} - ${product.name}",
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1E293B), height: 1.3),
                      ),
                    ),
                    // Unit
                    Text(
                      product.unit,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 12),
                    // Add Button
                    cartQuantity > 0
                        ? SizedBox(
                            width: double.infinity,
                            height: 36,
                            child: CartQuantityControl(product: product),
                          )
                        : InkWell(
                            onTap: () {
                              cartController.addToCart(product);
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: double.infinity,
                              height: 36,
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFFF43F5E), width: 1),
                                borderRadius: BorderRadius.circular(8),
                                color: const Color(0xFFFFF1F2).withOpacity(0.5),
                              ),
                              child: const Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text("ADD", style: TextStyle(color: Color(0xFFE11D48), fontWeight: FontWeight.w800, fontSize: 13)),
                                    SizedBox(width: 4),
                                    Text("+", style: TextStyle(color: Color(0xFFE11D48), fontWeight: FontWeight.w400, fontSize: 14)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(color: Color(0xFFF1F5F9), thickness: 1, height: 1),
          // Rating Row
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                const Icon(Icons.stars_rounded, color: Color(0xFF166534), size: 16),
                const SizedBox(width: 4),
                Text(rating.toString(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
              ],
            ),
          ),
          const Divider(color: Color(0xFFF1F5F9), thickness: 1, height: 1),
          // Price Row
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.centerLeft,
            child: Text(
              "₹${product.discountedPrice.toInt()}",
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
            ),
          ),
        ],
      ),
    );
  }
}
