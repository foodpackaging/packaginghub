import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:b2b_store/shared/models/product.dart';
import 'package:b2b_store/shared/models/catalog_page.dart';
import 'package:b2b_store/shop_ui/services/cms_service.dart';
import 'package:b2b_store/shared/providers/filter_provider.dart';
import 'package:b2b_store/shop_ui/components/product/product_card.dart';
import 'package:b2b_store/shop_ui/components/catalog_filter_sheet.dart';
import 'package:b2b_store/shop_ui/route/route_constants.dart';

/// Catalog browse: sub-category rail pinned left, paged product grid on the right,
/// with a sticky sort/filter bar. Switching sub-category never leaves the screen.
class ProductListScreen extends StatefulWidget {
  final String? categoryId;
  final String? subcategoryId;
  final String title;
  final String? brandFilter; // pre-select a brand (used by "Shop by brand")

  const ProductListScreen({
    super.key,
    this.categoryId,
    this.subcategoryId,
    required this.title,
    this.brandFilter,
  });

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  static const _pageSize = 24;
  static const _railWidth = 92.0;

  final CmsService _cms = CmsService();
  final ScrollController _scroll = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  List<Map<String, dynamic>> _subCategories = [];
  String? _parentCategoryId;
  String? _activeSubcategoryId;

  List<Product> _products = [];
  CatalogFacets _facets = const CatalogFacets();
  int _total = 0;
  int _page = 1;
  bool _hasMore = false;

  bool _loading = true;
  bool _loadingMore = false;
  bool _showSearch = false;
  String _sort = 'newest';
  String _search = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _parentCategoryId = widget.categoryId;
    _activeSubcategoryId = widget.subcategoryId;
    _scroll.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final filters = context.read<FilterProvider>();
      filters.clearFilters();
      if (widget.brandFilter != null && widget.brandFilter!.isNotEmpty) {
        filters.setFilterValue('brand', [widget.brandFilter!]);
      }
      await _resolveCategoryContext();
      await filters.loadFilters(_parentCategoryId, _activeSubcategoryId);
      await _load(reset: true);
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scroll.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Builds the rail. When we arrived on a sub-category directly, walk up to the
  /// parent so the rail can still show its siblings.
  Future<void> _resolveCategoryContext() async {
    try {
      if (_parentCategoryId == null && _activeSubcategoryId != null) {
        final sub = await _cms.getCategoryById(_activeSubcategoryId!);
        _parentCategoryId = sub?['parent_id']?.toString();
      }
      if (_parentCategoryId != null) {
        final subs = await _cms.getSubCategories(_parentCategoryId!);
        if (mounted) setState(() => _subCategories = subs);
      }
    } catch (_) {
      // The rail is an enhancement — a failure here shouldn't block the grid.
    }
  }

