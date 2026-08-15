import 'package:flutter/material.dart';
import 'package:b2b_store/shared/models/product.dart';
import 'package:b2b_store/shop_ui/services/cms_service.dart';
import 'package:b2b_store/shop_ui/components/network_image_with_loader.dart';
import 'package:b2b_store/shop_ui/route/route_constants.dart';
import 'package:provider/provider.dart';
import 'package:b2b_store/shop_ui/controllers/cart_controller.dart';
import 'package:b2b_store/shop_ui/components/cart/cart_quantity_control.dart';

class MoreFromBrand extends StatefulWidget {
  final Product currentProduct;

  const MoreFromBrand({super.key, required this.currentProduct});

  @override
  State<MoreFromBrand> createState() => _MoreFromBrandState();
}

class _MoreFromBrandState extends State<MoreFromBrand> {
  final CmsService _cmsService = CmsService();
  bool _isLoading = true;
  List<Product> _brandProducts = [];

  @override
  void initState() {
    super.initState();
    _loadBrandProducts();
  }

  Future<void> _loadBrandProducts() async {
    try {
      final brand = widget.currentProduct.brand;
      if (brand != null && brand.isNotEmpty) {
        final products = await _cmsService.getProductsFiltered(
          activeFilters: {'brand': brand},
        );
        // Remove current product and limit
        final filtered = products.where((p) => p.id != widget.currentProduct.id).take(8).toList();
        if (mounted) {
          setState(() {
            _brandProducts = filtered;
            _isLoading = false;
          });
        }
        return;
      }
    } catch (e) {
      debugPrint("Error loading brand products: $e");
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
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

    if (_brandProducts.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: Text(
              "More from ${widget.currentProduct.brand ?? ''}",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
            ),
          ),
          SizedBox(
            height: 290,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              physics: const BouncingScrollPhysics(),
              itemCount: _brandProducts.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: _buildBrandCard(context, _brandProducts[index]),
                );
              },
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildBrandCard(BuildContext context, Product product) {
    final cartController = Provider.of<CartController>(context);
    final int cartQuantity = cartController.quantityForProduct(product);

    // Hardcode veg icon based on name to match screenshot, or read from attributes
    final isVeg = product.attributes['is_veg'] ?? true;

    return Container(
      width: 160,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
      ),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(context, productDetailsScreenRoute, arguments: product);
        },
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image
                  Center(
                    child: SizedBox(
                      height: 100,
                      width: 100,
                      child: NetworkImageWithLoader(
                        product.images.isNotEmpty ? product.images.first : "https://i.imgur.com/K41Mj7C.png",
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Veg icon
                  if (isVeg == true)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF166534), width: 1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Center(
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF166534),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
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
                  const SizedBox(height: 8),
                  // Price
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        "₹${product.discountedPrice.toInt()}",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(width: 6),
                      if (product.discountPercent > 0)
                        Text(
                          "₹${product.price.toInt()}",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                            decoration: TextDecoration.lineThrough,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
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
            
            // % OFF Tag Overlay
            if (product.discountPercent > 0)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: const BoxDecoration(
                    color: Color(0xFF2563EB),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(8),
                      topRight: Radius.circular(15), // match parent
                    ),
                  ),
                  child: Text(
                    "${product.discountPercent.toInt()}% OFF",
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
