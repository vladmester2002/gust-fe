import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

class HashHelper {
  static final Random _random = Random.secure();

  static String generateSalt([int length = 32]) {
    final values = List<int>.generate(length, (_) => _random.nextInt(256));
    return base64UrlEncode(values);
  }

  static String hashPassword(String password, String salt) {
    final bytes = utf8.encode('$salt$password');
    final digest = sha256.convert(bytes);
    return '$salt:${digest.toString()}';
  }

  static bool verifyPassword(String password, String storedValue) {
    final parts = storedValue.split(':');
    if (parts.length != 2) return false;
    final salt = parts.first;
    return hashPassword(password, salt) == storedValue;
  }
}
