import 'package:flutter_test/flutter_test.dart';
import 'package:helper/services/push_token_service.dart';

void main() {
  group('PushTokenService.normalizePlatform', () {
    test('accepts supported platforms case-insensitively', () {
      expect(PushTokenService.normalizePlatform(' Android '), 'android');
      expect(PushTokenService.normalizePlatform('iOS'), 'ios');
      expect(PushTokenService.normalizePlatform('web'), 'web');
    });

    test('rejects unsupported platforms', () {
      expect(
        () => PushTokenService.normalizePlatform('desktop'),
        throwsArgumentError,
      );
    });
  });

  group('PushTokenService.normalizeOptionalText', () {
    test('trims values and converts blanks to null', () {
      expect(PushTokenService.normalizeOptionalText(' phone-1 '), 'phone-1');
      expect(PushTokenService.normalizeOptionalText('   '), isNull);
      expect(PushTokenService.normalizeOptionalText(null), isNull);
    });
  });
}
