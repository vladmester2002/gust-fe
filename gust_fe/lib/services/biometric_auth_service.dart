import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'secure_storage_service.dart';

class BiometricAuthService {
  final LocalAuthentication _localAuth = LocalAuthentication();

  Future<bool> isBiometricAvailable() async {
    if (kIsWeb) {
      return false;
    }
    try {
      final bool canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();
      return canAuthenticate;
    } catch (e) {
      debugPrint('Error checking biometric availability: $e');
      return false;
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    if (kIsWeb) {
      return const [];
    }
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('Error getting available biometrics: $e');
      return [];
    }
  }

  Future<bool> authenticate({
    String reason = 'Please authenticate to access your account',
  }) async {
    if (kIsWeb) {
      return false;
    }
    try {
      final bool isAvailable = await isBiometricAvailable();
      if (!isAvailable) {
        return false;
      }

      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );

      return didAuthenticate;
    } catch (e) {
      debugPrint('Error during biometric authentication: $e');
      return false;
    }
  }

  /// Check if the user has enabled biometric login
  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_email');
    if (email == null) return false;
    return prefs.getBool('biometric_enabled_$email') ?? false;
  }

  /// Enable biometric login for the current user
  Future<void> enableBiometric() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_email');
    if (email != null) {
      await prefs.setBool('biometric_enabled_$email', true);
      await prefs.setBool('biometric_prompt_shown_$email', true);
    }
  }

  /// Disable biometric login
  Future<void> disableBiometric() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_email');
    if (email != null) {
      await prefs.setBool('biometric_enabled_$email', false);
    }
  }

  /// Check if biometric prompt was already shown for this account
  Future<bool> wasBiometricPromptShown() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_email');
    if (email == null) return false;
    return prefs.getBool('biometric_prompt_shown_$email') ?? false;
  }

  /// Mark that biometric prompt was shown (when user skips)
  Future<void> markBiometricPromptShown() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_email');
    if (email != null) {
      await prefs.setBool('biometric_prompt_shown_$email', true);
    }
  }

  /// Save user email for account-specific biometric settings
  Future<void> saveUserEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_email', email);
  }

  /// Get a user-friendly name for the biometric type
  String getBiometricTypeName(List<BiometricType> biometrics) {
    if (biometrics.isEmpty) {
      return 'Biometric';
    }

    if (biometrics.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (biometrics.contains(BiometricType.fingerprint)) {
      return 'Fingerprint';
    } else if (biometrics.contains(BiometricType.iris)) {
      return 'Iris';
    } else {
      return 'Biometric';
    }
  }

  /// Store user's JWT token securely (for biometric login)
  /// SECURITY UPGRADE: Now uses SecureStorageService for encrypted storage
  Future<void> saveAuthToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_email');
    if (email != null) {
      // Use secure storage for the actual token (encrypted on all platforms)
      final secureStorage = SecureStorageService.instance;
      await secureStorage.cacheBiometricSecret(email, token);
    }
  }

  /// Retrieve stored JWT token after successful biometric authentication
  /// SECURITY UPGRADE: Now uses SecureStorageService for encrypted retrieval
  Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_email');
    if (email == null) return null;
    
    // Retrieve from secure storage (encrypted on all platforms)
    final secureStorage = SecureStorageService.instance;
    return secureStorage.readBiometricSecret(email);
  }

  /// Clear stored auth token (on logout)
  Future<void> clearAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_email');
    
    if (email != null) {
      // Clear from secure storage
      final secureStorage = SecureStorageService.instance;
      // Use the secure storage API to delete the biometric secret
      try {
        final storage = secureStorage;
        // Read then delete approach since we don't have direct access to _storage
        final exists = await storage.readBiometricSecret(email);
        if (exists != null) {
          // The service should have a method to clear this, but we'll work with what we have
          await storage.cacheBiometricSecret(email, ''); // Overwrite with empty
        }
      } catch (e) {
        debugPrint('Error clearing biometric token: $e');
      }
    }
    
    await disableBiometric(); // Also disable biometric on logout
  }
}
