import 'package:b2b_store/shared/models/product.dart';

final List<Category> demoCategoriesWithImage = [
  Category(id: "c1", name: "Woman’s", slug: "womans", imageUrl: "https://i.imgur.com/5M89G2P.png"),
  Category(id: "c2", name: "Man’s", slug: "mans", imageUrl: "https://i.imgur.com/UM3GdWg.png"),
  Category(id: "c3", name: "Kid’s", slug: "kids", imageUrl: "https://i.imgur.com/Lp0D6k5.png"),
  Category(id: "c4", name: "Accessories", slug: "accessories", imageUrl: "https://i.imgur.com/3mSE5sN.png"),
];

final List<Category> demoCategories = [
  Category(
    id: "cat1",
    name: "On sale",
    slug: "sale",
    svgSrc: "assets/icons/Sale.svg",
    subCategories: [
      Category(name: "All Friend", slug: "all"),
      Category(name: "New arrivals", slug: "new"),
    ],
  ),
  Category(
    id: "cat2",
    name: "Man’s & Woman’s",
    slug: "man-woman",
    svgSrc: "assets/icons/Product.svg",
    subCategories: [
      Category(name: "All Friend", slug: "all"),
      Category(name: "New arrivals", slug: "new"),
    ],
  ),
  Category(
    id: "cat3",
    name: "Kids",
    slug: "kids-all",
    svgSrc: "assets/icons/Child.svg",
    subCategories: [
      Category(name: "All Friend", slug: "all"),
      Category(name: "New arrivals", slug: "new"),
    ],
  ),
  Category(
    id: "cat4",
    name: "Accessories",
    slug: "accessories-all",
    svgSrc: "assets/icons/Accessories.svg",
    subCategories: [
      Category(name: "All Friend", slug: "all"),
      Category(name: "New arrivals", slug: "new"),
    ],
  ),
];
