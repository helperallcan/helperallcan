import 'package:flutter_test/flutter_test.dart';
import 'package:helper/core/validators.dart';

void main() {
  group('AppValidators.requiredText', () {
    test('rejects empty text', () {
      expect(AppValidators.requiredText('', min: 2), isNotNull);
    });

    test('accepts normal text', () {
      expect(AppValidators.requiredText('需要帮忙安装桌子', min: 2), isNull);
    });

    test('rejects blocked task terms', () {
      expect(AppValidators.requiredText('这是诈骗任务', min: 2), isNotNull);
    });
  });

  group('AppValidators.email', () {
    test('accepts valid email', () {
      expect(AppValidators.email('user@example.com'), isNull);
    });

    test('rejects invalid email', () {
      expect(AppValidators.email('user'), isNotNull);
      expect(AppValidators.email('user@'), isNotNull);
    });
  });

  group('AppValidators.password', () {
    test('accepts six or more characters', () {
      expect(AppValidators.password('123456'), isNull);
    });

    test('rejects short passwords', () {
      expect(AppValidators.password('12345'), isNotNull);
    });
  });

  group('AppValidators.confirmPassword', () {
    test('accepts matching password', () {
      expect(AppValidators.confirmPassword('123456', '123456'), isNull);
    });

    test('rejects mismatched password', () {
      expect(AppValidators.confirmPassword('654321', '123456'), isNotNull);
    });
  });

  group('AppValidators.displayName', () {
    test('accepts normal display name', () {
      expect(AppValidators.displayName('小明'), isNull);
    });

    test('rejects single character name', () {
      expect(AppValidators.displayName('小'), isNotNull);
    });
  });

  group('AppValidators.optionalPhone', () {
    test('accepts empty value', () {
      expect(AppValidators.optionalPhone(''), isNull);
    });

    test('accepts normal phone', () {
      expect(AppValidators.optionalPhone('+60 12-345 6789'), isNull);
    });

    test('rejects invalid phone', () {
      expect(AppValidators.optionalPhone('abc-phone'), isNotNull);
    });
  });

  group('AppValidators.optionalMoney', () {
    test('accepts empty value', () {
      expect(AppValidators.optionalMoney(''), isNull);
    });

    test('accepts positive number', () {
      expect(AppValidators.optionalMoney('120.50'), isNull);
    });

    test('rejects invalid number', () {
      expect(AppValidators.optionalMoney('-1'), isNotNull);
      expect(AppValidators.optionalMoney('abc'), isNotNull);
    });
  });

  group('AppValidators.budgetRange', () {
    test('accepts empty or partial range', () {
      expect(AppValidators.budgetRange(minValue: '', maxValue: ''), isNull);
      expect(AppValidators.budgetRange(minValue: '50', maxValue: ''), isNull);
      expect(AppValidators.budgetRange(minValue: '', maxValue: '100'), isNull);
    });

    test('accepts valid range', () {
      expect(
          AppValidators.budgetRange(minValue: '50', maxValue: '100'), isNull);
    });

    test('rejects max lower than min', () {
      expect(AppValidators.budgetRange(minValue: '120', maxValue: '80'),
          isNotNull);
    });
  });
}
