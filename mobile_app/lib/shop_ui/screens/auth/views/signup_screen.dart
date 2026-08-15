import 'package:b2b_store/shop_ui/route/route_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:b2b_store/shop_ui/screens/auth/views/components/sign_up_form.dart';
import 'package:b2b_store/shop_ui/constants.dart';
import 'package:b2b_store/shared/providers/auth_provider.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _formData = {};
  bool _isLoading = false;

  void _onSignUp() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() => _isLoading = true);

      try {
        await ref.read(userProfileProvider.notifier).signUp(
              _formData['email'] as String,
              _formData['password'] as String,
            );

        if (mounted) {
          // New signups always need onboarding.
          Navigator.pushNamedAndRemoveUntil(
              context, onboardingFormScreenRoute, (route) => false);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Registration failed: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F4F0),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: defaultPadding * 2),
              Text(
                "Sign up",
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Please Registration with email and sign up to continue\nusing our app",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: defaultPadding * 2),
              Image.asset(
                "assets/Illustration/login_illustration.jpg",
                height: MediaQuery.of(context).size.height * 0.20,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: defaultPadding * 2),
              Padding(
                padding: const EdgeInsets.all(defaultPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SignUpForm(
                      formKey: _formKey,
                      data: _formData,
                    ),
                    const SizedBox(height: defaultPadding * 2),
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _onSignUp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentRed,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text("Sign up", style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                  const SizedBox(height: defaultPadding),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("You already have an account?", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, logInScreenRoute);
                        },
                        child: const Text("Login", style: TextStyle(color: accentRed, fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                ],
              ),
            )
          ],
        ),
      ),
      ),
    );
  }
}
