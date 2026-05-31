import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('branding assets', () {
    test('keeps source app icons available for future store builds', () {
      expectPngSize('assets/branding/helper_app_icon.png', 1024);
      expectPngSize('assets/branding/helper_app_icon_maskable.png', 1024);
    });

    test('exports web app icons at manifest sizes', () {
      expectPngSize('web/favicon.png', 32);
      expectPngSize('web/icons/Icon-192.png', 192);
      expectPngSize('web/icons/Icon-512.png', 512);
      expectPngSize('web/icons/Icon-maskable-192.png', 192);
      expectPngSize('web/icons/Icon-maskable-512.png', 512);
    });

    test('exports Android launcher icons at density sizes', () {
      expectPngSize('android/app/src/main/res/mipmap-mdpi/ic_launcher.png', 48);
      expectPngSize('android/app/src/main/res/mipmap-hdpi/ic_launcher.png', 72);
      expectPngSize(
        'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png',
        96,
      );
      expectPngSize(
        'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png',
        144,
      );
      expectPngSize(
        'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
        192,
      );
    });
  });
}

void expectPngSize(String path, int expectedSize) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: path);
  final bytes = file.readAsBytesSync();
  expect(_pngDimension(bytes, 16), expectedSize, reason: '$path width');
  expect(_pngDimension(bytes, 20), expectedSize, reason: '$path height');
}

int _pngDimension(Uint8List bytes, int offset) {
  return (bytes[offset] << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3];
}
