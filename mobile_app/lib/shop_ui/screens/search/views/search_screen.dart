import 'package:flutter/material.dart';
import 'package:b2b_store/shared/models/product.dart';
import 'package:b2b_store/shared/services/api_service.dart';
import 'package:b2b_store/shop_ui/constants.dart';
import 'package:b2b_store/shop_ui/components/product/product_card.dart';
import 'package:b2b_store/shop_ui/route/route_constants.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _apiService = ApiService();
  final _searchController = TextEditingController();
  List<Product> _searchResults = [];
  bool _isLoading = false;
  String _lastQuery = "";

  void _onSearch(String query) async {
    if (query.isEmpty || query == _lastQuery) return;
    
    setState(() {
      _isLoading = true;
      _lastQuery = query;
    });

    try {
      final results = await _apiService.getProducts(search: query);
      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Search error: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: "Search products...",
            border: InputBorder.none,
          ),
          onSubmitted: _onSearch,
        ),
        actions: [
          IconButton(
            onPressed: () => _onSearch(_searchController.text),
            icon: const Icon(Icons.search),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _searchResults.isEmpty && _lastQuery.isNotEmpty
              ? Center(child: Text("No results found for '$_lastQuery'"))
              : GridView.builder(
                  padding: const EdgeInsets.all(defaultPadding),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: defaultPadding,
                    crossAxisSpacing: defaultPadding,
                    childAspectRatio: 0.62,
                  ),
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final product = _searchResults[index];
                    return ProductCard(
                      image: product.image,
                      name: product.name,
                      brand: product.brand ?? "",
                      price: product.price,
                      discountedPrice: product.discountedPrice,
                      discountPercent: product.discountPercent?.toInt(),
                      product: product,
                      press: () {
                        Navigator.pushNamed(
                          context,
                          productDetailsScreenRoute,
                          arguments: product,
                        );
                      },
                    );
                  },
                ),
    );
  }
}
