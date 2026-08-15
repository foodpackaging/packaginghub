import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../../core/services/push_notification_service.dart';
import '../../shop_ui/services/auth_service.dart';

class AuthController extends AsyncNotifier<UserProfile?> {
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  final PushNotificationService _push = PushNotificationService.instance;

  @override
  Future<UserProfile?> build() async {
    final profile = await _authService.getCurrentProfile();
    if (profile != null) {
      // Returning user: refresh the device token (FCM rotates it) and, if a
      // notification launched the app, jump to the order it points at.
      _push.registerDevice();
      _push.handleLaunchMessage();
    }
    return profile;
  }

  Future<void> login(String email, String password) async {
    final profile = await _authService.signIn(email: email, password: password);
    state = AsyncValue.data(profile);
    _push.registerDevice();
  }

  Future<void> signUp(String email, String password) async {
    final profile = await _authService.signUp(email: email, password: password);
    state = AsyncValue.data(profile);
    _push.registerDevice();
  }

  Future<void> logout() async {
    // Detach the device first: unregistering needs the access token that
    // signOut is about to throw away, and a shared phone must stop receiving
    // this account's order updates.
    await _push.unregisterDevice();
    await _authService.signOut();
    state = const AsyncValue.data(null);
  }

  Future<void> refresh() async {
    final profile = await _authService.getCurrentProfile();
    state = AsyncValue.data(profile);
  }

  Future<void> completeOnboarding(Map<String, dynamic> data) async {
    final profile = await _apiService.completeOnboarding(data);
    state = AsyncValue.data(profile);
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    final profile = await _apiService.updateProfile(data);
    state = AsyncValue.data(profile);
  }
}

final userProfileProvider = AsyncNotifierProvider<AuthController, UserProfile?>(AuthController.new);
