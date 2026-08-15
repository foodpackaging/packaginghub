import 'package:flutter/material.dart';
import 'package:b2b_store/shop_ui/constants.dart';
import 'package:b2b_store/shop_ui/route/route_constants.dart';
import 'package:b2b_store/shop_ui/services/cms_service.dart';

class DynamicCategoriesSliver extends StatefulWidget {
  const DynamicCategoriesSliver({super.key});

  @override
  State<DynamicCategoriesSliver> createState() => _DynamicCategoriesSliverState();
}

class _DynamicCategoriesSliverState extends State<DynamicCategoriesSliver> {
  final CmsService _cmsService = CmsService();
  late Future<List<Map<String, dynamic>>> _categoriesFuture;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = _cmsService.getCategories();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _categoriesFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          // Show a placeholder while loading
          return const SliverToBoxAdapter(
            child: Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
          );
        }

        final categories = snapshot.data!;
        
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
                final cat = categories[index];
                return _CategoryCard(
                  name: cat['name'] ?? "",
                  image: cat['icon_url'] ?? "https://i.imgur.com/K41Mj7C.png",
                  onTap: () {
                    Navigator.pushNamed(context, discoverScreenRoute, arguments: cat);
                  },
                );
              },
              childCount: categories.length,
            ),
          ),
        );
      },
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.name, required this.image, required this.onTap});
  final String name;
  final String image;
  final VoidCallback onTap;

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
                color: const Color(0xFFF1F4F7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Image.network(
                image,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.category_outlined, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: navyDark),
          ),
        ],
      ),
    );
  }
}
