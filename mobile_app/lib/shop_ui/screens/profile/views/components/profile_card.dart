import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:b2b_store/shop_ui/constants.dart';

class ProfileCard extends StatelessWidget {
  const ProfileCard({
    super.key,
    required this.name,
    required this.email,
    required this.imageSrc,
    this.proLableText = "Pro",
    this.isPro = false,
    this.press,
    this.isShowHi = true,
    this.isShowArrow = true,
  });

  final String name, email, imageSrc;
  final String proLableText;
  final bool isPro, isShowHi, isShowArrow;
  final VoidCallback? press;

  @override
  Widget build(BuildContext context) {
    // Determine if we should show a placeholder icon/initials
    final bool usePlaceholder = imageSrc.isEmpty || imageSrc.contains("imgur.com");
    final String initials = name.isNotEmpty ? name[0].toUpperCase() : "U";

    return ListTile(
      onTap: press,
      leading: CircleAvatar(
        radius: 28,
        backgroundColor: primaryColor.withValues(alpha: 0.1),
        child: usePlaceholder
            ? Text(
                initials,
                style: const TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              )
            : ClipOval(
                child: Image.network(
                  imageSrc,
                  fit: BoxFit.cover,
                  width: 56,
                  height: 56,
                  errorBuilder: (context, error, stackTrace) => Text(initials),
                ),
              ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              isShowHi ? "Hi, $name" : name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isPro) ...[
            const SizedBox(width: defaultPadding / 2),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: defaultPadding / 2, vertical: defaultPadding / 4),
              decoration: const BoxDecoration(
                color: primaryColor,
                borderRadius:
                    BorderRadius.all(Radius.circular(defaultBorderRadious)),
              ),
              child: Text(
                proLableText,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.7,
                  height: 1,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        email,
        style: const TextStyle(color: Colors.grey, fontSize: 13),
      ),
      trailing: isShowArrow
          ? SvgPicture.asset(
              "assets/icons/miniRight.svg",
              colorFilter: ColorFilter.mode(
                  Theme.of(context).iconTheme.color!.withValues(alpha: 0.4),
                  BlendMode.srcIn),
            )
          : null,
    );
  }
}
