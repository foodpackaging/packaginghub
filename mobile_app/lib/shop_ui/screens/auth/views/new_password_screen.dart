import 'package:flutter/material.dart';
import 'package:b2b_store/shop_ui/constants.dart';
import 'package:b2b_store/core/services/api_client.dart';
import 'package:b2b_store/shop_ui/services/auth_service.dart';
import 'package:b2b_store/shop_ui/route/route_constants.dart';

/// Carries the already-verified code through to the new-password step.
class PasswordResetHandoff {
  const PasswordResetHandoff({required this.email, required this.code});
  final String email;
  final String code;
}

/// Step 2 of the reset flow. Only reachable once the code has been verified.
class NewPasswordScreen extends StatefulWidget {
  const NewPasswordScreen({super.key});

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    // Repaint the checklist on every keystroke.
    _passwordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit(PasswordResetHandoff handoff) async {
    FocusScope.of(context).unfocus();
    if (_isLoading || !_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await _authService.resetPassword(
        email: handoff.email,
        code: handoff.code,
        newPassword: _passwordController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Password updated. Please log in with your new password.'),
        ));
      Navigator.pushNamedAndRemoveUntil(context, logInScreenRoute, (route) => false);
    } on ApiException catch (e) {
      _showError(e.message);
      // The code was consumed or invalidated server-side; send them back to re-request one.
      if (e.statusCode == 400 || e.statusCode == 429) {
        if (mounted) Navigator.pop(context);
      }
    } catch (_) {
      _showError("We couldn't update your password. Please try again.");
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

  Widget _ruleRow(PasswordRule rule, bool isEmpty) {
    final met = rule.isSatisfiedBy(_passwordController.text);
    final Color color;
    if (isEmpty) {
      color = Theme.of(context).textTheme.bodySmall!.color!.withValues(alpha: 0.6);
    } else {
      color = met ? successColor : errorColor;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(rule.label, style: TextStyle(fontSize: 13, color: color)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final handoff = ModalRoute.of(context)?.settings.arguments as PasswordResetHandoff?;

    // Should be unreachable via the normal flow, but never render the form without a code.
    if (handoff == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Set New Password")),
        body: Padding(
          padding: const EdgeInsets.all(defaultPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "This page needs a verified reset code. Please start the reset again.",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: defaultPadding),
              ElevatedButton(
                onPressed: () => Navigator.pushNamedAndRemoveUntil(
                    context, passwordRecoveryScreenRoute, (route) => false),
                child: const Text("Back to password reset"),
              ),
            ],
          ),
        ),
      );
    }

    final isEmpty = _passwordController.text.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text("Set New Password")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(defaultPadding),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.verified_user_outlined, color: successColor, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(child: Text("Code verified")),
                ],
              ),
              const SizedBox(height: defaultPadding),
              Text(
                "Choose a new password",
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: defaultPadding / 2),
              Text("Setting a new password for ${handoff.email}."),
              const SizedBox(height: defaultPadding * 1.5),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: "New Password",
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                obscureText: _obscurePassword,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
                validator: passwordValidator.call,
              ),
              const SizedBox(height: defaultPadding),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(defaultPadding * 0.75),
                decoration: BoxDecoration(
                  color: Theme.of(context).textTheme.bodyLarge!.color!.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(defaultBorderRadious),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Your password must have:",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).textTheme.bodyLarge!.color,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...passwordRules.map((rule) => _ruleRow(rule, isEmpty)),
                  ],
                ),
              ),
              const SizedBox(height: defaultPadding),
              TextFormField(
                controller: _confirmController,
                decoration: InputDecoration(
                  labelText: "Confirm New Password",
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    tooltip: _obscureConfirm ? 'Show password' : 'Hide password',
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                obscureText: _obscureConfirm,
                textInputAction: TextInputAction.done,
                validator: (value) =>
                    value == _passwordController.text ? null : 'Passwords do not match',
                onFieldSubmitted: (_) => _submit(handoff),
              ),
              const SizedBox(height: defaultPadding * 2),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : () => _submit(handoff),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text("Update Password"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
