import 'package:shared_preferences/shared_preferences.dart';

import '../services/secure_storage_service.dart';

/// Helper service to manage locally stored authentication state.
class AuthHelper {
  static const _tokenKey = 'jwt_token';
  static const _userIdKey = 'user_id';
  static const _emailKey = 'user_email';
  static const _providerKey = 'auth_provider';
  static final SecureStorageService _secureStorage =
      SecureStorageService.instance;

  /// Persist the session metadata so non-provider widgets can work without AuthState.
  static Future<void> storeSession({
    required String token,
    required int userId,
    required String email,
    required String provider,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, userId.toString());
    await prefs.setString(_emailKey, email);
    await prefs.setString(_providerKey, provider);
    await _secureStorage.cacheAccessToken(token);
  }

  /// Check if user is authenticated (has a token)
  static Future<bool> isAuthenticated() async {
    final secureToken = await _secureStorage.readAccessToken();
    if (secureToken != null && secureToken.isNotEmpty) {
      return true;
    }

    // Migrate any legacy plain-text token into secure storage, then clear it.
    final prefs = await SharedPreferences.getInstance();
    final legacyToken = prefs.getString(_tokenKey);
    if (legacyToken != null && legacyToken.isNotEmpty) {
      await _secureStorage.cacheAccessToken(legacyToken);
      await prefs.remove(_tokenKey);
      return true;
    }
    return false;
  }

  static bool _looksLikeJwt(String? token) =>
      token != null && token.split('.').length == 3;

  /// Get the stored JWT token
  static Future<String?> getToken() async {
    final secureToken = await _secureStorage.readAccessToken();
    if (secureToken != null && secureToken.isNotEmpty) {
      return secureToken;
    }
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(_tokenKey);
    if (legacy != null && legacy.isNotEmpty) {
      await _secureStorage.cacheAccessToken(legacy);
      await prefs.remove(_tokenKey);
    }
    return legacy;
  }

  /// Returns a JWT token that can be sent to the backend or `null` if the
  /// cached token looks like an offline/local placeholder.
  static Future<String?> getNetworkToken() async {
    final secureToken = await _secureStorage.readAccessToken();
    if (_looksLikeJwt(secureToken)) {
      return secureToken;
    }

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_tokenKey);
    if (_looksLikeJwt(stored)) {
      await _secureStorage.cacheAccessToken(stored!);
      await prefs.remove(_tokenKey);
      return stored;
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
    await _secureStorage.clearAccessToken();
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
}
