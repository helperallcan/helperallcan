import '../core/supabase_client.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.data = const {},
    this.readAt,
  });

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final Map<String, dynamic> data;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  String? get taskId => _nonEmptyString(data['task_id']);
  String? get conversationId => _nonEmptyString(data['conversation_id']);

  String? get routePath {
    final chatId = conversationId;
    if (chatId != null) {
      return '/chat/$chatId';
    }

    final relatedTaskId = taskId;
    if (relatedTaskId != null) {
      return '/tasks/$relatedTaskId';
    }

    return null;
  }

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
      data: _readData(map['data']),
      readAt: DateTime.tryParse(map['read_at'] as String? ?? ''),
    );
  }

  static Map<String, dynamic> _readData(Object? value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return const {};
  }

  static String? _nonEmptyString(Object? value) {
    if (value is! String) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

class NotificationService {
  Stream<List<AppNotification>> watchNotifications() {
    final user = supabase.auth.currentUser!;
    return supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .map(
          (rows) => rows
              .map((row) =>
                  AppNotification.fromMap(Map<String, dynamic>.from(row)))
              .toList(),
        );
  }

  Future<void> markRead(String id) async {
    await supabase
        .from('notifications')
        .update({'read_at': DateTime.now().toIso8601String()}).eq('id', id);
  }
}
