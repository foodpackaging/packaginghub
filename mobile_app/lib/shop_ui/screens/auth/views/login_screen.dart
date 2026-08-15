import 'package:b2b_store/shop_ui/route/route_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:b2b_store/shop_ui/constants.dart';
import 'package:b2b_store/core/services/api_client.dart';
import 'package:b2b_store/shared/providers/auth_provider.dart';

import 'components/login_form.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _formData = {};
  bool _isLoading = false;

  void _onLogin() async {
    // Close the keyboard so the error snackbar isn't hidden behind it.
    FocusScope.of(context).unfocus();

    if (_isLoading || !_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => _isLoading = true);

    try {
      await ref.read(userProfileProvider.notifier).login(
            _formData['email'] as String,
            _formData['password'] as String,
          );

      final profile = ref.read(userProfileProvider).value;
      if (mounted) {
        if (profile != null && profile.onboardingComplete) {
          Navigator.pushNamedAndRemoveUntil(
              context, entryPointScreenRoute, (route) => false);
        } else {
          Navigator.pushNamedAndRemoveUntil(
              context, onboardingFormScreenRoute, (route) => false);
        }
      }
    } on ApiException catch (e) {
      _showError(e.statusCode == 401
          ? 'Incorrect email or password. Please try again.'
          : e.message);
    } catch (_) {
      _showError('Something went wrong while signing in. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: errorColor,
        duration: const Duration(seconds: 5),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F4F0),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: defaultPadding * 2),
              Text(
                "Log In",
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Please Log In to continue using our app",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: defaultPadding * 2),
              Image.asset(
                "assets/Illustration/login_illustration.jpg",
                height: size.height * 0.25,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: defaultPadding * 2),
              Padding(
                padding: const EdgeInsets.all(defaultPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    LogInForm(
                      formKey: _formKey,
                      data: _formData,
                      onSubmit: _onLogin,
                    ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      child: const Text("Forgot Password?", style: TextStyle(color: Colors.black54)),
                      onPressed: () {
                        Navigator.pushNamed(
                            context, passwordRecoveryScreenRoute);
                      },
                    ),
                  ),
                  SizedBox(
                    height: size.height > 700
                        ? size.height * 0.05
                        : defaultPadding,
                  ),
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _onLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentRed,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text("Log In", style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                  const SizedBox(height: defaultPadding),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account?", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, signUpScreenRoute);
                        },
                        child: const Text("SignUp", style: TextStyle(color: accentRed, fontWeight: FontWeight.bold)),
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
