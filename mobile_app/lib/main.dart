import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart' as legacy_provider;
import 'shop_ui/components/cart/cart_summary_bar.dart';
import 'shop_ui/controllers/cart_controller.dart';
import 'shop_ui/route/navigator_key.dart';
import 'shop_ui/route/router.dart' as shop_router;
import 'shop_ui/theme/app_theme.dart' as shop_theme;
import 'shared/providers/auth_provider.dart';
import 'shop_ui/screens/auth/views/login_screen.dart';
import 'shop_ui/screens/onbording/views/onboarding_form_screen.dart';
import 'shop_ui/entry_point.dart';
import 'shared/providers/filter_provider.dart';
import 'core/services/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables (API_BASE_URL, RAZORPAY_KEY_ID)
  await dotenv.load(fileName: ".env");

  // Boots Firebase and the notification channel. No-ops (with a log) when the
  // Firebase config files aren't in place yet, so the app still starts.
  await PushNotificationService.instance.initialize();

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return legacy_provider.MultiProvider(
      providers: [
        legacy_provider.ChangeNotifierProvider(create: (_) => CartController()),
        legacy_provider.ChangeNotifierProvider(create: (_) => FilterProvider()),
      ],
      child: MaterialApp(
        title: 'B2B Store',
        debugShowCheckedModeBanner: false,
        theme: shop_theme.AppTheme.lightTheme(context),
        themeMode: ThemeMode.light,
        scrollBehavior: const MaterialScrollBehavior().copyWith(
          physics: const BouncingScrollPhysics(),
        ),
        navigatorKey: shopNavigatorKey,
        onGenerateRoute: shop_router.generateRoute,
        builder: (context, child) {
          return child ?? const SizedBox.shrink();
        },
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);

    return profileAsync.when(
      data: (profile) {
        if (profile == null) {
          return const LoginScreen();
        } else if (!profile.onboardingComplete) {
          return const OnboardingFormScreen();
        }
        return const EntryPoint();
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => const LoginScreen(),
    );
  }
}
