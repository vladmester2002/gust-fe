import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  SecureStorageService._internal();

  static final SecureStorageService instance = SecureStorageService._internal();
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(),
    mOptions: MacOsOptions(),
    lOptions: LinuxOptions(),
    webOptions: WebOptions(),
    wOptions: WindowsOptions(),
  );

  Future<void> cacheAccessToken(String token) =>
      _storage.write(key: 'auth_token', value: token);

  Future<String?> readAccessToken() => _storage.read(key: 'auth_token');

  Future<void> clearAccessToken() => _storage.delete(key: 'auth_token');

  Future<void> cacheBiometricSecret(String email, String secret) =>
      _storage.write(key: 'biometric_secret_$email', value: secret);

  Future<String?> readBiometricSecret(String email) =>
      _storage.read(key: 'biometric_secret_$email');

  Future<void> storeEncryptionKey(String userEmail, String key) =>
      _storage.write(key: 'db_key_$userEmail', value: key);

  Future<String?> readEncryptionKey(String userEmail) =>
      _storage.read(key: 'db_key_$userEmail');

  Future<void> clearAll() => _storage.deleteAll();
}
