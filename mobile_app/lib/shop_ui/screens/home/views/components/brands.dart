import 'package:flutter/material.dart';
import 'package:b2b_store/shop_ui/constants.dart';
import 'package:b2b_store/shop_ui/route/route_constants.dart';
import 'package:b2b_store/shop_ui/services/cms_service.dart';

class DynamicBrandsSliver extends StatefulWidget {
  const DynamicBrandsSliver({super.key});

  @override
  State<DynamicBrandsSliver> createState() => _DynamicBrandsSliverState();
}

class _DynamicBrandsSliverState extends State<DynamicBrandsSliver> {
  final CmsService _cmsService = CmsService();
  late Future<List<String>> _brandsFuture;

  @override
  void initState() {
    super.initState();
    _brandsFuture = _cmsService.getBrands();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: _brandsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        final brands = snapshot.data!;
        if (brands.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: defaultPadding),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 16,
              crossAxisSpacing: 12,
              childAspectRatio: 0.75,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final brand = brands[index];
                return _BrandCard(
                  name: brand,
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      brandScreenRoute,
                      arguments: {'brand': brand},
                    );
                  },
                );
              },
              childCount: brands.length,
            ),
          ),
        );
      },
    );
  }
}

class _BrandCard extends StatelessWidget {
  const _BrandCard({required this.name, required this.onTap});
  final String name;
  final VoidCallback onTap;

  // Generate a consistent colour from the brand name
  Color _brandColor(String name) {
    const palette = [
      Color(0xFFE3F2FD),
      Color(0xFFFCE4EC),
      Color(0xFFE8F5E9),
      Color(0xFFFFF8E1),
      Color(0xFFEDE7F6),
      Color(0xFFE0F7FA),
      Color(0xFFFBE9E7),
      Color(0xFFF3E5F5),
    ];
    return palette[name.codeUnitAt(0) % palette.length];
  }

  Color _textColor(String name) {
    const palette = [
      Color(0xFF1565C0),
      Color(0xFFC62828),
      Color(0xFF2E7D32),
      Color(0xFFF57F17),
      Color(0xFF4527A0),
      Color(0xFF00695C),
      Color(0xFFBF360C),
      Color(0xFF6A1B9A),
    ];
    return palette[name.codeUnitAt(0) % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _brandColor(name),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  name.substring(0, name.length > 2 ? 2 : name.length).toUpperCase(),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: _textColor(name),
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: navyDark,
            ),
          ),
        ],
      ),
    );
  }
}
