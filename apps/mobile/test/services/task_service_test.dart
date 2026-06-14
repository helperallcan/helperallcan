import 'package:flutter_test/flutter_test.dart';
import 'package:helper/services/task_service.dart';

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

  group('TaskService.taskDetailSelect', () {
    test('uses an explicit task offers relationship to avoid embed ambiguity',
        () {
      expect(
        TaskService.taskDetailSelect,
        contains('task_offers!task_offers_task_id_fkey'),
      );
    });
  });
}
