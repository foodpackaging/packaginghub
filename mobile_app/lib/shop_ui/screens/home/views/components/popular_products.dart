import 'package:b2b_store/shop_ui/route/route_constants.dart';
import 'package:flutter/material.dart';
import 'package:b2b_store/shop_ui/components/product/product_card.dart';
import 'package:b2b_store/shop_ui/components/skleton/product/products_skelton.dart';
import 'package:b2b_store/shared/models/product.dart';
import 'package:b2b_store/shop_ui/constants.dart';
import 'package:b2b_store/shop_ui/services/cms_service.dart';

class PopularProducts extends StatefulWidget {
  const PopularProducts({
    super.key,
  });

  @override
  State<PopularProducts> createState() => _PopularProductsState();
}

class _PopularProductsState extends State<PopularProducts> {
  final CmsService _cmsService = CmsService();
  late Future<List<Product>> _productsFuture;

  @override
  void initState() {
    super.initState();
    _productsFuture = _cmsService.getProducts();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(defaultPadding),
          child: Text(
            "Popular products",
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        StreamBuilder<List<Product>>(
          stream: _cmsService.getProductsStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const ProductsSkelton();
            } else if (snapshot.hasError) {
              return Center(child: Text("Error loading products: ${snapshot.error}"));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Padding(
                padding: EdgeInsets.all(defaultPadding),
                child: Text("No products found"),
              ));
            }
 
            final products = snapshot.data!;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: defaultPadding),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: products.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: defaultPadding,
                  mainAxisSpacing: defaultPadding,
                  childAspectRatio: 0.62,
                ),
                itemBuilder: (context, index) => ProductCard(
                  image: products[index].image,
                  brand: products[index].brand ?? "B2B",
                  name: products[index].name,
                  price: products[index].price,
                  discountedPrice: products[index].discountedPrice,
                  discountPercent: products[index].discountPercent.toInt(),
                  product: products[index],
                  press: () {
                    Navigator.pushNamed(context, productDetailsScreenRoute,
                        arguments: products[index]);
                  },
                ),
              ),
            );
          },
        )
      ],
    );
  }
}
