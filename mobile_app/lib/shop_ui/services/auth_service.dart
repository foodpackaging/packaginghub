import 'package:b2b_store/core/services/api_client.dart';
import 'package:b2b_store/shared/models/user_profile.dart';

class AuthService {
  final ApiClient _client = ApiClient.instance;

  Future<UserProfile> signUp({required String email, required String password}) async {
    final response = await _client.post('/auth/signup', body: {'email': email, 'password': password});
    await _client.saveTokens(
      accessToken: response['access_token'] as String,
      refreshToken: response['refresh_token'] as String,
    );
    return UserProfile.fromJson(response['user'] as Map<String, dynamic>);
  }

  Future<UserProfile> signIn({required String email, required String password}) async {
    final response = await _client.post('/auth/login', body: {'email': email, 'password': password});
    await _client.saveTokens(
      accessToken: response['access_token'] as String,
      refreshToken: response['refresh_token'] as String,
    );
    return UserProfile.fromJson(response['user'] as Map<String, dynamic>);
  }

  Future<void> signOut() async {
    try {
      await _client.post('/auth/logout');
    } catch (_) {
      // Best-effort; the token is discarded locally regardless.
    }
    await _client.clearTokens();
  }

  Future<UserProfile?> getCurrentProfile() async {
    if (!await _client.hasSession()) return null;
    try {
      final response = await _client.get('/auth/me');
      return UserProfile.fromJson(response['user'] as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _client.post('/auth/forgot-password', body: {'email': email});
  }

  /// Confirms a reset code without consuming it, so the app can gate the
  /// new-password step behind a verified code. Throws [ApiException] if invalid.
  Future<void> verifyResetCode({required String email, required String code}) async {
    await _client.post('/auth/verify-reset-code', body: {'email': email, 'code': code});
  }

  Future<void> resetPassword({required String email, required String code, required String newPassword}) async {
    await _client.post('/auth/reset-password', body: {
      'email': email,
      'code': code,
      'new_password': newPassword,
    });
  }

  Future<void> updatePassword(String newPassword) async {
    await _client.post('/auth/update-password', body: {'new_password': newPassword});
  }
}
