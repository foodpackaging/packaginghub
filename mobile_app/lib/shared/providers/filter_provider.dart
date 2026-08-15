import 'package:flutter/material.dart';
import 'package:b2b_store/shared/models/filter_model.dart';
import 'package:b2b_store/shop_ui/services/cms_service.dart';

class FilterProvider extends ChangeNotifier {
  final CmsService _cmsService = CmsService();

  List<ProductFilter> _availableFilters = [];
  Map<String, dynamic> _activeFilters = {};
  bool _isLoading = false;

  // Guard: track last loaded context to avoid redundant re-fetches
  String? _lastCategoryId;
  String? _lastSubcategoryId;

  List<ProductFilter> get availableFilters => _availableFilters;
  Map<String, dynamic> get activeFilters => _activeFilters;
  bool get isLoading => _isLoading;

  /// Loads filters for the given category/subcategory context.
  /// Skips the network call if the context hasn't changed (prevents UX flicker
  /// when navigating back to a product list that was already loaded).
  Future<void> loadFilters(String? categoryId, String? subcategoryId) async {
    // Skip reload if the context is identical to the last successful load
    if (_lastCategoryId == categoryId &&
        _lastSubcategoryId == subcategoryId &&
        _availableFilters.isNotEmpty) {
      return;
    }

    _lastCategoryId = categoryId;
    _lastSubcategoryId = subcategoryId;

    _isLoading = true;
    notifyListeners();

    try {
      _availableFilters = await _cmsService.getFilters(
        categoryId: categoryId,
        subcategoryId: subcategoryId,
      );
    } catch (e) {
      debugPrint('Error loading filters: $e');
      _availableFilters = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Clears cached context so the next [loadFilters] call always fetches fresh.
  void resetContext() {
    _lastCategoryId = null;
    _lastSubcategoryId = null;
  }

  void setFilterValue(String key, dynamic value) {
    if (value == null || (value is List && value.isEmpty) || value == '') {
      _activeFilters.remove(key);
    } else {
      _activeFilters[key] = value;
    }
    notifyListeners();
  }

  void clearFilters() {
    _activeFilters.clear();
    notifyListeners();
  }

  int get activeFilterCount {
    int count = 0;
    _activeFilters.forEach((key, value) {
      if (value is Map && value.containsKey('min') && value.containsKey('max')) {
        if (value['min'] != null || value['max'] != null) count++;
      } else {
        count++;
      }
    });
    return count;
  }
}
