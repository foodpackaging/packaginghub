import 'package:flutter/material.dart';
import 'package:b2b_store/shop_ui/components/cart/cart_quantity_control.dart';
import 'package:b2b_store/shop_ui/constants.dart';
import 'package:b2b_store/shop_ui/route/route_constants.dart';
import 'package:b2b_store/shop_ui/services/cms_service.dart';
import 'package:b2b_store/shared/models/filter_model.dart';
import 'package:b2b_store/shared/models/product.dart';
import 'package:b2b_store/shop_ui/components/cart/cart_summary_bar.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final CmsService _cmsService = CmsService();
  
  Map<String, dynamic>? _selectedCategory;
  Map<String, dynamic>? _activeSubCategory; // Currently selected sub-category
  List<Map<String, dynamic>> _allCategories = [];
  List<Map<String, dynamic>> _cmsFilterConfigs = [];
  List<Product> _products = [];
  bool _isLoading = true;

  // Filters State
  String? _currentSort; // null, 'low_to_high', 'high_to_low', 'name_asc'
  final Map<String, dynamic> _activeFilterSelections = {};

  @override
  void initState() {
    super.initState();
    // Categories will be loaded in didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic> && _selectedCategory == null) {
      _selectedCategory = args;
      _loadInitialData();
    }
  }

  Future<void> _loadInitialData() async {
    await _loadCategories(); // Load sidebar based on selected main category
    if (_selectedCategory != null) {
      // Fetch fresh parent category to make sure we have the latest filter_configs
      try {
        final parentId = _selectedCategory!['id']?.toString();
        if (parentId != null) {
          final freshParent = await _cmsService.getCategoryById(parentId);
          if (freshParent != null && mounted) {
            setState(() {
              _selectedCategory = freshParent;
            });
          }
        }
      } catch (e) {
        debugPrint("Error loading fresh parent category: $e");
      }
      await _loadFilterConfigs();
      _loadProducts(_selectedCategory!['id']); // Load products for the initial selection
    }
  }

  Future<void> _loadFilterConfigs() async {
    final categoryId = _selectedCategory?['id']?.toString();
    final subcategoryId = _activeSubCategory?['id']?.toString();
    if (categoryId == null) return;

    try {
      final filters = await _cmsService.getFilters(
        categoryId: categoryId,
        subcategoryId: subcategoryId,
      );
      if (mounted) {
        setState(() {
          _cmsFilterConfigs = filters.map(_filterToDiscoverConfig).toList();
        });
      }
    } catch (e) {
      debugPrint("Error loading filters: $e");
      if (mounted) {
        setState(() {
          _cmsFilterConfigs = [];
        });
      }
    }
  }

  Map<String, dynamic> _filterToDiscoverConfig(ProductFilter filter) {
    return {
      'id': filter.key,
      'name': filter.label,
      'type': _discoverFilterType(filter.uiType),
      'options': filter.options,
      'scope': filter.scope,
      'sort_order': filter.sortOrder,
    };
  }

  String _discoverFilterType(String uiType) {
    switch (uiType) {
      case 'boolean':
      case 'rating':
        return 'boolean';
      case 'range':
        return 'range';
      case 'single-select':
      case 'chip-selection':
        return 'single-select';
      case 'multiselect':
      default:
        return 'multiselect';
    }
  }

  Future<void> _loadCategories() async {
    try {
      if (_selectedCategory != null) {
        // Fetch sub-categories of the main category we just clicked
        final subs = await _cmsService.getSubCategories(_selectedCategory!['id']);
        if (mounted) {
          setState(() {
            _allCategories = subs;
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading subcategories: $e");
    }
  }

  Future<void> _loadProducts(dynamic categoryId) async {
    if (!mounted) return;
    setState(() { _isLoading = true; });
    
    try {
      final id = categoryId?.toString();
      final products = id == null
          ? await _cmsService.getProducts()
          : await _cmsService.getProductsByCategory(id);
      
      if (mounted) {
        setState(() {
          _products = products;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading products: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }



  List<dynamic> _getCommonFilterConfigs() {
    if (_cmsFilterConfigs.isNotEmpty) {
      return _cmsFilterConfigs
          .where((config) => config['scope'] == 'global' || config['scope'] == 'category')
          .toList();
    }

    final List<dynamic> configs = [];
    if (_selectedCategory != null && _selectedCategory!['filter_configs'] != null) {
      final categoryConfigs = _selectedCategory!['filter_configs'];
      configs.addAll((categoryConfigs as List<dynamic>?) ?? []);
    }
    return configs;
  }

  List<dynamic> _getSpecificFilterConfigs() {
    if (_cmsFilterConfigs.isNotEmpty) {
      return _cmsFilterConfigs
          .where((config) => config['scope'] == 'subcategory')
          .toList();
    }

    final List<dynamic> configs = [];
    if (_activeSubCategory != null && _activeSubCategory!['filter_configs'] != null) {
      final subCategoryConfigs = _activeSubCategory!['filter_configs'];
      configs.addAll((subCategoryConfigs as List<dynamic>?) ?? []);
    }
    return configs;
  }

  int _getActiveCommonFiltersCount() {
    int count = 0;
    final commonConfigs = _getCommonFilterConfigs();
    for (final config in commonConfigs) {
      if (config is Map) {
        final id = config['id']?.toString();
        if (id != null && _activeFilterSelections.containsKey(id)) {
          final selection = _activeFilterSelections[id];
          if (selection is bool && selection == true) {
            count++;
          } else if (selection is List && selection.isNotEmpty) {
            count++;
          } else if (selection is Map && (selection['min'] != null || selection['max'] != null)) {
            count++;
          } else if (selection is String && selection.isNotEmpty) {
            count++;
          }
        }
      }
    }
    return count;
  }

  // Local Filtered Products computing
  List<Product> get _filteredProducts {
    List<Product> list = List.from(_products);
    
    // Apply dynamic CMS filters in real-time
    _activeFilterSelections.forEach((filterId, selectionValue) {
      if (selectionValue == null) return;
      
      // 1. Boolean filter type
      if (selectionValue is bool) {
        if (selectionValue == true) {
          list = list.where((p) {
            if (filterId.contains('rating') || filterId.contains('rated')) {
              final ratingCode = p.id.hashCode % 10;
              final rating = 3.5 + (ratingCode * 0.15); // yields values between 3.5 and 4.85
              return rating >= 4.0;
            }
            
            final nameLower = p.name.toLowerCase();
            final descLower = (p.description ?? '').toLowerCase();
            final term = filterId.replaceFirst('is_', '').replaceAll('_', ' ');
            return nameLower.contains(term) || descLower.contains(term);
          }).toList();
        }
      }
      
      // 2. Multiselect filter type
      else if (selectionValue is List && selectionValue.isNotEmpty) {
        final List<String> selectedOptions = List<String>.from(selectionValue);
        list = list.where((p) {
          if (filterId == 'brand') {
            return p.brand != null && selectedOptions.any((opt) => p.brand!.toLowerCase().trim() == opt.toLowerCase().trim());
          }
          
          final nameLower = p.name.toLowerCase();
          final descLower = (p.description ?? '').toLowerCase();
          final brandLower = (p.brand ?? '').toLowerCase();
          final unitLower = p.unit.toLowerCase();
          
          return selectedOptions.any((option) {
            final optionLower = option.toLowerCase().trim();
            return nameLower.contains(optionLower) || 
                   descLower.contains(optionLower) || 
                   brandLower.contains(optionLower) || 
                   unitLower.contains(optionLower);
          });
        }).toList();
      }

      else if (selectionValue is String && selectionValue.isNotEmpty) {
        list = list.where((p) {
          if (filterId == 'brand') {
            return p.brand != null && p.brand!.toLowerCase().trim() == selectionValue.toLowerCase().trim();
          }

          final needle = selectionValue.toLowerCase().trim();
          return p.name.toLowerCase().contains(needle) ||
              (p.description ?? '').toLowerCase().contains(needle) ||
              (p.brand ?? '').toLowerCase().contains(needle) ||
              p.unit.toLowerCase().contains(needle);
        }).toList();
      }

      else if (selectionValue is Map) {
        final min = selectionValue['min'];
        final max = selectionValue['max'];
        if (filterId == 'price') {
          list = list.where((p) {
            final price = p.discountedPrice;
            final minOk = min is num ? price >= min : true;
            final maxOk = max is num ? price <= max : true;
            return minOk && maxOk;
          }).toList();
        }
      }
    });
    
    // Sort logic
    if (_currentSort == 'low_to_high') {
      list.sort((a, b) => a.discountedPrice.compareTo(b.discountedPrice));
    } else if (_currentSort == 'high_to_low') {
      list.sort((a, b) => b.discountedPrice.compareTo(a.discountedPrice));
    } else if (_currentSort == 'name_asc') {
      list.sort((a, b) => a.name.compareTo(b.name));
    }
    
    return list;
  }

  void _showSortDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Sort Products By", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: navyDark)),
                  const SizedBox(height: 16),
                  _buildSortOption(
                    context, 
                    label: "Default (Newest)", 
                    value: null, 
                    selectedValue: _currentSort,
                    onTap: () {
                      setState(() => _currentSort = null);
                      Navigator.pop(context);
                    }
                  ),
                  _buildSortOption(
                    context, 
                    label: "Price: Low to High", 
                    value: 'low_to_high', 
                    selectedValue: _currentSort,
                    onTap: () {
                      setState(() => _currentSort = 'low_to_high');
                      Navigator.pop(context);
                    }
                  ),
                  _buildSortOption(
                    context, 
                    label: "Price: High to Low", 
                    value: 'high_to_low', 
                    selectedValue: _currentSort,
                    onTap: () {
                      setState(() => _currentSort = 'high_to_low');
                      Navigator.pop(context);
                    }
                  ),
                  _buildSortOption(
                    context, 
                    label: "Product Name: A to Z", 
                    value: 'name_asc', 
                    selectedValue: _currentSort,
                    onTap: () {
                      setState(() => _currentSort = 'name_asc');
                      Navigator.pop(context);
                    }
                  ),
                ],
              ),
            );
          }
        );
      }
    );
  }

  Widget _buildSortOption(
    BuildContext context, {
    required String label,
    required String? value,
    required String? selectedValue,
    required VoidCallback onTap,
  }) {
    final isSelected = value == selectedValue;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 14, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? accentRed : navyDark)),
            if (isSelected) const Icon(Icons.check_circle_rounded, color: accentRed, size: 20),
          ],
        ),
      ),
    );
  }

  void _showMultiselectDialog(String filterId, String filterName, List<String> options) {
    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No options available for $filterName"), duration: const Duration(seconds: 1)),
      );
      return;
    }

    if (!_activeFilterSelections.containsKey(filterId)) {
      _activeFilterSelections[filterId] = <String>[];
    }
    
    final List<String> localSelected = List<String>.from((_activeFilterSelections[filterId] as List?) ?? []);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Filter by $filterName", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: navyDark)),
                      if (localSelected.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            setModalState(() {
                              localSelected.clear();
                            });
                            setState(() {
                              _activeFilterSelections.remove(filterId);
                            });
                          },
                          child: const Text("Clear All", style: TextStyle(fontSize: 12, color: accentRed, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final option = options[index];
                        final isChecked = localSelected.contains(option);
                        return CheckboxListTile(
                          title: Text(option, style: const TextStyle(fontSize: 14, color: navyDark)),
                          activeColor: accentRed,
                          value: isChecked,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (val) {
                            setModalState(() {
                              if (val == true) {
                                localSelected.add(option);
                              } else {
                                localSelected.remove(option);
                              }
                            });
                            setState(() {
                              if (localSelected.isEmpty) {
                                _activeFilterSelections.remove(filterId);
                              } else {
                                _activeFilterSelections[filterId] = localSelected;
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentRed,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text("Apply Filter", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          }
        );
      }
    );
  }

  void _showCommonFiltersSheet() {
    final commonConfigs = _getCommonFilterConfigs();
    if (commonConfigs.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final activeCount = _getActiveCommonFiltersCount();

            return Container(
              padding: EdgeInsets.only(
                top: 12,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Filters",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: navyDark,
                        ),
                      ),
                      if (activeCount > 0)
                        GestureDetector(
                          onTap: () {
                            setModalState(() {
                              for (final config in commonConfigs) {
                                if (config is Map) {
                                  final id = config['id']?.toString();
                                  if (id != null) {
                                    _activeFilterSelections.remove(id);
                                  }
                                }
                              }
                            });
                            setState(() {
                              for (final config in commonConfigs) {
                                if (config is Map) {
                                  final id = config['id']?.toString();
                                  if (id != null) {
                                    _activeFilterSelections.remove(id);
                                  }
                                }
                              }
                            });
                          },
                          child: const Text(
                            "Clear All",
                            style: TextStyle(
                              fontSize: 13,
                              color: accentRed,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFFF3F4F6), height: 1),
                  const SizedBox(height: 16),
                  
                  // Scrollable filters list
                  Flexible(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: commonConfigs.map<Widget>((config) {
                          if (config is! Map) return const SizedBox.shrink();
                          
                          final String id = config['id']?.toString() ?? '';
                          final String name = config['name']?.toString() ?? '';
                          final String type = config['type']?.toString() ?? 'multiselect';
                          final optionsList = config['options'] is List 
                              ? ((config['options'] as List?) ?? []).map((e) => e.toString()).toList() 
                              : <String>[];
                          
                          if (type == 'boolean') {
                            final isSelected = _activeFilterSelections[id] == true;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFFFF8F8) : const Color(0xFFF9FAFB),
                                border: Border.all(
                                  color: isSelected ? accentRed : const Color(0xFFE5E7EB),
                                  width: 1,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: CheckboxListTile(
                                title: Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: navyDark,
                                  ),
                                ),
                                activeColor: accentRed,
                                value: isSelected,
                                controlAffinity: ListTileControlAffinity.trailing,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                                onChanged: (val) {
                                  setModalState(() {
                                    if (val == true) {
                                      _activeFilterSelections[id] = true;
                                    } else {
                                      _activeFilterSelections.remove(id);
                                    }
                                  });
                                  setState(() {
                                    if (val == true) {
                                      _activeFilterSelections[id] = true;
                                    } else {
                                      _activeFilterSelections.remove(id);
                                    }
                                  });
                                },
                              ),
                            );
                          } else if (type == 'range') {
                            final currentValue = _activeFilterSelections[id];
                            final currentMap = currentValue is Map ? currentValue : <String, dynamic>{};
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: navyDark,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        initialValue: currentMap['min']?.toString() ?? '',
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          labelText: "Min",
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                        ),
                                        onChanged: (value) {
                                          final latestValue = _activeFilterSelections[id];
                                          final next = Map<String, dynamic>.from(
                                            latestValue is Map ? latestValue : <String, dynamic>{},
                                          );
                                          next['min'] = double.tryParse(value);
                                          next.removeWhere((_, v) => v == null);
                                          setModalState(() {
                                            if (next.isEmpty) {
                                              _activeFilterSelections.remove(id);
                                            } else {
                                              _activeFilterSelections[id] = next;
                                            }
                                          });
                                          setState(() {
                                            if (next.isEmpty) {
                                              _activeFilterSelections.remove(id);
                                            } else {
                                              _activeFilterSelections[id] = next;
                                            }
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        initialValue: currentMap['max']?.toString() ?? '',
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          labelText: "Max",
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                        ),
                                        onChanged: (value) {
                                          final latestValue = _activeFilterSelections[id];
                                          final next = Map<String, dynamic>.from(
                                            latestValue is Map ? latestValue : <String, dynamic>{},
                                          );
                                          next['max'] = double.tryParse(value);
                                          next.removeWhere((_, v) => v == null);
                                          setModalState(() {
                                            if (next.isEmpty) {
                                              _activeFilterSelections.remove(id);
                                            } else {
                                              _activeFilterSelections[id] = next;
                                            }
                                          });
                                          setState(() {
                                            if (next.isEmpty) {
                                              _activeFilterSelections.remove(id);
                                            } else {
                                              _activeFilterSelections[id] = next;
                                            }
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                              ],
                            );
                          } else {
                            final currentValue = _activeFilterSelections[id];
                            final List<String> selectedOptions = type == 'single-select'
                                ? (currentValue == null ? <String>[] : <String>[currentValue.toString()])
                                : List<String>.from((currentValue as List?) ?? []);

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: navyDark,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: optionsList.map((option) {
                                    final isChecked = selectedOptions.contains(option);
                                    return GestureDetector(
                                      onTap: () {
                                        setModalState(() {
                                          if (type == 'single-select') {
                                            if (isChecked) {
                                              _activeFilterSelections.remove(id);
                                            } else {
                                              _activeFilterSelections[id] = option;
                                            }
                                          } else {
                                            if (isChecked) {
                                              selectedOptions.remove(option);
                                            } else {
                                              selectedOptions.add(option);
                                            }
                                            if (selectedOptions.isEmpty) {
                                              _activeFilterSelections.remove(id);
                                            } else {
                                              _activeFilterSelections[id] = selectedOptions;
                                            }
                                          }
                                        });
                                        setState(() {
                                          if (type == 'single-select') {
                                            if (isChecked) {
                                              _activeFilterSelections.remove(id);
                                            } else {
                                              _activeFilterSelections[id] = option;
                                            }
                                          } else {
                                            if (selectedOptions.isEmpty) {
                                              _activeFilterSelections.remove(id);
                                            } else {
                                              _activeFilterSelections[id] = selectedOptions;
                                            }
                                          }
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: isChecked ? const Color(0xFFFFF1F1) : Colors.white,
                                          border: Border.all(
                                            color: isChecked ? accentRed : const Color(0xFFE5E7EB),
                                            width: 1,
                                          ),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          option,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isChecked ? accentRed : const Color(0xFF4B5563),
                                            fontWeight: isChecked ? FontWeight.bold : FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 20),
                              ],
                            );
                          }
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentRed,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text("Apply Filters", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChip(
    String label, {
    required bool isSelected,
    required VoidCallback onTap,
    Widget? leading,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF1F1) : Colors.white,
          border: Border.all(
            color: isSelected ? accentRed : const Color(0xFFE5E7EB),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[
              leading,
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? accentRed : const Color(0xFF4B5563),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterRow() {
    final commonConfigs = _getCommonFilterConfigs();
    final specificConfigs = _getSpecificFilterConfigs();
    final activeCommonCount = _getActiveCommonFiltersCount();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // 1. Keep Sort filter first
            _buildFilterChip(
              _currentSort == null 
                ? "Sort ⌄" 
                : _currentSort == 'low_to_high'
                  ? "Price: Low to High ⌄"
                  : _currentSort == 'high_to_low'
                    ? "Price: High to Low ⌄"
                    : "Name A-Z ⌄", 
              isSelected: _currentSort != null, 
              onTap: _showSortDialog,
              leading: Icon(Icons.swap_vert_rounded, size: 14, color: _currentSort != null ? accentRed : const Color(0xFF6B7280)),
            ),
            
            // 2. Filters Button/Chip for Common Filters
            if (commonConfigs.isNotEmpty) ...[
              const SizedBox(width: 8),
              _buildFilterChip(
                activeCommonCount > 0 ? "Filters ($activeCommonCount) ⌄" : "Filters ⌄",
                isSelected: activeCommonCount > 0,
                onTap: _showCommonFiltersSheet,
                leading: Icon(
                  Icons.filter_alt_outlined,
                  size: 14,
                  color: activeCommonCount > 0 ? accentRed : const Color(0xFF6B7280),
                ),
              ),
            ],
            
            // 3. Render specific filters for active subcategory as individual chips
            ...specificConfigs.map((config) {
              if (config is! Map) return const SizedBox.shrink();
              
              final String id = config['id']?.toString() ?? '';
              final String name = config['name']?.toString() ?? '';
              final String type = config['type']?.toString() ?? 'multiselect';
              final optionsList = config['options'] is List 
                  ? ((config['options'] as List?) ?? []).map((e) => e.toString()).toList() 
                  : <String>[];
              
              final selection = _activeFilterSelections[id];
              final isSelected = selection is bool
                  ? selection == true
                  : selection is List
                      ? selection.isNotEmpty
                      : selection is Map
                          ? selection['min'] != null || selection['max'] != null
                          : selection is String
                              ? selection.isNotEmpty
                              : false;
              
              String label = name;
              if (type == 'multiselect' && isSelected) {
                final List<String> selectedList = List<String>.from((_activeFilterSelections[id] as List?) ?? []);
                label = "$name: ${selectedList.join(', ')} ⌄";
              } else if (type == 'multiselect') {
                label = "$name ⌄";
              }
              
              return Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: _buildFilterChip(
                  label,
                  isSelected: isSelected,
                  onTap: () {
                    if (type == 'boolean') {
                      setState(() {
                        if (_activeFilterSelections.containsKey(id)) {
                          _activeFilterSelections.remove(id);
                        } else {
                          _activeFilterSelections[id] = true;
                        }
                      });
                    } else {
                      _showMultiselectDialog(id, name, optionsList);
                    }
                  },
                  leading: type == 'boolean' 
                    ? Icon(Icons.check_circle_outline_rounded, size: 14, color: isSelected ? accentRed : const Color(0xFF9CA3AF))
                    : null,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String title = _selectedCategory?['name'] ?? "Products";

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: navyDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(color: navyDark, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text("Change category", style: TextStyle(color: accentRed, fontSize: 11, fontWeight: FontWeight.w600)),
                  SizedBox(width: 2),
                  Icon(Icons.keyboard_arrow_down, size: 14, color: accentRed),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search, color: navyDark, size: 22), onPressed: () {}),
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined, color: navyDark, size: 22),
            onPressed: () => Navigator.pushNamed(context, cartScreenRoute),
          ),
        ],
      ),
      body: Row(
        children: [
          // SIDEBAR (dynamically shows sub-categories with virtual 'All' first)
          Container(
            width: 85,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: Color(0xFFF3F4F6)))
            ),
            child: ListView.builder(
              itemCount: _allCategories.length + 1, // +1 for the virtual "All" item
              itemBuilder: (context, index) {
                if (index == 0) {
                  // Virtual "All" category item
                  final isSelected = _activeSubCategory == null;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _activeSubCategory = null;
                        _activeFilterSelections.clear();
                      });
                      _loadFilterConfigs();
                      _loadProducts(_selectedCategory?['id']);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
                      decoration: BoxDecoration(
                        border: Border(left: BorderSide(color: isSelected ? accentRed : Colors.transparent, width: 3.5)),
                        color: isSelected ? const Color(0xFFFFF8F8) : Colors.white,
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFFFF1F1) : const Color(0xFFF3F4F6), 
                              shape: BoxShape.circle
                            ),
                            child: Icon(
                              Icons.apps_rounded, 
                              color: isSelected ? accentRed : const Color(0xFF6B7280), 
                              size: 20
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "All", 
                            textAlign: TextAlign.center, 
                            style: TextStyle(
                              fontSize: 9.5, 
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, 
                              color: isSelected ? accentRed : const Color(0xFF4B5563)
                            )
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Regular subcategories
                final cat = _allCategories[index - 1];
                final isSelected = _activeSubCategory != null && _activeSubCategory!['id'].toString() == cat['id'].toString();
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _activeSubCategory = cat;
                      _activeFilterSelections.clear();
                    });
                    _loadFilterConfigs();
                    _loadProducts(cat['id']);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
                    decoration: BoxDecoration(
                      border: Border(left: BorderSide(color: isSelected ? accentRed : Colors.transparent, width: 3.5)),
                      color: isSelected ? const Color(0xFFFFF8F8) : Colors.white,
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 44, height: 44,
                          decoration: const BoxDecoration(color: Color(0xFFF9FAFB), shape: BoxShape.circle),
                          child: ClipOval(
                            child: Image.network(
                              cat['icon_url'] ?? "https://i.imgur.com/K41Mj7C.png", 
                              fit: BoxFit.cover, 
                              errorBuilder: (_,__,___) => Icon(
                                Icons.category_rounded, 
                                size: 20, 
                                color: isSelected ? accentRed : const Color(0xFF9CA3AF)
                              )
                            )
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          cat['name'], 
                          textAlign: TextAlign.center, 
                          maxLines: 2, 
                          style: TextStyle(
                            fontSize: 9.5, 
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, 
                            color: isSelected ? accentRed : const Color(0xFF4B5563), 
                            height: 1.1
                          )
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          // MAIN CONTENT
          Expanded(
            child: Column(
              children: [
                _buildSavingsBanner(),
                _buildFilterRow(), // Horizontal Filter Chips added here!
                Expanded(
                  child: _isLoading 
                    ? const Center(child: CircularProgressIndicator(color: accentRed))
                    : _filteredProducts.isEmpty
                      ? const Center(child: Text("No products found", style: TextStyle(color: mutedText)))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _filteredProducts.length,
                          itemBuilder: (context, index) => _buildProductCard(_filteredProducts[index]),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const CartSummaryBar(),
    );
  }

  Widget _buildSavingsBanner() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFF8F1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: const [
          Icon(Icons.stars, color: Colors.orange, size: 14),
          SizedBox(width: 8),
          Expanded(
            child: Text("Save more with B2B bulk pricing", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF444444))),
          ),
        ],
      ),
    );
  }

Widget _buildProductCard(Product p) {
  final ratingCode = p.id.hashCode % 10;
  final simulatedRating = 4.0 + (ratingCode * 0.1);
  final simulatedReviews = 100 + (ratingCode * 25);
  final minOrderQty = p.minOrderQty > 0 ? p.minOrderQty : 1;
  final perPieceCalculated = p.discountedPrice / minOrderQty;

  return InkWell(
    onTap: () {
      Navigator.pushNamed(
        context,
        productDetailsScreenRoute,
        arguments: p,
      );
    },
    borderRadius: BorderRadius.circular(12),
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFEEEEEE)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0FE),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  "Price drop alert",
                  style: TextStyle(color: alertBlue, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),

              if (p.discountPercent > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: alertBlue,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    "${p.discountPercent.toInt()}% OFF",
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),

            ],
          ),

          const SizedBox(height: 12),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [

                    Text(
                      p.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: navyDark),
                      maxLines: 2,
                    ),

                    const SizedBox(height: 4),

                    Text(
                      "${p.minOrderQty} ${p.unit}",
                      style: const TextStyle(fontSize: 11, color: mutedText),
                    ),

                    const SizedBox(height: 8),

                    Row(
                      children: [

                        Container(
                          padding:
                              const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF2E7D32),
                            borderRadius:
                                BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [

                              const Icon(
                                Icons.star,
                                size: 10,
                                color: Colors.white,
                              ),

                              Text(
                                " ${simulatedRating.toStringAsFixed(1)}",
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),

                            ],
                          ),
                        ),

                        const SizedBox(width: 4),

                        Text(
                          "($simulatedReviews)",
                          style: const TextStyle(fontSize: 10, color: mutedText),
                        ),

                      ],
                    ),

                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [

                        Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [

                            Text(
                              "₹${p.discountedPrice.toInt()}",
                            ),

                            if (p.minOrderQty > 1)
                              Text(
                                "₹${perPieceCalculated.toStringAsFixed(2)}",
                              ),

                          ],
                        ),

                        CartQuantityControl(product: p, compact: true),

                      ],
                    ),

                  ],
                ),
              ),

              const SizedBox(width: 12),

              Container(
                width: 75,
                height: 75,
                child: p.images.isNotEmpty
                    ? Image.network(
                        p.images[0],
                        fit: BoxFit.cover,
                      )
                    : const Icon(Icons.image),
              ),

            ],
          ),

        ],
      ),
    ),
  );
}
}
