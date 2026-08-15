class Category {
  final String id;
  final String name;
  final String slug;
  final String? description;
  final String? imageUrl;
  final String? svgSrc;
  final List<Category>? subCategories;
  final int sortOrder;
  final bool isActive;
  
  Category({
    this.id = 'demo',
    this.name = 'Demo Category',
    this.slug = 'demo',
    this.description,
    this.imageUrl,
    this.svgSrc,
    this.subCategories,
    this.sortOrder = 0,
    this.isActive = true,
  });
  
  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id']?.toString() ?? "",
      name: json['name']?.toString() ?? "Unnamed Category",
      slug: json['slug']?.toString() ?? "",
      description: json['description']?.toString() ?? "",
      imageUrl: json['icon_url']?.toString(),
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class Product {
  final String id;
  final String name;
  final String slug;
  final String? description;
  final String? brand;
  final String? categoryId;
  final Category? category;
  final double price;
  final double discountPercent;
  final double discountedPrice;
  final int stockQuantity;
  final String unit;
  final int minOrderQty;
  final List<String> images;
  final bool isActive;
  final bool isFeatured;
  final Map<String, dynamic> attributes;
  final List<ProductInformationSection> productInformationSections;
  final DateTime createdAt;
  final String? sku;
  
  Product({
    this.id = 'demo',
    this.name = 'Demo Product',
    this.slug = '',
    this.description,
    this.brand,
    this.categoryId,
    this.category,
    required this.price,
    this.discountPercent = 0,
    double? discountedPrice,
    this.stockQuantity = 999,
    this.unit = 'piece',
    this.minOrderQty = 1,
    this.images = const [],
    this.isActive = true,
    this.isFeatured = false,
    this.attributes = const {},
    this.productInformationSections = const [],
    DateTime? createdAt,
    this.sku,
  })  : discountedPrice = discountedPrice ?? (price * (1 - discountPercent / 100)),
        createdAt = createdAt ?? DateTime.now();
  
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id']?.toString() ?? "",
      name: json['name']?.toString() ?? "Unnamed Product",
      slug: json['slug']?.toString() ?? "",
      description: json['description']?.toString() ?? "",
      brand: json['brand']?.toString() ?? (json['attributes'] != null ? json['attributes']['brand']?.toString() : null) ?? "",
      categoryId: json['category_id']?.toString(),
      category: json['category'] != null 
        ? Category.fromJson(json['category'] as Map<String, dynamic>)
        : null,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      discountPercent: (json['discount_percent'] as num?)?.toDouble() ?? 0.0,
      discountedPrice: (json['discounted_price'] as num?)?.toDouble() ?? 
                       ((json['price'] as num?)?.toDouble() ?? 0.0),
      stockQuantity: (json['stock_quantity'] as num?)?.toInt() ?? 0,
      unit: json['unit']?.toString() ?? 'piece',
      minOrderQty: (json['min_order_qty'] as num?)?.toInt() ?? 1,
      images: (json['images'] as List<dynamic>?)?.cast<String>() ?? [],
      isActive: json['is_active'] as bool? ?? true,
      isFeatured: json['is_featured'] as bool? ?? false,
      attributes: json['attributes'] as Map<String, dynamic>? ?? {},
      productInformationSections: _parseProductInformationSections(json),
      createdAt: json['created_at'] != null 
        ? DateTime.parse(json['created_at'] as String)
        : DateTime.now(),
      sku: json['sku']?.toString(),
    );
  }
  
  bool get isOutOfStock => stockQuantity == 0;
  bool get hasDiscount => discountPercent > 0;
  double get savings => price - discountedPrice;
  String get image => images.isNotEmpty ? images.first : "";
}

List<ProductInformationSection> _parseProductInformationSections(Map<String, dynamic> json) {
  final attributes = json['attributes'] as Map<String, dynamic>?;
  final rawSections = json['productInformationSections'] ??
      json['product_information_sections'] ??
      attributes?['productInformationSections'] ??
      attributes?['product_information_sections'];

  if (rawSections is! List) return [];

  final sections = rawSections
      .whereType<Map>()
      .map((section) => ProductInformationSection.fromJson(Map<String, dynamic>.from(section)))
      .where((section) => section.heading.trim().isNotEmpty && section.content.trim().isNotEmpty)
      .toList();

  sections.sort((a, b) => a.order.compareTo(b.order));
  return sections;
}

class ProductInformationSection {
  final String id;
  final String heading;
  final String content;
  final int order;

  const ProductInformationSection({
    required this.id,
    required this.heading,
    required this.content,
    required this.order,
  });

  factory ProductInformationSection.fromJson(Map<String, dynamic> json) {
    return ProductInformationSection(
      id: json['id']?.toString() ?? '',
      heading: json['heading']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      order: (json['order'] as num?)?.toInt() ?? 0,
    );
  }
}

extension CategoryExtension on Category {
  String get title => name;
}

class CartItem {
  final Product product;
  final int quantity;
  
  CartItem({
    required this.product,
    required this.quantity,
  });
  
  double get total => product.discountedPrice * quantity;
  
  Map<String, dynamic> toJson() {
    return {
      'product': {
        'id': product.id,
        'name': product.name,
        'price': product.price,
        'discounted_price': product.discountedPrice,
        'images': product.images,
        'unit': product.unit,
      },
      'quantity': quantity,
    };
  }
  
  factory CartItem.fromJson(Map<String, dynamic> json) {
    final productData = json['product'] as Map<String, dynamic>? ?? {};
    return CartItem(
      product: Product(
        id: productData['id']?.toString() ?? "",
        name: productData['name']?.toString() ?? "Product",
        slug: '',
        price: (productData['price'] as num?)?.toDouble() ?? 
               (productData['discounted_price'] as num?)?.toDouble() ?? 0.0,
        discountedPrice: (productData['discounted_price'] as num?)?.toDouble() ?? 0.0,
        stockQuantity: 999,
        images: (productData['images'] as List<dynamic>?)?.cast<String>() ?? [],
        unit: productData['unit']?.toString() ?? 'piece',
        createdAt: DateTime.now(),
      ),
      quantity: json['quantity'] as int? ?? 1,
    );
  }
  
  CartItem copyWith({int? quantity}) {
    return CartItem(
      product: product,
      quantity: quantity ?? this.quantity,
    );
  }
}
