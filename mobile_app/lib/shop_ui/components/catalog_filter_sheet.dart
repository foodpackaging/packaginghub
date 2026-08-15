import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:b2b_store/shared/providers/filter_provider.dart';
import 'package:b2b_store/shared/models/filter_model.dart';
import 'package:b2b_store/shared/models/catalog_page.dart';

/// Filter panel backed by server-computed facet counts.
///
/// Each option shows how many products it would return, and options that would
/// return nothing are disabled rather than hidden — so the shape of the catalog
/// stays visible instead of choices silently disappearing.
///
/// Pops `true` when filters were applied, so the caller knows to refetch.
class CatalogFilterSheet extends StatefulWidget {
  const CatalogFilterSheet({
    super.key,
    required this.facets,
    required this.resultTotal,
  });

  final CatalogFacets facets;
  final int resultTotal;

  @override
  State<CatalogFilterSheet> createState() => _CatalogFilterSheetState();
}

class _CatalogFilterSheetState extends State<CatalogFilterSheet> {
  late Map<String, dynamic> _draft;

  @override
  void initState() {
    super.initState();
    // Edit a copy so backing out of the sheet leaves the applied filters alone.
    _draft = Map<String, dynamic>.from(context.read<FilterProvider>().activeFilters);
  }

  void _set(String key, dynamic value) {
    setState(() {
      if (value == null || (value is List && value.isEmpty) || value == '') {
        _draft.remove(key);
      } else {
        _draft[key] = value;
      }
    });
  }

  void _apply() {
    final provider = context.read<FilterProvider>();
    provider.clearFilters();
    _draft.forEach(provider.setFilterValue);
    Navigator.pop(context, true);
  }

  /// Brand isn't an attribute filter, so it won't appear in the Filter collection —
  /// synthesise an entry for it whenever the catalog has brands to offer.
  List<ProductFilter> get _sections {
    final defined = context
        .read<FilterProvider>()
        .availableFilters
        .where((f) => f.showInMobileFilters)
        .toList();

    final hasBrandSection = defined.any((f) => f.key == 'brand');
    if (!hasBrandSection && widget.facets.brands.isNotEmpty) {
      return [
        ProductFilter(
          id: '_brand',
          key: 'brand',
          label: 'Brand',
          scope: 'global',
          uiType: 'multiselect',
          dataType: 'string',
          options: widget.facets.brands.map((b) => b.value).toList(),
          sortOrder: -1,
        ),
        ...defined,
      ];
    }
    return defined;
  }

  @override
  Widget build(BuildContext context) {
    final sections = _sections;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Filters', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                if (_draft.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(() => _draft.clear()),
                    child: const Text('Clear all'),
                  ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context, false),
                ),
              ],
            ),
          ),
          Expanded(
            child: sections.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'No filters are set up for this category yet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: sections.length,
                    separatorBuilder: (context, index) => const Divider(height: 32),
                    itemBuilder: (context, index) => _buildSection(sections[index]),
                  ),
          ),
          Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  offset: const Offset(0, -4),
                  blurRadius: 10,
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _apply,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Show results', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(ProductFilter filter) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(filter.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 10),
        _buildInput(filter),
      ],
    );
  }

  Widget _buildInput(ProductFilter filter) {
    final current = _draft[filter.key];

    switch (filter.uiType) {
      case 'multiselect':
      case 'chip-selection':
        final isMulti = filter.uiType == 'multiselect';
        final selected = isMulti
            ? List.from(current as List? ?? const [])
            : (current != null ? [current] : []);

        // Prefer the values the catalog actually contains; fall back to the
        // configured options when this facet wasn't counted.
        final facetValues = widget.facets.valuesFor(filter.key);
        final options = facetValues.isNotEmpty
            ? facetValues.map((f) => f.value).toList()
            : filter.options;

        if (options.isEmpty) {
          return const Text('No options available', style: TextStyle(color: Colors.grey, fontSize: 13));
        }

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = selected.any((s) => s.toString() == option.toString());
            final count = widget.facets.countFor(filter.key, option);
            // A zero-count option is still worth showing — it tells the user the
            // value exists — but selecting it would just empty the grid.
            final disabled = count == 0 && !isSelected;

            return FilterChip(
              label: Text(count != null ? '$option ($count)' : option.toString()),
              selected: isSelected,
              onSelected: disabled
                  ? null
                  : (nowSelected) {
                      if (isMulti) {
                        final next = List.from(selected);
                        if (nowSelected) {
                          next.add(option);
                        } else {
                          next.removeWhere((s) => s.toString() == option.toString());
                        }
                        _set(filter.key, next);
                      } else {
                        _set(filter.key, nowSelected ? option : null);
                      }
                    },
              selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.18),
              checkmarkColor: Theme.of(context).primaryColor,
            );
          }).toList(),
        );

      case 'boolean':
        return SwitchListTile(
          title: Text(
            filter.key == 'availability'
                ? 'In stock only (${widget.facets.inStockCount})'
                : filter.label,
          ),
          value: current == true,
          onChanged: (v) => _set(filter.key, v ? true : null),
          contentPadding: EdgeInsets.zero,
        );

      case 'range':
        final map = current is Map ? Map<String, dynamic>.from(current) : <String, dynamic>{};
        final bounds = widget.facets;
        final hint = (filter.key == 'price' && bounds.priceMin != null)
            ? 'Available: ₹${bounds.priceMin} - ₹${bounds.priceMax}'
            : null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hint != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(hint, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: map['min']?.toString() ?? '',
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Min', border: OutlineInputBorder()),
                    onChanged: (v) => _set(filter.key, {...map, 'min': double.tryParse(v)}),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    initialValue: map['max']?.toString() ?? '',
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Max', border: OutlineInputBorder()),
                    onChanged: (v) => _set(filter.key, {...map, 'max': double.tryParse(v)}),
                  ),
                ),
              ],
            ),
          ],
        );

      case 'single-select':
        final facetValues = widget.facets.valuesFor(filter.key);
        final options = facetValues.isNotEmpty
            ? facetValues.map((f) => f.value).toList()
            : filter.options;

        return DropdownButtonFormField<dynamic>(
          initialValue: current,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: [
            const DropdownMenuItem(value: null, child: Text('Any')),
            ...options.map((o) {
              final count = widget.facets.countFor(filter.key, o);
              return DropdownMenuItem(
                value: o,
                child: Text(count != null ? '$o ($count)' : o.toString()),
              );
            }),
          ],
          onChanged: (v) => _set(filter.key, v),
        );

      case 'rating':
        final rating = (current as num?)?.toInt() ?? 0;
        return Row(
          children: List.generate(5, (i) {
            final star = i + 1;
            return IconButton(
              icon: Icon(
                star <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
                color: star <= rating ? Colors.amber : Colors.grey.shade300,
                size: 28,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              visualDensity: VisualDensity.compact,
              onPressed: () => _set(filter.key, star == rating ? null : star),
            );
          }),
        );

      default:
        return const SizedBox.shrink();
    }
  }
}
