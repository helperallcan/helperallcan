import '../core/supabase_client.dart';

class PushTokenService {
  Future<void> registerToken({
    required String platform,
    required String token,
    String? deviceId,
  }) async {
    final normalizedPlatform = normalizePlatform(platform);
    final normalizedToken = token.trim();
    if (normalizedToken.isEmpty) {
      throw ArgumentError.value(token, 'token', 'Push token cannot be blank.');
    }

    final user = supabase.auth.currentUser!;
    await supabase.from('push_tokens').upsert(
      {
        'user_id': user.id,
        'platform': normalizedPlatform,
        'token': normalizedToken,
        'device_id': normalizeOptionalText(deviceId),
        'is_active': true,
        'last_seen_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'user_id,token',
    );
  }

  Future<void> deactivateToken(String token) async {
    final user = supabase.auth.currentUser!;
    await supabase
        .from('push_tokens')
        .update({'is_active': false})
        .eq('user_id', user.id)
        .eq('token', token.trim());
  }

  static String normalizePlatform(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'android' || normalized == 'ios' || normalized == 'web') {
      return normalized;
    }
    throw ArgumentError.value(value, 'platform', 'Unsupported push platform.');
  }

  static String? normalizeOptionalText(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}
