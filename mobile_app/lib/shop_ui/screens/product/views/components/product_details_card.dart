import 'package:flutter/material.dart';
import 'package:b2b_store/shared/models/product.dart';
import 'package:b2b_store/shared/models/filter_model.dart';
import 'package:b2b_store/shop_ui/services/cms_service.dart';

class ProductDetailsCard extends StatefulWidget {
  final Product product;

  const ProductDetailsCard({super.key, required this.product});

  @override
  State<ProductDetailsCard> createState() => _ProductDetailsCardState();
}

class _ProductDetailsCardState extends State<ProductDetailsCard> {
  final CmsService _cmsService = CmsService();
  bool _isLoading = true;
  List<ProductFilter> _filters = [];

  @override
  void initState() {
    super.initState();
    _loadFilters();
  }

  Future<void> _loadFilters() async {
    try {
      final catId = widget.product.categoryId;
      if (catId != null) {
        // The categoryId on product could be a subcategory or main category,
        // getFilters will resolve parent if it's a subcategory based on our previous logic.
        // Pass it as subcategoryId to ensure both scopes are loaded.
        final filters = await _cmsService.getFilters(subcategoryId: catId);
        if (mounted) {
          setState(() {
            _filters = filters;
            _isLoading = false;
          });
        }
        return;
      }
    } catch (e) {
      debugPrint("Error loading filters for product details: $e");
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getLabelForKey(String key) {
    // Try to find the exact label from CMS filters
    final filter = _filters.where((f) => f.key == key).firstOrNull;
    if (filter != null) {
      return filter.label;
    }
    
    // Fallback: format the key (e.g., 'ideal_uses' -> 'Ideal Uses')
    return key
        .split('_')
        .map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1)}' : '')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    // Collect all attributes to show
    final Map<String, dynamic> attributes = Map.from(widget.product.attributes);
    // Remove productInformationSections if it's stored in attributes
    attributes.remove('productInformationSections');
    attributes.remove('product_information_sections');
    
    // Also include old informationSections if any are present
    final bool hasInfoSections = widget.product.productInformationSections.isNotEmpty;

    if (attributes.isEmpty && !hasInfoSections) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Product details",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 20),
              
              if (_isLoading)
                const Center(child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ))
              else
                ...attributes.entries.map((entry) {
                  final key = entry.key;
                  final value = entry.value;
                  
                  // Skip nulls or empties
                  if (value == null || value.toString().trim().isEmpty) {
                    return const SizedBox.shrink();
                  }
                  
                  // Format value if it's a list (e.g., multiselect)
                  String displayValue = "";
                  if (value is List) {
                    displayValue = value.map((e) => e.toString()).join(", ");
                  } else {
                    displayValue = value.toString();
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 120,
                          child: Text(
                            _getLabelForKey(key),
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            displayValue,
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 13,
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

              // Append old information sections if present
              if (hasInfoSections) ...[
                if (attributes.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Divider(color: Color(0xFFF1F5F9), thickness: 1.5),
                  ),
                ...widget.product.productInformationSections.map((section) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 120,
                          child: Text(
                            section.heading,
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            section.content,
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 13,
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
