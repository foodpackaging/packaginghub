import 'package:flutter/material.dart';
import 'package:b2b_store/shop_ui/constants.dart';
import 'package:b2b_store/shop_ui/route/route_constants.dart';

class EmailConfirmationSuccessScreen extends StatelessWidget {
  const EmailConfirmationSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(defaultPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryColor.withOpacity(0.1),
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: primaryColor,
                  size: 100,
                ),
              ),
              const SizedBox(height: defaultPadding * 2),
              Text(
                "Email Confirmed!",
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: defaultPadding),
              const Text(
                "Your email has been successfully verified. You can now complete your profile setup.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // This pushes the user straight to their onboarding process
                    Navigator.pushNamedAndRemoveUntil(context, onboardingFormScreenRoute, (route) => false);
                  },
                  child: const Text("Continue to Setup Profile"),
                ),
              ),
              const SizedBox(height: defaultPadding),
            ],
          ),
        ),
      ),
    );
  }
}
