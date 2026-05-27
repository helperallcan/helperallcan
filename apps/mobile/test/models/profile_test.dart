import 'package:flutter_test/flutter_test.dart';
import 'package:helper/models/profile.dart';

void main() {
  group('AppRole.fromValue', () {
    test('parses known roles', () {
      expect(AppRole.fromValue('user'), AppRole.user);
      expect(AppRole.fromValue('helper'), AppRole.helper);
      expect(AppRole.fromValue('merchant'), AppRole.merchant);
      expect(AppRole.fromValue('admin'), AppRole.admin);
    });

    test('falls back to user for unknown role', () {
      expect(AppRole.fromValue('unknown'), AppRole.user);
      expect(AppRole.fromValue(null), AppRole.user);
    });
  });

  group('AppRole.selectable', () {
    test('contains only public user choices', () {
      expect(AppRole.selectable, [
        AppRole.user,
        AppRole.helper,
        AppRole.merchant,
      ]);
      expect(AppRole.selectable, isNot(contains(AppRole.admin)));
    });
  });

  group('UserProfile.fromMap', () {
    test('maps database profile row', () {
      final profile = UserProfile.fromMap({
        'id': 'user-id',
        'display_name': '阿明',
        'role': 'helper',
        'phone': '+60 12-345 6789',
        'avatar_url': 'https://example.com/avatar.png',
        'city': 'Kuala Lumpur',
        'district': 'Cheras',
        'bio': 'Reliable helper',
        'is_blocked': false,
      });

      expect(profile.id, 'user-id');
      expect(profile.displayName, '阿明');
      expect(profile.role, AppRole.helper);
      expect(profile.phone, '+60 12-345 6789');
      expect(profile.city, 'Kuala Lumpur');
      expect(profile.district, 'Cheras');
      expect(profile.bio, 'Reliable helper');
      expect(profile.isBlocked, isFalse);
    });

    test('uses safe defaults for optional fields', () {
      final profile = UserProfile.fromMap({'id': 'user-id'});

      expect(profile.displayName, '新用户');
      expect(profile.role, AppRole.user);
      expect(profile.isBlocked, isFalse);
    });
  });
}
