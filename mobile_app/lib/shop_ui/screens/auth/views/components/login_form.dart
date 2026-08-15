import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:b2b_store/shop_ui/constants.dart';

class LogInForm extends StatefulWidget {
  const LogInForm({
    super.key,
    required this.formKey,
    required this.data,
    this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final Map<String, dynamic> data;

  /// Lets the keyboard's "done" action submit the form instead of just dismissing.
  final VoidCallback? onSubmit;

  @override
  State<LogInForm> createState() => _LogInFormState();
}

class _LogInFormState extends State<LogInForm> {
  bool _obscurePassword = true;

  Widget _prefixIcon(String asset) => Padding(
        padding: const EdgeInsets.symmetric(vertical: defaultPadding * 0.75),
        child: SvgPicture.asset(
          asset,
          height: 24,
          width: 24,
          colorFilter: ColorFilter.mode(
            Theme.of(context).textTheme.bodyLarge!.color!.withValues(alpha: 0.3),
            BlendMode.srcIn,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: Column(
        children: [
          TextFormField(
            // Trim so a stray space from autocomplete or a soft keyboard can't fail the login.
            onSaved: (email) => widget.data['email'] = email?.trim(),
            validator: emaildValidator.call,
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            autofillHints: const [AutofillHints.username, AutofillHints.email],
            inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
            decoration: InputDecoration(
              hintText: "Email address",
              prefixIcon: _prefixIcon("assets/icons/Message.svg"),
            ),
          ),
          const SizedBox(height: defaultPadding),
          TextFormField(
            onSaved: (password) => widget.data['password'] = password,
            validator: loginPasswordValidator.call,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onFieldSubmitted: (_) => widget.onSubmit?.call(),
            decoration: InputDecoration(
              hintText: "Password",
              prefixIcon: _prefixIcon("assets/icons/Lock.svg"),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: Theme.of(context).textTheme.bodyLarge!.color!.withValues(alpha: 0.4),
                ),
                tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
