import 'package:flutter_test/flutter_test.dart';
import 'package:staffpro/core/utils/crypto_utils.dart';
import 'package:staffpro/core/utils/formatters.dart';
import 'package:staffpro/core/validators/validators.dart';
import 'package:staffpro/models/enums.dart';
import 'package:staffpro/services/location_service.dart';
import 'package:staffpro/state/app_state.dart';

void main() {
  group('validators & formatters', () {
    test('email and amount', () {
      expect(Validators.email('bad'), isNotNull);
      expect(Validators.email('owner@store.com'), isNull);
      expect(Validators.amount('0'), isNotNull);
      expect(Validators.amount('1500'), isNull);
    });

    test('money / initials / duration', () {
      expect(Formatters.money(52430).contains('52,430'), isTrue);
      expect(Formatters.initials('Ali Khan'), 'AK');
      expect(Formatters.duration(null), '--:--');
      expect(Formatters.duration(90), '01:30');
    });

    test('password hashing', () {
      final salt = CryptoUtils.randomSalt();
      final hash = CryptoUtils.hashPassword('Secret123', salt);
      expect(hash.contains('Secret123'), isFalse);
      expect(CryptoUtils.verify('Secret123', salt, hash), isTrue);
    });
  });

  group('role ranks', () {
    test('ordering', () {
      expect(StaffProController.roleRank(UserRole.superAdmin), greaterThan(StaffProController.roleRank(UserRole.businessAdmin)));
      expect(StaffProController.roleRank(UserRole.businessAdmin), greaterThan(StaffProController.roleRank(UserRole.manager)));
      expect(StaffProController.roleRank(UserRole.manager), greaterThan(StaffProController.roleRank(UserRole.employee)));
    });
  });

  group('geofence math', () {
    test('same point is ~0m', () {
      const a = GeoPoint(31.5204, 74.3587);
      expect(LocationService.distanceMeters(a, a), lessThan(1));
    });

    test('nearby points within 200m geofence', () {
      const branch = GeoPoint(31.5204, 74.3587);
      // ~11m north
      const near = GeoPoint(31.5205, 74.3587);
      final d = LocationService.distanceMeters(branch, near);
      expect(d, lessThan(200));
    });
  });

  group('period filter', () {
    test('today contains now', () {
      final p = PeriodFilter.today();
      expect(p.contains(DateTime.now()), isTrue);
    });
  });
}
