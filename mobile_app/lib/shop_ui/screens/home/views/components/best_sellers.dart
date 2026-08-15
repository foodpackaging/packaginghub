import 'package:b2b_store/shop_ui/route/route_constants.dart';
import 'package:flutter/material.dart';
import 'package:b2b_store/shop_ui/components/product/product_card.dart';
import 'package:b2b_store/shop_ui/components/skleton/product/products_skelton.dart';
import 'package:b2b_store/shared/models/product.dart';
import 'package:b2b_store/shop_ui/services/cms_service.dart';
import 'package:b2b_store/shop_ui/constants.dart';

class BestSellers extends StatefulWidget {
  const BestSellers({
    super.key,
  });

  @override
  State<BestSellers> createState() => _BestSellersState();
}

class _BestSellersState extends State<BestSellers> {
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
        const SizedBox(height: defaultPadding / 2),
        Padding(
          padding: const EdgeInsets.all(defaultPadding),
          child: Text(
            "Best sellers",
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        FutureBuilder<List<Product>>(
          future: _productsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const ProductsSkelton();
            } else if (snapshot.hasError) {
              return Center(child: Text("Error: ${snapshot.error}"));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const SizedBox.shrink();
            }

            final products = snapshot.data!;
            return SizedBox(
              height: 260,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: products.length,
                itemBuilder: (context, index) => Padding(
                  padding: EdgeInsets.only(
                    left: defaultPadding,
                    right: index == products.length - 1 ? defaultPadding : 0,
                  ),
                  child: SizedBox(width: 140, child: ProductCard(
                    image: products[index].image,
                    brand: products[index].brand ?? "UNKNOWN",
                    name: products[index].name,
                    price: products[index].price,
                    discountedPrice: products[index].discountedPrice,
                    discountPercent: products[index].discountPercent.toInt(),
                    product: products[index],
                    press: () {
                      Navigator.pushNamed(context, productDetailsScreenRoute,
                          arguments: products[index]);
                    },
                  )),
                ),
              ),
            );
          },
        )
      ],
    );
  }
}
