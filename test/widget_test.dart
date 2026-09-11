import 'package:flutter_test/flutter_test.dart';
import 'package:staffpro/core/utils/crypto_utils.dart';
import 'package:staffpro/core/utils/formatters.dart';
import 'package:staffpro/core/validators/validators.dart';

void main() {
  test('password hashing is not plaintext and verifies correctly', () {
    final salt = CryptoUtils.randomSalt();
    final hash = CryptoUtils.hashPassword('Secret123', salt);
    expect(hash.contains('Secret123'), isFalse);
    expect(CryptoUtils.verify('Secret123', salt, hash), isTrue);
    expect(CryptoUtils.verify('wrong', salt, hash), isFalse);
  });

  test('email and amount validators', () {
    expect(Validators.email('bad'), isNotNull);
    expect(Validators.email('owner@store.com'), isNull);
    expect(Validators.amount('0'), isNotNull);
    expect(Validators.amount('1500'), isNull);
  });

  test('money formatter', () {
    expect(Formatters.money(52430).contains('52,430'), isTrue);
    expect(Formatters.initials('Ali Khan'), 'AK');
    expect(Formatters.duration(null), '--:--');
    expect(Formatters.duration(90), '01:30');
  });
}
