import 'package:flutter_test/flutter_test.dart';
import 'package:zhao_bang_shou/models/task.dart';
import 'package:zhao_bang_shou/models/task_create_input.dart';

void main() {
  group('TaskCreateInput.parseOptionalMoney', () {
    test('parses empty value as null', () {
      expect(TaskCreateInput.parseOptionalMoney(''), isNull);
      expect(TaskCreateInput.parseOptionalMoney('  '), isNull);
    });

    test('parses numeric values', () {
      expect(TaskCreateInput.parseOptionalMoney('88.50'), 88.5);
    });
  });

  group('TaskCreateInput.budgetRangeError', () {
    test('accepts valid budget range', () {
      final input = _input(budgetMin: 50, budgetMax: 100);
      expect(input.budgetRangeError, isNull);
    });

    test('rejects inverted budget range', () {
      final input = _input(budgetMin: 100, budgetMax: 50);
      expect(input.budgetRangeError, isNotNull);
    });
  });

  group('TaskCreateInput.toInsertMap', () {
    test('trims strings and converts blank optional fields to null', () {
      final input = _input(
        title: '  Move a desk  ',
        description: '  Need help moving one desk tomorrow.  ',
        locationText: '  Cheras  ',
        categoryId: 'category-id',
        subcategoryId: 'subcategory-id',
        city: '  Kuala Lumpur  ',
        district: '   ',
        budgetMin: 50,
        budgetMax: 100,
      );

      final map = input.toInsertMap(creatorId: 'user-id');

      expect(map['creator_id'], 'user-id');
      expect(map['task_type'], TaskKind.help.value);
      expect(map['title'], 'Move a desk');
      expect(map['description'], 'Need help moving one desk tomorrow.');
      expect(map['location_text'], 'Cheras');
      expect(map['category_id'], 'category-id');
      expect(map['subcategory_id'], 'subcategory-id');
      expect(map['city'], 'Kuala Lumpur');
      expect(map['district'], isNull);
      expect(map['budget_min'], 50);
      expect(map['budget_max'], 100);
      expect(map['status'], 'open');
    });

    test('sets urgent fee only for urgent tasks', () {
      expect(
          _input(isUrgent: true)
              .toInsertMap(creatorId: 'user-id')['urgent_fee'],
          urgentPublishFee);
      expect(
          _input(isUrgent: false)
              .toInsertMap(creatorId: 'user-id')['urgent_fee'],
          0);
    });
  });
}

TaskCreateInput _input({
  String title = 'Need help moving a desk',
  String description = 'Please help move one desk tomorrow.',
  String locationText = 'Cheras',
  String? categoryId,
  String? subcategoryId,
  String? city,
  String? district,
  double? budgetMin,
  double? budgetMax,
  bool isUrgent = false,
}) {
  return TaskCreateInput(
    taskKind: TaskKind.help,
    title: title,
    description: description,
    locationText: locationText,
    categoryId: categoryId,
    subcategoryId: subcategoryId,
    city: city,
    district: district,
    budgetMin: budgetMin,
    budgetMax: budgetMax,
    isUrgent: isUrgent,
  );
}
