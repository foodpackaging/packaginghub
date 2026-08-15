class FilterOption {
  final String label;
  final dynamic value;

  FilterOption({required this.label, required this.value});
}

class ProductFilter {
  final String id;
  final String key;
  final String label;
  final String scope;
  final String uiType;
  final String dataType;
  final List<dynamic> options;
  final int sortOrder;
  final bool isRequired;
  final bool showInMobileFilters;
  final bool isSearchable;
  final String? defaultValue;

  ProductFilter({
    required this.id,
    required this.key,
    required this.label,
    required this.scope,
    required this.uiType,
    required this.dataType,
    required this.options,
    required this.sortOrder,
    this.isRequired = false,
    this.showInMobileFilters = true,
    this.isSearchable = false,
    this.defaultValue,
  });

  factory ProductFilter.fromJson(Map<String, dynamic> json) {
    return ProductFilter(
      id: json['id']?.toString() ?? '',
      key: json['key']?.toString() ?? '',
      label: json['label']?.toString() ?? 'Unknown Filter',
      scope: json['scope']?.toString() ?? 'global',
      uiType: json['ui_type']?.toString() ?? 'multiselect',
      dataType: json['data_type']?.toString() ?? 'string',
      options: json['options'] is List ? List.from(json['options']) : [],
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isRequired: json['is_required'] as bool? ?? false,
      showInMobileFilters: json['show_in_mobile_filters'] as bool? ?? true,
      isSearchable: json['is_searchable'] as bool? ?? false,
      defaultValue: json['default_value']?.toString(),
    );
  }
}
