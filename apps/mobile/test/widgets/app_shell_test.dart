import 'package:flutter_test/flutter_test.dart';
import 'package:helper/widgets/app_shell.dart';

void main() {
  group('AppShellBreakpoints', () {
    test('uses mobile shell below desktop width', () {
      expect(AppShellBreakpoints.isDesktop(899), isFalse);
    });

    test('uses desktop shell at desktop width and above', () {
      expect(AppShellBreakpoints.isDesktop(900), isTrue);
      expect(AppShellBreakpoints.isDesktop(1280), isTrue);
    });
  });
}
