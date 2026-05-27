import 'package:flutter_test/flutter_test.dart';
import 'package:zhao_bang_shou/services/upload_service.dart';

void main() {
  group('UploadService.safeTaskImageExtension', () {
    test('keeps allowed image extensions', () {
      expect(UploadService.safeTaskImageExtension('photo.JPG'), 'jpg');
      expect(UploadService.safeTaskImageExtension('photo.jpeg'), 'jpeg');
      expect(UploadService.safeTaskImageExtension('photo.png'), 'png');
      expect(UploadService.safeTaskImageExtension('photo.webp'), 'webp');
    });

    test('falls back to jpg for unknown extensions', () {
      expect(UploadService.safeTaskImageExtension('photo.gif'), 'jpg');
      expect(UploadService.safeTaskImageExtension('photo'), 'jpg');
    });
  });

  group('UploadService.taskImageContentType', () {
    test('maps known extensions to storage content types', () {
      expect(UploadService.taskImageContentType('png'), 'image/png');
      expect(UploadService.taskImageContentType('webp'), 'image/webp');
      expect(UploadService.taskImageContentType('jpg'), 'image/jpeg');
      expect(UploadService.taskImageContentType('jpeg'), 'image/jpeg');
    });
  });

  group('UploadService completion proof helpers', () {
    test('keeps image and pdf proof extensions', () {
      expect(UploadService.safeCompletionProofExtension('proof.JPG'), 'jpg');
      expect(UploadService.safeCompletionProofExtension('proof.webp'), 'webp');
      expect(UploadService.safeCompletionProofExtension('proof.pdf'), 'pdf');
    });

    test('falls back to jpg for unknown proof extensions', () {
      expect(UploadService.safeCompletionProofExtension('proof.exe'), 'jpg');
      expect(UploadService.safeCompletionProofExtension('proof'), 'jpg');
    });

    test('maps proof content types', () {
      expect(UploadService.completionProofContentType('png'), 'image/png');
      expect(UploadService.completionProofContentType('webp'), 'image/webp');
      expect(
          UploadService.completionProofContentType('pdf'), 'application/pdf');
      expect(UploadService.completionProofContentType('jpg'), 'image/jpeg');
    });

    test('detects image proof paths and remote URLs', () {
      expect(UploadService.isImageProofPath('user/task/proof.png'), isTrue);
      expect(UploadService.isImageProofPath('user/task/proof.pdf'), isFalse);
      expect(
          UploadService.isRemoteUrl('https://example.com/proof.jpg'), isTrue);
      expect(UploadService.isRemoteUrl('user/task/proof.jpg'), isFalse);
    });
  });
}
