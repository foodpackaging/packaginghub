import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:b2b_store/shop_ui/constants.dart';
import 'package:b2b_store/shop_ui/route/route_constants.dart';
import 'package:b2b_store/shared/providers/auth_provider.dart';
import 'package:b2b_store/shop_ui/components/address/address_form.dart';

/// Onboarding step 2: the business's primary delivery address.
///
/// Completing this marks onboarding done, so the user drops straight into the
/// app on every later login rather than being asked for a location again.
class OnboardingAddressScreen extends ConsumerWidget {
  const OnboardingAddressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Account Setup (2/2)'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Primary Delivery Address',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Where should we deliver your orders? This is your business, warehouse '
              'or shop address — it does not have to be where you are right now.',
              style: TextStyle(color: Colors.grey, height: 1.4),
            ),
            const SizedBox(height: 8),
            const Text(
              'You can add more delivery locations later from your profile.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: defaultPadding * 1.5),
            AddressForm(
              submitLabel: 'Finish & Enter Shop',
              // The first address is the default by definition; no need to ask.
              showDefaultToggle: false,
              onSubmit: (address, _) async {
                await ref.read(userProfileProvider.notifier).completeOnboarding({
                  'address': {
                    ...address.toRequestBody(),
                    'label': address.label.trim().isEmpty ? 'Primary Address' : address.label.trim(),
                  },
                });
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(context, entryPointScreenRoute, (route) => false);
                }
              },
            ),
            const SizedBox(height: defaultPadding),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
