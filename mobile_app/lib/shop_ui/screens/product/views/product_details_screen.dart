import 'package:b2b_store/shop_ui/constants.dart';
import 'package:b2b_store/shop_ui/route/route_constants.dart';
import 'package:flutter/material.dart';
import 'package:b2b_store/shared/models/product.dart';
import 'package:provider/provider.dart';
import 'package:b2b_store/shop_ui/controllers/cart_controller.dart';

import 'components/product_images.dart';
import 'components/product_info.dart';
import 'components/product_details_card.dart';
import 'components/compare_similar_items.dart';
import 'components/more_from_brand.dart';

class ProductDetailsScreen extends StatelessWidget {
  const ProductDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final product = ModalRoute.of(context)!.settings.arguments as Product;
    final cartController = Provider.of<CartController>(context, listen: false);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildFloatingIconButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onPressed: () => Navigator.pop(context),
                      iconSize: 18,
                    ),
                    Row(
                      children: [
                        _buildFloatingIconButton(
                          icon: Icons.share_outlined,
                          onPressed: () {},
                        ),
                        const SizedBox(width: 8),
                        _buildFloatingIconButton(
                          icon: Icons.search,
                          onPressed: () {},
                        ),
                        const SizedBox(width: 8),
                        _buildFloatingIconButton(
                          icon: Icons.shopping_cart_outlined,
                          onPressed: () => Navigator.pushNamed(context, cartScreenRoute),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            ProductImages(
              images: product.images.isNotEmpty ? product.images : ["https://i.imgur.com/K41Mj7C.png"],
            ),
            ProductInfo(
              brand: product.brand ?? "Glen",
              name: product.name,
              isAvailable: product.isActive,
              stockQuantity: product.stockQuantity,
              price: product.price,
              discountPercent: product.discountPercent,
              discountedPrice: product.discountedPrice,
              informationSections: product.productInformationSections,
              product: product,
              description: product.description ??
                  "No description available for this product.",
              onAddToCart: () {
                cartController.addToCart(product);
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text("Added to cart"),
                    backgroundColor: primaryColor,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(milliseconds: 1500),
                    action: SnackBarAction(
                      label: "VIEW",
                      textColor: Colors.white,
                      onPressed: () {
                        Navigator.pushNamed(context, cartScreenRoute);
                      },
                    ),
                  ),
                );
              },
              onBuyNow: () {
                cartController.addToCart(product);
                Navigator.pushNamed(context, cartScreenRoute);
              },
            ),
            ProductDetailsCard(product: product),
            
            CompareSimilarItems(currentProduct: product),
            MoreFromBrand(currentProduct: product),

            const SliverToBoxAdapter(
              child: SizedBox(height: defaultPadding * 2),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    double iconSize = 22,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: navyDark, size: iconSize),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        splashRadius: 20,
      ),
    );
  }
}
