import 'package:b2b_store/shop_ui/route/route_constants.dart';
import 'package:b2b_store/shop_ui/constants.dart';
import 'package:flutter/material.dart';
import 'package:b2b_store/shop_ui/entry_point.dart';

import 'screen_export.dart';
import 'package:b2b_store/shop_ui/screens/product/views/product_list_screen.dart';
import 'package:b2b_store/shop_ui/screens/onbording/views/onboarding_form_screen.dart';
import 'package:b2b_store/shop_ui/screens/auth/views/verify_reset_code_screen.dart';
import 'package:b2b_store/shop_ui/screens/auth/views/new_password_screen.dart';
import 'package:b2b_store/shop_ui/screens/auth/views/email_confirmation_success_screen.dart';
import 'package:b2b_store/shop_ui/screens/checkout/views/map_location_picker_screen.dart';
import 'package:b2b_store/shop_ui/screens/checkout/views/address_details_screen.dart';

Route<dynamic> generateRoute(RouteSettings settings) {
  switch (settings.name) {
    case onbordingScreenRoute:
      return MaterialPageRoute(
        builder: (context) => const OnBordingScreen(),
      );
    case logInScreenRoute:
      return MaterialPageRoute(
        builder: (context) => const LoginScreen(),
      );
    case signUpScreenRoute:
      return MaterialPageRoute(
        builder: (context) => const SignUpScreen(),
      );
    case passwordRecoveryScreenRoute:
      return MaterialPageRoute(
        builder: (context) => const PasswordRecoveryScreen(),
      );
    case verifyResetCodeScreenRoute:
      return MaterialPageRoute(
        // Carries the email forward from the recovery screen.
        settings: settings,
        builder: (context) => const VerifyResetCodeScreen(),
      );
    case newPasswordScreenRoute:
      return MaterialPageRoute(
        // Carries the verified email + code forward.
        settings: settings,
        builder: (context) => const NewPasswordScreen(),
      );
    case emailConfirmationSuccessScreenRoute:
      return MaterialPageRoute(
        builder: (context) => const EmailConfirmationSuccessScreen(),
      );
    case productDetailsScreenRoute:
      return MaterialPageRoute(
        settings: settings,
        builder: (context) => const ProductDetailsScreen(),
      );
    case productReviewsScreenRoute:
      return MaterialPageRoute(
        builder: (context) => const ProductReviewsScreen(),
      );
    case homeScreenRoute:
      return MaterialPageRoute(
        builder: (context) => const HomeScreen(),
      );
    case brandScreenRoute:
      final args = settings.arguments as Map<String, dynamic>?;
      final brandName = args?['brand'] as String? ?? 'Brand';
      return MaterialPageRoute(
        builder: (context) => ProductListScreen(
          title: brandName,
          brandFilter: brandName,
        ),
      );
    case discoverScreenRoute:
      return PageRouteBuilder(
        settings: settings,
        pageBuilder: (context, animation, secondaryAnimation) => const DiscoverScreen(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      );
    case onSaleScreenRoute:
      return MaterialPageRoute(
        builder: (context) => const OnSaleScreen(),
      );
    case kidsScreenRoute:
      return MaterialPageRoute(
        builder: (context) => const KidsScreen(),
      );
    case searchScreenRoute:
      return MaterialPageRoute(
        builder: (context) => const SearchScreen(),
      );
    case bookmarkScreenRoute:
      return MaterialPageRoute(
        builder: (context) => const BookmarkScreen(),
      );
    case entryPointScreenRoute:
      return MaterialPageRoute(
        builder: (context) => const EntryPoint(),
      );
    case profileScreenRoute:
      return MaterialPageRoute(
        builder: (context) => const ProfileScreen(),
      );
    case userInfoScreenRoute:
      return MaterialPageRoute(
        builder: (context) => const UserInfoScreen(),
      );
    case notificationsScreenRoute:
      return MaterialPageRoute(
        builder: (context) => const NotificationsScreen(),
      );
    case noNotificationScreenRoute:
      return MaterialPageRoute(
        builder: (context) => const NoNotificationScreen(),
      );
    case enableNotificationScreenRoute:
      return MaterialPageRoute(
        builder: (context) => const EnableNotificationScreen(),
      );
    case notificationOptionsScreenRoute:
      return MaterialPageRoute(
        builder: (context) => const NotificationOptionsScreen(),
      );
    case addressesScreenRoute:
      return MaterialPageRoute(
        builder: (context) => const AddressesScreen(),
      );
    case ordersScreenRoute:
      return MaterialPageRoute(
        builder: (context) => const OrdersScreen(),
      );
    case myReturnsScreenRoute:
      return MaterialPageRoute(
        builder: (context) => const MyReturnsScreen(),
      );
    case returnDetailsScreenRoute:
      final returnId = settings.arguments as String?;
      return MaterialPageRoute(
        builder: (context) => ReturnDetailsScreen(returnId: returnId ?? ''),
      );
    case orderDetailsScreenRoute:
      final orderId = settings.arguments as String?;
      return MaterialPageRoute(
        builder: (context) => OrderDetailsScreen(orderId: orderId ?? ''),
      );
    case preferencesScreenRoute:
      return MaterialPageRoute(
        builder: (context) => const PreferencesScreen(),
      );
    case emptyWalletScreenRoute:
      return MaterialPageRoute(
        builder: (context) => const EmptyWalletScreen(),
      );
    case walletScreenRoute:
      return MaterialPageRoute(
        builder: (context) => const WalletScreen(),
      );
    case cartScreenRoute:
      return MaterialPageRoute(
        builder: (context) => const CartScreen(),
      );
    case checkoutScreenRoute:
      return MaterialPageRoute(
        builder: (context) => const CheckoutScreen(),
      );
    case paymentMethodScreenRoute:
      return MaterialPageRoute(
        builder: (context) => const PaymentCheckoutScreen(),
      );
    case thanksForOrderScreenRoute:
      final orderId = settings.arguments as String?;
      return MaterialPageRoute(
        builder: (context) => ThanksForOrderScreen(orderId: orderId),
      );
    case mapLocationPickerScreenRoute:
      return MaterialPageRoute(
        builder: (context) => const MapLocationPickerScreen(),
      );
    case addressDetailsScreenRoute:
      return MaterialPageRoute(
        builder: (context) => const AddressDetailsScreen(),
      );
    case onboardingFormScreenRoute:
      return MaterialPageRoute(
        builder: (context) => const OnboardingFormScreen(),
      );
    case verificationScreenRoute:
      return MaterialPageRoute(
        builder: (context) => const VerificationScreen(),
      );
    case onboardingAddressScreenRoute:
      return MaterialPageRoute(
        builder: (context) => const OnboardingAddressScreen(),
      );
    case termsAndConditionsScreenRoute:
      return MaterialPageRoute(
        builder: (context) => const TermsAndConditionsScreen(),
      );
    default:
      return MaterialPageRoute(
        builder: (context) => const OnBordingScreen(),
      );
  }
}
