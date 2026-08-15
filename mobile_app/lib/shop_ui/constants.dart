import 'package:flutter/material.dart';
import 'package:form_field_validator/form_field_validator.dart';

// Just for demo
const productDemoImg1 = "https://i.imgur.com/CGCyp1d.png";
const productDemoImg2 = "https://i.imgur.com/AkzWQuJ.png";
const productDemoImg3 = "https://i.imgur.com/J7mGZ12.png";
const productDemoImg4 = "https://i.imgur.com/q9oF9Yq.png";
const productDemoImg5 = "https://i.imgur.com/MsppAcx.png";
const productDemoImg6 = "https://i.imgur.com/JfyZlnO.png";

// End For demo

const grandisExtendedFont = "Plus Jakarta";

// On color 80, 60.... those means opacity

const Color primaryColor = Color(0xFFE31E24); // accentRed

const MaterialColor primaryMaterialColor =
    MaterialColor(0xFFE31E24, <int, Color>{
  50: Color(0xFFFBE4E5),
  100: Color(0xFFF5BDBD),
  200: Color(0xFFEE9292),
  300: Color(0xFFE76666),
  400: Color(0xFFE14646),
  500: Color(0xFFE31E24),
  600: Color(0xFFCB1A20),
  700: Color(0xFFB1171C),
  800: Color(0xFF981318),
  900: Color(0xFF6A0D10),
});

const Color blackColor = Color(0xFF16161E);
const Color blackColor80 = Color(0xFF45454B);
const Color blackColor60 = Color(0xFF737378);
const Color blackColor40 = Color(0xFFA2A2A5);
const Color blackColor20 = Color(0xFFD0D0D2);
const Color blackColor10 = Color(0xFFE8E8E9);
const Color blackColor5 = Color(0xFFF3F3F4);

const Color whiteColor = Colors.white;
const Color whileColor80 = Color(0xFFCCCCCC);
const Color whileColor60 = Color(0xFF999999);
const Color whileColor40 = Color(0xFF666666);
const Color whileColor20 = Color(0xFF333333);
const Color whileColor10 = Color(0xFF191919);
const Color whileColor5 = Color(0xFF0D0D0D);

const Color greyColor = Color(0xFFB8B5C3);
const Color lightGreyColor = Color(0xFFF8F8F9);
const Color darkGreyColor = Color(0xFF1C1C25);
// const Color greyColor80 = Color(0xFFC6C4CF);
// const Color greyColor60 = Color(0xFFD4D3DB);
// const Color greyColor40 = Color(0xFFE3E1E7);
// const Color greyColor20 = Color(0xFFF1F0F3);
// const Color greyColor10 = Color(0xFFF8F8F9);
// const Color greyColor5 = Color(0xFFFBFBFC);

const Color purpleColor = Color(0xFFE31E24);
const Color successColor = Color(0xFF2ED573);
const Color warningColor = Color(0xFFFFBE21);
const Color errorColor = Color(0xFFEA5B5B);

// B2B Redesign Colors
const Color accentRed = Color(0xFFE31E24);
const Color navyDark = Color(0xFF1A1D1E);
const Color categoryBg = Color(0xFFE8F1F2);
const Color alertBlue = Color(0xFF0056D2);
const Color mutedText = Color(0xFF707070);
const Color discountBlue = Color(0xFFE3F2FD);

const double defaultPadding = 16.0;
const double defaultBorderRadious = 12.0;
const Duration defaultDuration = Duration(milliseconds: 300);

final passwordValidator = MultiValidator([
  RequiredValidator(errorText: 'Password is required'),
  MinLengthValidator(8, errorText: 'Password must be at least 8 characters long'),
  PatternValidator(r'(?=.*?[A-Z])', errorText: 'Password must have at least one uppercase letter'),
  PatternValidator(r'(?=.*?[a-z])', errorText: 'Password must have at least one lowercase letter'),
  PatternValidator(r'(?=.*?[0-9])', errorText: 'Password must have at least one number'),
  PatternValidator(r'(?=.*?[#?!@$%^&*-])',
      errorText: 'Password must have at least one special character')
]);

// Sign-in must only check that something was typed. Running the strength rules here
// locks out anyone whose existing password predates them, so it belongs on sign-up only.
final loginPasswordValidator = RequiredValidator(errorText: 'Password is required');

class PasswordRule {
  const PasswordRule(this.label, this.isSatisfiedBy);
  final String label;
  final bool Function(String password) isSatisfiedBy;
}

// Mirrors [passwordValidator] exactly. Keep the two in sync — a checklist that
// ticks green while the validator still rejects the field is worse than no checklist.
final passwordRules = <PasswordRule>[
  PasswordRule('At least 8 characters', (v) => v.length >= 8),
  PasswordRule('One uppercase letter (A-Z)', (v) => RegExp(r'[A-Z]').hasMatch(v)),
  PasswordRule('One lowercase letter (a-z)', (v) => RegExp(r'[a-z]').hasMatch(v)),
  PasswordRule('One number (0-9)', (v) => RegExp(r'[0-9]').hasMatch(v)),
  PasswordRule(r'One special character (# ? ! @ $ % ^ & * -)',
      (v) => RegExp(r'[#?!@$%^&*-]').hasMatch(v)),
];

final emaildValidator = MultiValidator([
  RequiredValidator(errorText: 'Email is required'),
  EmailValidator(errorText: "Enter a valid email address"),
]);

// Reset codes are 6 characters mixing letters and numbers, entered case-insensitively.
final resetCodeValidator = MultiValidator([
  RequiredValidator(errorText: 'Enter the code from your email'),
  PatternValidator(r'^[A-Za-z0-9]{6}$', errorText: 'The code is 6 letters and numbers'),
]);

final commonValidator = RequiredValidator(errorText: 'This field is required');

final phoneValidator = MultiValidator([
  RequiredValidator(errorText: 'Phone number is required'),
  MinLengthValidator(10, errorText: 'Enter a valid phone number'),
  MaxLengthValidator(10, errorText: 'Enter a valid phone number'),
  PatternValidator(r'^[0-9]*$', errorText: 'Only digits allowed'),
]);

final gstValidator = MultiValidator([
  RequiredValidator(errorText: 'GST number is required'),
  PatternValidator(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$',
      errorText: 'Enter a valid GST number'),
]);

const pasNotMatchErrorText = "passwords do not match";













