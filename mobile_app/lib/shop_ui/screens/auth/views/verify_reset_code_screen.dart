import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:b2b_store/shop_ui/constants.dart';
import 'package:b2b_store/core/services/api_client.dart';
import 'package:b2b_store/shop_ui/services/auth_service.dart';
import 'package:b2b_store/shop_ui/route/route_constants.dart';
import 'package:b2b_store/shop_ui/screens/auth/views/new_password_screen.dart';

/// Reset codes are stored uppercase server-side, so normalise as the user types.
class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

/// Step 1 of the reset flow. The new-password fields only appear once the code
/// here has been confirmed by the server.
class VerifyResetCodeScreen extends StatefulWidget {
  const VerifyResetCodeScreen({super.key});

  @override
  State<VerifyResetCodeScreen> createState() => _VerifyResetCodeScreenState();
}

class _VerifyResetCodeScreenState extends State<VerifyResetCodeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();

  final AuthService _authService = AuthService();

  bool _isVerifying = false;
  bool _isResending = false;
  bool _argumentsRead = false;

  // The backend enforces a 60s gap between sends; mirror it so the button reflects reality.
  static const _resendCooldown = Duration(seconds: 60);
  Timer? _cooldownTimer;
  int _secondsUntilResend = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argumentsRead) return;
    _argumentsRead = true;
    final email = ModalRoute.of(context)?.settings.arguments as String? ?? '';
    _emailController.text = email;
    if (email.isNotEmpty) _startCooldown();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    // Set directly rather than via setState: this also runs from didChangeDependencies,
    // and the timer's first tick repaints the countdown a moment later regardless.
    _secondsUntilResend = _resendCooldown.inSeconds;
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _secondsUntilResend -= 1);
      if (_secondsUntilResend <= 0) timer.cancel();
    });
  }

  Future<void> _verifyCode() async {
    FocusScope.of(context).unfocus();
    if (_isVerifying || !_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    setState(() => _isVerifying = true);

    try {
      await _authService.verifyResetCode(email: email, code: code);
      if (!mounted) return;
      // Code confirmed — only now do we let them choose a new password.
      Navigator.pushNamed(
        context,
        newPasswordScreenRoute,
        arguments: PasswordResetHandoff(email: email, code: code),
      );
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError("We couldn't check that code. Please try again.");
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _resendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showError('Enter your email address first.');
      return;
    }

    setState(() => _isResending = true);
    try {
      await _authService.sendPasswordResetEmail(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('A new code is on its way.')));
      _codeController.clear();
      _startCooldown();
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError("We couldn't resend the code. Please try again.");
    } finally {
      if (mounted) setState(() => _isResending = false);
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
    final canResend = !_isResending && !_isVerifying && _secondsUntilResend <= 0;

    return Scaffold(
      appBar: AppBar(title: const Text("Enter Reset Code")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(defaultPadding),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Check your email",
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: defaultPadding / 2),
              const Text(
                "We sent you a 6-character code made up of letters and numbers. "
                "Enter it below to continue.",
              ),
              const SizedBox(height: defaultPadding * 1.5),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: "Email address",
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
                validator: emaildValidator.call,
              ),
              const SizedBox(height: defaultPadding),
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: "Reset Code",
                  prefixIcon: Icon(Icons.pin_outlined),
                  hintText: "e.g. 7KP2QM",
                ),
                // Letters as well as digits, so a plain text keyboard rather than a numeric one.
                keyboardType: TextInputType.text,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                textInputAction: TextInputAction.done,
                style: const TextStyle(letterSpacing: 6, fontWeight: FontWeight.bold),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                  LengthLimitingTextInputFormatter(6),
                  _UpperCaseTextFormatter(),
                ],
                validator: resetCodeValidator.call,
                onFieldSubmitted: (_) => _verifyCode(),
              ),
              const SizedBox(height: defaultPadding / 2),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: canResend ? _resendCode : null,
                  child: Text(
                    _isResending
                        ? 'Sending...'
                        : _secondsUntilResend > 0
                            ? 'Resend code in ${_secondsUntilResend}s'
                            : 'Resend code',
                  ),
                ),
              ),
              const SizedBox(height: defaultPadding),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isVerifying ? null : _verifyCode,
                  child: _isVerifying
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text("Verify Code"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
