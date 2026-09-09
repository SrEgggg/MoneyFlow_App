import 'package:flutter_test/flutter_test.dart';
import 'package:savings_app/data/models/enums.dart';

void main() {
  group('AccountType.fromId', () {
    test('canonical ids resolve to themselves', () {
      for (final t in AccountType.values) {
        expect(AccountType.fromId(t.id), t, reason: 'id: ${t.id}');
      }
    });

    test('EWallet aliases (gcash, maya, gotyme) all map to ewallet', () {
      for (final alias in const ['gcash', 'maya', 'gotyme']) {
        expect(AccountType.fromId(alias), AccountType.ewallet,
            reason: 'alias: $alias');
      }
    });

    test('crypto and digital map to digital', () {
      expect(AccountType.fromId('crypto'), AccountType.digital);
      expect(AccountType.fromId('digital'), AccountType.digital);
    });

    test('null and unknown ids fall back to other', () {
      expect(AccountType.fromId(null), AccountType.other);
      expect(AccountType.fromId(''), AccountType.other);
      expect(AccountType.fromId('not_a_real_type'), AccountType.other);
    });
  });

  group('AccountType id round-trip', () {
    test('every AccountType has a non-empty id', () {
      for (final t in AccountType.values) {
        expect(t.id, isNotEmpty);
        expect(t.label, isNotEmpty);
      }
    });

    test('every id is unique', () {
      final ids = AccountType.values.map((t) => t.id).toSet();
      expect(ids.length, AccountType.values.length);
    });
  });
}