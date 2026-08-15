import 'package:b2b_store/shared/models/product.dart';

/// A single value of a facet, with how many products carry it.
class FacetValue {
  const FacetValue({required this.value, required this.count});

  final dynamic value;
  final int count;

  String get label => value.toString();

  factory FacetValue.fromJson(Map<String, dynamic> json) => FacetValue(
        value: json['value'],
        count: (json['count'] as num?)?.toInt() ?? 0,
      );
}

/// Server-computed counts backing the filter sheet.
///
/// Each facet is counted with its own selection excluded, so picking one brand
/// doesn't zero out every other brand — the user can always switch.
class CatalogFacets {
  const CatalogFacets({
    this.brands = const [],
    this.priceMin,
    this.priceMax,
    this.inStockCount = 0,
    this.attributes = const {},
  });

  final List<FacetValue> brands;
  final num? priceMin;
  final num? priceMax;
  final int inStockCount;
  final Map<String, List<FacetValue>> attributes;

  /// Counts for a filter key, whichever facet bucket it lives in.
  List<FacetValue> valuesFor(String key) {
    if (key == 'brand') return brands;
    return attributes[key] ?? const [];
  }

  int? countFor(String key, dynamic value) {
    for (final v in valuesFor(key)) {
      if (v.value.toString() == value.toString()) return v.count;
    }
    return null;
  }

  factory CatalogFacets.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CatalogFacets();
    final price = json['price'] as Map<String, dynamic>? ?? const {};
    final rawAttributes = json['attributes'] as Map<String, dynamic>? ?? const {};

    return CatalogFacets(
      brands: ((json['brands'] as List?) ?? [])
          .map((e) => FacetValue.fromJson(e as Map<String, dynamic>))
          .toList(),
      priceMin: price['min'] as num?,
      priceMax: price['max'] as num?,
      inStockCount: (json['in_stock_count'] as num?)?.toInt() ?? 0,
      attributes: rawAttributes.map(
        (key, value) => MapEntry(
          key,
          ((value as List?) ?? [])
              .map((e) => FacetValue.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      ),
    );
  }
}

/// One page of catalog results plus the metadata the browse screen needs.
class CatalogPage {
  const CatalogPage({
    required this.products,
    required this.total,
    required this.page,
    required this.limit,
    required this.hasMore,
    required this.sort,
    this.facets = const CatalogFacets(),
  });

  final List<Product> products;
  final int total;
  final int page;
  final int limit;
  final bool hasMore;
  final String sort;
  final CatalogFacets facets;

  factory CatalogPage.fromJson(Map<String, dynamic> json) => CatalogPage(
        products: ((json['products'] as List?) ?? [])
            .map((e) => Product.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: (json['total'] as num?)?.toInt() ?? 0,
        page: (json['page'] as num?)?.toInt() ?? 1,
        limit: (json['limit'] as num?)?.toInt() ?? 24,
        hasMore: json['has_more'] == true,
        sort: json['sort']?.toString() ?? 'newest',
        facets: CatalogFacets.fromJson(json['facets'] as Map<String, dynamic>?),
      );
}

/// Sort options the API accepts, with the labels shown in the sort sheet.
class CatalogSort {
  const CatalogSort(this.key, this.label);
  final String key;
  final String label;

  static const options = <CatalogSort>[
    CatalogSort('newest', 'Newest first'),
    CatalogSort('price_asc', 'Price: low to high'),
    CatalogSort('price_desc', 'Price: high to low'),
    CatalogSort('discount', 'Discount: high to low'),
    CatalogSort('name_asc', 'Name: A to Z'),
  ];

  static String labelFor(String key) =>
      options.firstWhere((o) => o.key == key, orElse: () => options.first).label;
}
