import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:helper/core/app_assets.dart';

void main() {
  group('AppAssets', () {
    test('declares bundled image assets that exist', () {
      for (final asset in AppAssets.all) {
        expect(asset, endsWith('.webp'));
        expect(File(asset).existsSync(), isTrue, reason: asset);
      }
    });
  });
}
