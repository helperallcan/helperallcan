import 'package:flutter_test/flutter_test.dart';
import 'package:zhao_bang_shou/services/task_service.dart';

void main() {
  group('TaskService.normalizeOptionalText', () {
    test('converts blank values to null', () {
      expect(TaskService.normalizeOptionalText(null), isNull);
      expect(TaskService.normalizeOptionalText(''), isNull);
      expect(TaskService.normalizeOptionalText('   '), isNull);
    });

    test('trims normal values', () {
      expect(TaskService.normalizeOptionalText('  good work  '), 'good work');
    });
  });
}
