import 'package:b2b_store/core/services/api_client.dart' show ApiClient, ApiException;
import 'package:b2b_store/shared/models/product.dart';
import 'package:b2b_store/shared/models/filter_model.dart';
import 'package:b2b_store/shared/models/catalog_page.dart';
import 'package:flutter/foundation.dart';

class CmsService {
  final ApiClient _client = ApiClient.instance;

  // Fetch banners, optionally for a specific home page placement.
  Future<List<Map<String, dynamic>>> getBanners({String? placement}) async {
    try {
      final response = await _client.get('/banners', query: {
        if (placement != null) 'placement': placement,
      });
      return List<Map<String, dynamic>>.from(response['banners'] as List? ?? []);
    } catch (e) {
      debugPrint('Error fetching banners: $e');
      return [];
    }
  }

  // Fetch only top-level categories (Main Categories)
  Future<List<Map<String, dynamic>>> getCategories() async {
    final response = await _client.get('/categories', query: {'parent_id': 'null'});
    return List<Map<String, dynamic>>.from(response['categories'] as List? ?? []);
  }

  // Fetch sub-categories for a parent
  Future<List<Map<String, dynamic>>> getSubCategories(String parentId) async {
    final response = await _client.get('/categories', query: {'parent_id': parentId});
    return List<Map<String, dynamic>>.from(response['categories'] as List? ?? []);
  }

  // Fetch flash sale products (discount > 15%)
  Future<List<Product>> getFlashSaleProducts() async {
    final response = await _client.get('/products', query: {'flash_sale': true});
    return ((response['products'] as List?) ?? []).map((json) => Product.fromJson(json)).toList();
  }

  Future<List<Product>> getProducts() async {
    final response = await _client.get('/products');
    return ((response['products'] as List?) ?? []).map((json) => Product.fromJson(json)).toList();
  }

  /// Polls for the product list every 5 seconds (replaces the old Supabase Realtime subscription).
  Stream<List<Product>> getProductsStream() async* {
    while (true) {
      yield await getProducts();
      await Future.delayed(const Duration(seconds: 5));
    }
  }

  // Fetch products by category (includes sub-category products)
  Future<List<Product>> getProductsByCategory(String categoryId) async {
    final response = await _client.get('/products', query: {'category_id': categoryId});
    return ((response['products'] as List?) ?? []).map((json) => Product.fromJson(json)).toList();
  }

  // Fetch category by ID
  Future<Map<String, dynamic>?> getCategoryById(String id) async {
    try {
      final response = await _client.get('/categories/$id');
      return response['category'] as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  // Fetch dynamic filters for a category or subcategory.
  Future<List<ProductFilter>> getFilters({
    String? categoryId,
    String? subcategoryId,
  }) async {
    try {
      // Resolve parent category ID when only subcategoryId is provided
      String? resolvedParentId = categoryId;
      if (subcategoryId != null && categoryId == null) {
        final sub = await getCategoryById(subcategoryId);
        resolvedParentId = sub?['parent_id']?.toString();
      }
      if (resolvedParentId == null) return [];

      final response = await _client.get('/filters', query: {
        'category_id': resolvedParentId,
        if (subcategoryId != null) 'subcategory_id': subcategoryId,
      });

      return List<Map<String, dynamic>>.from(response['filters'] as List? ?? [])
          .map((json) => ProductFilter.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error fetching filters: $e');
      return [];
    }
  }

  // Fetch products with dynamic attribute filtering.
  Future<List<Product>> getProductsFiltered({
    String? categoryId,
    String? subcategoryId,
    Map<String, dynamic> activeFilters = const {},
  }) async {
    final page = await getCatalogPage(
      categoryId: categoryId,
      subcategoryId: subcategoryId,
      activeFilters: activeFilters,
      includeFacets: false,
      limit: 100,
    );
    return page.products;
  }

  /// Paged catalog fetch that also returns the true total and facet counts.
  ///
  /// One request per interaction: the grid, the result count and the filter
  /// sheet's option counts all come from this single response.
  Future<CatalogPage> getCatalogPage({
    String? categoryId,
    String? subcategoryId,
    Map<String, dynamic> activeFilters = const {},
    String? search,
    String sort = 'newest',
    int page = 1,
    int limit = 24,
    bool includeFacets = true,
  }) async {
    try {
      final response = await _client.post('/products/filtered', body: {
        if (categoryId != null) 'category_id': categoryId,
        if (subcategoryId != null) 'subcategory_id': subcategoryId,
        'filters': activeFilters,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        'sort': sort,
        'page': page,
        'limit': limit,
        'include_facets': includeFacets,
      });
      return CatalogPage.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Error fetching catalog page: $e');
      rethrow;
    }
  }

  /// Validates a coupon code, returning {'coupon': {...}, 'discount_amount': num}.
  /// Throws [ApiException] with a user-facing message (e.g. "invalid code",
  /// "minimum order amount is X") if the coupon can't be applied.
  Future<Map<String, dynamic>> validateCoupon(String code, {double orderAmount = 0}) async {
    final response = await _client.post('/coupons/validate', body: {
      'code': code,
      'order_amount': orderAmount,
    });
    return response as Map<String, dynamic>;
  }

  // Fetch distinct brand names from available products
  Future<List<String>> getBrands() async {
    try {
      final response = await _client.get('/products/brands');
      return List<String>.from(response['brands'] as List? ?? []);
    } catch (e) {
      return [];
    }
  }
}
