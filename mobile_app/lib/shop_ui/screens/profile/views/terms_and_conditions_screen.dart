import 'package:flutter/material.dart';
import 'package:b2b_store/shop_ui/constants.dart';

class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Terms & Conditions',
          style: TextStyle(color: navyDark, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: navyDark),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        children: const [
          _Section(
            title: '1. Acceptance of Terms',
            body:
                'By accessing or using the B2B Store application ("App"), you agree to be bound by these Terms and Conditions. If you do not agree to these terms, please do not use the App.',
          ),
          _Section(
            title: '2. Use of the App',
            body:
                'The App is intended for registered business customers only. You agree to use the App solely for lawful purposes and in accordance with these Terms. You are responsible for maintaining the confidentiality of your account credentials.',
          ),
          _Section(
            title: '3. Orders and Payments',
            body:
                'All orders placed through the App are subject to availability and acceptance. Prices are subject to change without notice. Payments must be completed as specified at checkout. We reserve the right to cancel any order at our discretion.',
          ),
          _Section(
            title: '4. Delivery',
            body:
                'Estimated delivery times are provided as a guide only and are not guaranteed. We are not responsible for delays caused by circumstances beyond our control. Delivery charges may apply depending on your order value and location.',
          ),
          _Section(
            title: '5. Returns & Refunds',
            body:
                'Returns must be requested within 7 days of order completion. Refunds are calculated based on the discounted price of the returned item(s). Delivery charges are non-refundable for partial returns. All returns are subject to verification and approval by our team.',
          ),
          _Section(
            title: '6. Product Information',
            body:
                'We strive to ensure that all product descriptions and prices on the App are accurate. However, errors may occur. In the event of a pricing error, we reserve the right to cancel orders placed at the incorrect price.',
          ),
          _Section(
            title: '7. Intellectual Property',
            body:
                'All content, trademarks, and intellectual property on the App are owned by or licensed to us. You may not reproduce, distribute, or create derivative works without our prior written consent.',
          ),
          _Section(
            title: '8. Privacy',
            body:
                'Your use of the App is also governed by our Privacy Policy. We collect and process personal data in accordance with applicable data protection laws. By using the App, you consent to such processing.',
          ),
          _Section(
            title: '9. Limitation of Liability',
            body:
                'To the fullest extent permitted by law, we shall not be liable for any indirect, incidental, or consequential damages arising out of your use of the App. Our total liability shall not exceed the amount paid for the relevant order.',
          ),
          _Section(
            title: '10. Changes to Terms',
            body:
                'We reserve the right to update these Terms and Conditions at any time. Continued use of the App after changes are posted constitutes your acceptance of the revised terms.',
          ),
          _Section(
            title: '11. Governing Law',
            body:
                'These Terms and Conditions are governed by and construed in accordance with the laws of India. Any disputes arising under these terms shall be subject to the exclusive jurisdiction of the courts of India.',
          ),
          _Section(
            title: '12. Contact Us',
            body:
                'If you have any questions about these Terms and Conditions, please contact our support team through the App or at support@b2bstore.in.',
          ),
          SizedBox(height: 32),
          Center(
            child: Text(
              'Last updated: June 2025',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: navyDark,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F8F8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              body,
              style: const TextStyle(
                color: Color(0xFF555555),
                fontSize: 13.5,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
