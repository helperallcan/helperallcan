import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_client.dart';

class UploadedFile {
  const UploadedFile({required this.path, this.publicUrl});

  final String path;
  final String? publicUrl;
}

class UploadService {
  static const maxTaskImageBytes = 10 * 1024 * 1024;
  static const maxCompletionProofBytes = 10 * 1024 * 1024;

  static String safeTaskImageExtension(String fileName) {
    final parts = fileName.split('.');
    final extension = parts.length > 1 ? parts.last.toLowerCase() : '';
    return ['jpg', 'jpeg', 'png', 'webp'].contains(extension)
        ? extension
        : 'jpg';
  }

  static String taskImageContentType(String extension) {
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }

  static String safeCompletionProofExtension(String fileName) {
    final parts = fileName.split('.');
    final extension = parts.length > 1 ? parts.last.toLowerCase() : '';
    return ['jpg', 'jpeg', 'png', 'webp', 'pdf'].contains(extension)
        ? extension
        : 'jpg';
  }

  static String completionProofContentType(String extension) {
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'pdf' => 'application/pdf',
      _ => 'image/jpeg',
    };
  }

  static bool isImageProofPath(String path) {
    final extension = safeCompletionProofExtension(path);
    return ['jpg', 'jpeg', 'png', 'webp'].contains(extension);
  }

  static bool isRemoteUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  Future<UploadedFile> uploadTaskImage({
    required String taskId,
    required XFile file,
  }) async {
    final user = supabase.auth.currentUser!;
    final size = await file.length();
    if (size > maxTaskImageBytes) {
      throw ArgumentError('图片不能超过 10MB');
    }

    final safeExtension = safeTaskImageExtension(file.name);
    final path =
        '${user.id}/$taskId/${DateTime.now().microsecondsSinceEpoch}.$safeExtension';

    await supabase.storage.from('task-images').uploadBinary(
          path,
          await file.readAsBytes(),
          fileOptions: FileOptions(
            contentType: taskImageContentType(safeExtension),
            upsert: false,
          ),
        );

    return UploadedFile(
      path: path,
      publicUrl: supabase.storage.from('task-images').getPublicUrl(path),
    );
  }

  Future<UploadedFile> uploadCompletionProof({
    required String taskId,
    required XFile file,
  }) async {
    final user = supabase.auth.currentUser!;
    final size = await file.length();
    if (size > maxCompletionProofBytes) {
      throw ArgumentError('完成证明不能超过 10MB');
    }

    final safeExtension = safeCompletionProofExtension(file.name);
    final path =
        '${user.id}/$taskId/${DateTime.now().microsecondsSinceEpoch}.$safeExtension';

    await supabase.storage.from('completion-proofs').uploadBinary(
          path,
          await file.readAsBytes(),
          fileOptions: FileOptions(
            contentType: completionProofContentType(safeExtension),
            upsert: false,
          ),
        );

    return UploadedFile(path: path);
  }

  Future<String> createCompletionProofSignedUrl(String path) async {
    if (isRemoteUrl(path)) return path;
    return supabase.storage
        .from('completion-proofs')
        .createSignedUrl(path, 60 * 15);
  }
}