  void _onScroll() {
    if (!_scroll.hasClients || _loadingMore || !_hasMore) return;
    // Prefetch before the user actually hits the bottom.
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
      _load();
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _page = 1;
      });
    } else {
      if (_loadingMore || !_hasMore) return;
      setState(() => _loadingMore = true);
    }

    final requestedPage = reset ? 1 : _page + 1;
    final filters = context.read<FilterProvider>();

    try {
      final result = await _cms.getCatalogPage(
        categoryId: _activeSubcategoryId == null ? _parentCategoryId : null,
        subcategoryId: _activeSubcategoryId,
        activeFilters: filters.activeFilters,
        search: _search,
        sort: _sort,
        page: requestedPage,
        limit: _pageSize,
        // Facets only change when the query changes, not when paging deeper.
        includeFacets: reset,
      );
      if (!mounted) return;

      setState(() {
        _products = reset ? result.products : [..._products, ...result.products];
        if (reset) _facets = result.facets;
        _total = result.total;
        _page = result.page;
        _hasMore = result.hasMore;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        if (reset) _error = 'Could not load products. Pull down to retry.';
      });
    }
  }

  void _selectSubcategory(String? id) {
    if (_activeSubcategoryId == id) return;
    setState(() => _activeSubcategoryId = id);
    _scroll.jumpTo(0);
    context.read<FilterProvider>().loadFilters(_parentCategoryId, id).then((_) => _load(reset: true));
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    // Wait for a pause in typing rather than firing a request per keystroke.
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted || _search == value.trim()) return;
      _search = value.trim();
      _load(reset: true);
    });
  }

  Future<void> _openSortSheet() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('Sort by', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const Divider(height: 1),
            // A plain ListTile with a trailing check avoids Radio's deprecated
            // groupValue/onChanged pair, and reads the same in a picker sheet.
            ...CatalogSort.options.map(
              (option) => ListTile(
                title: Text(
                  option.label,
                  style: TextStyle(
                    fontWeight: option.key == _sort ? FontWeight.bold : FontWeight.normal,
                    color: option.key == _sort ? Theme.of(context).primaryColor : null,
                  ),
                ),
                trailing: option.key == _sort
                    ? Icon(Icons.check, color: Theme.of(context).primaryColor)
                    : null,
                onTap: () => Navigator.pop(sheetContext, option.key),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (picked != null && picked != _sort) {
      setState(() => _sort = picked);
      _scroll.jumpTo(0);
      _load(reset: true);
    }
  }

  Future<void> _openFilterSheet() async {
    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CatalogFilterSheet(facets: _facets, resultTotal: _total),
    );
    if (applied == true) {
      _scroll.jumpTo(0);
      _load(reset: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filters = context.watch<FilterProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: _showSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search in this category',
                  border: InputBorder.none,
                ),
                onChanged: _onSearchChanged,
              )
            : Text(widget.title),
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search),
            tooltip: _showSearch ? 'Close search' : 'Search',
            onPressed: () {
              setState(() => _showSearch = !_showSearch);
              if (!_showSearch && _search.isNotEmpty) {
                _searchController.clear();
                _search = '';
                _load(reset: true);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildControlBar(filters),
          if (filters.activeFilterCount > 0) _buildActiveChips(filters),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_subCategories.isNotEmpty) _buildCategoryRail(),
                Expanded(child: _buildResults()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlBar(FilterProvider filters) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _loading ? 'Loading...' : '$_total ${_total == 1 ? 'product' : 'products'}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton.icon(
            onPressed: _openSortSheet,
            icon: const Icon(Icons.swap_vert, size: 18, color: Colors.black87),
            label: Text(
              CatalogSort.labelFor(_sort),
              style: const TextStyle(color: Colors.black87, fontSize: 13),
            ),
          ),
          const SizedBox(height: 20, child: VerticalDivider(width: 1)),
          TextButton.icon(
            onPressed: _openFilterSheet,
            icon: Badge(
              isLabelVisible: filters.activeFilterCount > 0,
              label: Text('${filters.activeFilterCount}'),
              child: const Icon(Icons.tune, size: 18, color: Colors.black87),
            ),
            label: const Text('Filter', style: TextStyle(color: Colors.black87, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveChips(FilterProvider filters) {
    final entries = filters.activeFilters.entries.toList();
    return Container(
      height: 48,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: entries.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final entry = entries[index];
          final meta = filters.availableFilters.where((f) => f.key == entry.key).toList();
          final label = meta.isNotEmpty ? meta.first.label : entry.key;

          String display = entry.value.toString();
          if (entry.value is List) display = (entry.value as List).join(', ');
          if (entry.value is Map) {
            final map = entry.value as Map;
            display = '₹${map['min'] ?? 0} - ₹${map['max'] ?? '+'}';
          }
          if (entry.value == true) display = 'Yes';

          return Center(
            child: Chip(
              label: Text('$label: $display', style: const TextStyle(fontSize: 12)),
              deleteIcon: const Icon(Icons.close, size: 14),
              onDeleted: () {
                filters.setFilterValue(entry.key, null);
                _load(reset: true);
              },
              backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.08),
              side: BorderSide.none,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoryRail() {
    // A leading "All" entry (null id) clears the sub-category narrowing.
    final items = <({String? id, String name})>[
      (id: null, name: 'All'),
      ..._subCategories.map(
        (c) => (id: c['id']?.toString(), name: c['name']?.toString() ?? ''),
      ),
    ];

    return Container(
      width: _railWidth,
      color: const Color(0xFFF0F0F0),
      child: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final id = item.id;
          final selected = id == _activeSubcategoryId;

          return InkWell(
            onTap: () => _selectSubcategory(id),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
              decoration: BoxDecoration(
                color: selected ? Colors.white : Colors.transparent,
                border: Border(
                  left: BorderSide(
                    color: selected ? Theme.of(context).primaryColor : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
              child: Text(
                item.name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.25,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected ? Theme.of(context).primaryColor : Colors.black87,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildResults() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return _buildMessage(Icons.wifi_off, _error!, 'Retry', () => _load(reset: true));
    }

    if (_products.isEmpty) {
      final filters = context.read<FilterProvider>();
      final hasQuery = filters.activeFilterCount > 0 || _search.isNotEmpty;
      return _buildMessage(
        Icons.inventory_2_outlined,
        hasQuery ? 'No products match your filters.' : 'Nothing here yet.',
        hasQuery ? 'Clear filters' : null,
        hasQuery
            ? () {
                filters.clearFilters();
                _searchController.clear();
                _search = '';
                _load(reset: true);
              }
            : null,
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: GridView.builder(
        controller: _scroll,
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.56,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        // One extra cell carries the paging spinner at the end of the list.
        itemCount: _products.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _products.length) {
            return const Center(child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(strokeWidth: 2),
            ));
          }
          final product = _products[index];
          return ProductCard(
            image: product.image,
            brand: product.brand ?? 'Unknown',
            name: product.name,
            price: product.price,
            discountedPrice: product.discountedPrice,
            discountPercent: product.discountPercent.toInt(),
            product: product,
            press: () => Navigator.pushNamed(
              context,
              productDetailsScreenRoute,
              arguments: product,
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessage(IconData icon, String message, String? actionLabel, VoidCallback? onAction) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(message, textAlign: TextAlign.center),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ],
      ),
    );
  }
}
