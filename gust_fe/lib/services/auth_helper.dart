import 'package:shared_preferences/shared_preferences.dart';

import '../services/secure_storage_service.dart';

/// Helper service to manage locally stored authentication state.
class AuthHelper {
  static const _tokenKey = 'jwt_token';
  static const _userIdKey = 'user_id';
  static const _emailKey = 'user_email';
  static const _providerKey = 'auth_provider';
  static const _guestUserIdKey = 'guest_user_id_cache';
  static const _guestEmailKey = 'guest_email_cache';

  /// Persist the session metadata so non-provider widgets can work without AuthState.
  static Future<void> storeSession({
    required String token,
    required int userId,
    required String email,
    required String provider,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userIdKey, userId.toString());
    await prefs.setString(_emailKey, email);
    await prefs.setString(_providerKey, provider);
  }

  /// Check if user is authenticated (has a token)
  static Future<bool> isAuthenticated() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    return token != null && token.isNotEmpty;
  }

  static bool _looksLikeJwt(String? token) =>
      token != null && token.split('.').length == 3;

  /// Get the stored JWT token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// Returns a JWT token that can be sent to the backend or `null` if the
  /// cached token looks like an offline/local placeholder.
  static Future<String?> getNetworkToken() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_tokenKey);
    if (_looksLikeJwt(stored)) return stored;

    final secureToken =
        await SecureStorageService.instance.readAccessToken();
    if (_looksLikeJwt(secureToken)) {
      await prefs.setString(_tokenKey, secureToken!);
      return secureToken;
    }
    return null;
  }

  /// Clear all authentication data (logout)
  static Future<void> clearAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_providerKey);
    await SecureStorageService.instance.clearAccessToken();
  }

  /// Get user ID if available
  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  static Future<String?> getProvider() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_providerKey);
  }

  static Future<bool> isGuestSession() async {
    final provider = await getProvider();
    return provider == 'ANONYMOUS';
  }

  static Future<void> rememberGuestUser({
    required int userId,
    required String email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_guestUserIdKey, userId.toString());
    await prefs.setString(_guestEmailKey, email);
  }

  static Future<GuestIdentity?> getSavedGuestUser() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_guestEmailKey);
    final userIdRaw = prefs.getString(_guestUserIdKey);
    if (email == null || userIdRaw == null) return null;
    final userId = int.tryParse(userIdRaw);
    if (userId == null) return null;
    return GuestIdentity(userId: userId, email: email);
  }

  static Future<void> clearGuestUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_guestUserIdKey);
    await prefs.remove(_guestEmailKey);
  }
}

class GuestIdentity {
  const GuestIdentity({required this.userId, required this.email});
  final int userId;
  final String email;
}
