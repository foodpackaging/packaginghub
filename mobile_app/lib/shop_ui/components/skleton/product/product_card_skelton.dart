import 'package:flutter/material.dart';

import 'package:b2b_store/shop_ui/constants.dart';
import '../skelton.dart';

class ProductCardSkelton extends StatelessWidget {
  const ProductCardSkelton({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 260,
      width: 140,
      child: Padding(
        padding: EdgeInsets.all(defaultPadding / 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.15,
              child: Skeleton(),
            ),
            Spacer(flex: 2),
            Skeleton(height: 12, width: 64),
            Spacer(flex: 2),
            Skeleton(),
            Spacer(),
            Skeleton(),
            Spacer(flex: 2),
            Skeleton(height: 12, width: 80),
            Spacer(),
          ],
        ),
      ),
    );
  }
}












