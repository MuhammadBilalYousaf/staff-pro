import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

class CryptoUtils {
  CryptoUtils._();

  static String randomSalt() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return base64UrlEncode(bytes);
  }

  static String hashPassword(String password, String salt) {
    final bytes = utf8.encode('$salt::$password');
    return sha256.convert(bytes).toString();
  }

  static bool verify(String password, String salt, String hash) {
    return hashPassword(password, salt) == hash;
  }
}
