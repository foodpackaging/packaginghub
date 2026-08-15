import 'package:b2b_store/shop_ui/route/route_constants.dart';
import 'package:b2b_store/shop_ui/constants.dart';
import 'package:flutter/material.dart';
import 'package:b2b_store/shop_ui/controllers/cart_controller.dart';
import 'package:provider/provider.dart';
import 'package:b2b_store/shop_ui/components/notification_bell.dart';
import 'package:b2b_store/shop_ui/screens/search/views/components/search_form.dart';

import 'components/categories.dart';
import 'components/popular_products.dart';
import 'components/home_banners.dart';
import 'components/brands.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: defaultPadding, vertical: defaultPadding / 2),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          "Packaging Hub",
                          style: Theme.of(context).textTheme.titleLarge!.copyWith(
                                fontWeight: FontWeight.bold,
                                color: navyDark,
                              ),
                        ),
                        const Spacer(),
                        const NotificationBell(),
                        const SizedBox(width: 8),
                        Consumer<CartController>(
                          builder: (context, cart, child) => Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: blackColor10),
                            ),
                            child: Badge(
                              label: Text("${cart.totalItems}"),
                              isLabelVisible: cart.items.isNotEmpty,
                              child: IconButton(
                                onPressed: () => Navigator.pushNamed(context, cartScreenRoute),
                                icon: const Icon(Icons.shopping_cart_outlined, color: navyDark),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: defaultPadding),
                    SearchForm(
                      readOnly: true,
                      onTap: () {
                        Navigator.pushNamed(context, searchScreenRoute);
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: defaultPadding / 2),
                child: HomeBanners(),
              ),
            ),

            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: defaultPadding / 2, bottom: defaultPadding / 2),
                child: HomeBanners(
                  placement: 'category',
                  height: 128,
                  borderRadius: 14,
                  showIndicators: false,
                ),
              ),
            ),
            
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: defaultPadding, vertical: defaultPadding / 2),
                child: Text(
                  "Shop by category",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: navyDark,
                  ),
                ),
              ),
            ),

            const DynamicCategoriesSliver(),

            const SliverToBoxAdapter(child: SizedBox(height: defaultPadding)),

            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: defaultPadding, vertical: defaultPadding / 2),
                child: Text(
                  "Shop by brand",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: navyDark,
                  ),
                ),
              ),
            ),
            
            const DynamicBrandsSliver(),
            
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: defaultPadding),
                child: PopularProducts(),
              ),
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: defaultPadding * 2),
            ),
          ],
        ),
      ),
    );
  }
}
