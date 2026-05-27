import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helper/core/theme.dart';

void main() {
  group('AppTheme.light', () {
    test('uses Material 3 and an 8px card radius', () {
      final theme = AppTheme.light();
      final shape = theme.cardTheme.shape;

      expect(theme.useMaterial3, isTrue);
      expect(shape, isA<RoundedRectangleBorder>());
      expect(
        (shape as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(8),
      );
    });
  });
}
