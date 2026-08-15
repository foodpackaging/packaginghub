import 'dart:async';

import 'package:b2b_store/shop_ui/constants.dart';
import 'package:b2b_store/shop_ui/route/route_constants.dart';
import 'package:flutter/material.dart';

class ThanksForOrderScreen extends StatefulWidget {
  const ThanksForOrderScreen({super.key, this.orderId});

  final String? orderId;

  @override
  State<ThanksForOrderScreen> createState() => _ThanksForOrderScreenState();
}

class _ThanksForOrderScreenState extends State<ThanksForOrderScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
    _scale = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _controller.forward();

    Timer(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      if (widget.orderId != null && widget.orderId!.isNotEmpty) {
        Navigator.pushNamedAndRemoveUntil(context, entryPointScreenRoute, (route) => false);
        Navigator.pushNamed(context, ordersScreenRoute);
        Navigator.pushNamed(context, orderDetailsScreenRoute, arguments: widget.orderId);
      } else {
        Navigator.pushNamedAndRemoveUntil(context, entryPointScreenRoute, (route) => false);
        Navigator.pushNamed(context, ordersScreenRoute);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(defaultPadding * 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: _scale,
                child: Container(
                  height: 96,
                  width: 96,
                  decoration: const BoxDecoration(color: successColor, shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 56),
                ),
              ),
              const SizedBox(height: defaultPadding * 1.5),
              const Text(
                'Order placed',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: navyDark),
              ),
              const SizedBox(height: 8),
              const Text(
                'Taking you to your order details...',
                textAlign: TextAlign.center,
                style: TextStyle(color: mutedText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
