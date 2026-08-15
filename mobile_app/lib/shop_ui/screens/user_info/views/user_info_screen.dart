import 'package:flutter/material.dart';
import 'package:b2b_store/shared/providers/auth_provider.dart';
import 'package:b2b_store/shop_ui/constants.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserInfoScreen extends ConsumerWidget {
  const UserInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile Information"),
      ),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) return const Center(child: Text("Profile not found"));

          return ListView(
            padding: const EdgeInsets.all(defaultPadding),
            children: [
              const Center(
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: primaryColor,
                  child: Icon(Icons.person, size: 50, color: Colors.white),
                ),
              ),
              const SizedBox(height: 24),
              _buildInfoTile(context, "First Name", profile.firstName ?? "Not provided"),
              _buildInfoTile(context, "Last Name", profile.lastName ?? "Not provided"),
              _buildInfoTile(context, "Login Email", profile.email),
              _buildInfoTile(context, "Work Email", profile.workEmail ?? "Not provided"),
              _buildInfoTile(context, "Phone", profile.phone ?? "Not provided"),
              _buildInfoTile(context, "Company Type", profile.companyType ?? "Not provided"),
              _buildInfoTile(context, "Role", profile.role ?? "Not provided"),
              if (profile.role == 'Other')
                _buildInfoTile(context, "Role Description", profile.roleDescription ?? "Not provided"),
              _buildInfoTile(context, "GST Number", profile.gstNumber ?? "Not provided"),
              _buildInfoTile(context, "Address", profile.address ?? "Not provided"),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  // TODO: Implement Edit Profile
                },
                child: const Text("Edit Profile"),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Error: $err")),
      ),
    );
  }

  Widget _buildInfoTile(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const Divider(),
        ],
      ),
    );
  }
}
