import 'package:b2b_store/shop_ui/constants.dart';
import 'package:flutter/material.dart';

class CategorySidebarItem {
  final String name;
  final String image;

  CategorySidebarItem({required this.name, required this.image});
}

List<CategorySidebarItem> sidebarCategories = [
  CategorySidebarItem(name: "All", image: "https://i.imgur.com/K41Mj7C.png"),
  CategorySidebarItem(name: "Cutlery & Tissues", image: "https://i.imgur.com/K41Mj7C.png"),
  CategorySidebarItem(name: "Reusable Round Containers", image: "https://i.imgur.com/K41Mj7C.png"),
  CategorySidebarItem(name: "Reusable Rectangular Containers", image: "https://i.imgur.com/K41Mj7C.png"),
  CategorySidebarItem(name: "Meal Trays", image: "https://i.imgur.com/K41Mj7C.png"),
  CategorySidebarItem(name: "Carry Bags", image: "https://i.imgur.com/K41Mj7C.png"),
];

class CategorySidebar extends StatelessWidget {
  const CategorySidebar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      color: Colors.white,
      // Using SingleChildScrollView + Column instead of ListView for better stability 
      // on Windows during first-frame hit testing.
      child: SingleChildScrollView(
        child: Column(
          children: List.generate(sidebarCategories.length, (index) {
            final isSelected = selectedIndex == index;
            return GestureDetector(
              onTap: () => onTap(index),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: isSelected ? accentRed : Colors.transparent,
                      width: 4,
                    ),
                  ),
                  color: isSelected ? Colors.grey.withOpacity(0.05) : Colors.transparent,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: categoryBg.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Image.network(
                        sidebarCategories[index].image,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.category_outlined, color: mutedText, size: 20),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      sidebarCategories[index].name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9,
                        height: 1.2,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? navyDark : mutedText,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
