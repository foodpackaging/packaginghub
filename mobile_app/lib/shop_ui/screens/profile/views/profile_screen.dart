import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:b2b_store/shop_ui/route/route_constants.dart';
import 'package:b2b_store/shop_ui/constants.dart';
import 'package:b2b_store/shared/providers/auth_provider.dart';

import 'components/profile_card.dart';
import 'components/profile_menu_item_list_tile.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Profile"),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) return const Center(child: Text("No profile found"));
          
          return ListView(
            children: [
              ProfileCard(
                name: profile.firstName ?? "User",
                email: profile.email,
                imageSrc: "", 
                press: () {
                  Navigator.pushNamed(context, userInfoScreenRoute);
                },
              ),
              const SizedBox(height: defaultPadding),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: defaultPadding),
                child: Text(
                  "Account Settings",
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: defaultPadding / 2),
              
              ProfileMenuListTile(
                text: "Business Addresses",
                svgSrc: "assets/icons/Address.svg",
                press: () {
                  Navigator.pushNamed(context, addressesScreenRoute);
                },
              ),

              ProfileMenuListTile(
                text: "My Orders",
                svgSrc: "assets/icons/Order.svg",
                press: () {
                  Navigator.pushNamed(context, ordersScreenRoute);
                },
              ),

              ProfileMenuListTile(
                text: "Returns & Refunds",
                svgSrc: "assets/icons/Order.svg",
                press: () {
                  Navigator.pushNamed(context, myReturnsScreenRoute);
                },
              ),

              ProfileMenuListTile(
                text: "Terms & Conditions",
                svgSrc: "assets/icons/info.svg",
                press: () {
                  Navigator.pushNamed(context, termsAndConditionsScreenRoute);
                },
                isShowDivider: false,
              ),
              
              const SizedBox(height: defaultPadding),

              // Log Out
              Padding(
                padding: const EdgeInsets.only(top: defaultPadding),
                child: ListTile(
                  onTap: () async {
                    await ref.read(userProfileProvider.notifier).logout();
                  },
                  minLeadingWidth: 24,
                  leading: SvgPicture.asset(
                    "assets/icons/Logout.svg",
                    height: 24,
                    width: 24,
                    colorFilter: const ColorFilter.mode(
                      errorColor,
                      BlendMode.srcIn,
                    ),
                  ),
                  title: const Text(
                    "Log Out",
                    style: TextStyle(color: errorColor, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              )
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text("Error: $e")),
      ),
    );
  }
}
