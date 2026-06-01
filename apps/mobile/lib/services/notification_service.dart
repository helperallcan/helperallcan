import 'dart:async';

import '../core/supabase_client.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.notificationType,
    required this.title,
    required this.body,
    required this.createdAt,
    this.data = const {},
    this.readAt,
  });

  final String id;
  final String notificationType;
  final String title;
  final String body;
  final DateTime createdAt;
  final Map<String, dynamic> data;
  final DateTime? readAt;

  bool get isRead => readAt != null;
  bool get isChat => notificationType == 'chat' || conversationId != null;

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
      notificationType: map['notification_type'] as String? ?? 'system',
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

class UnreadSummary {
  const UnreadSummary({
    required this.notifications,
    required this.chats,
  });

  final int notifications;
  final int chats;

  int get total => notifications + chats;
  bool get hasUnread => total > 0;
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

  Stream<int> watchUnreadNotificationCount({bool includeChat = false}) {
    return watchNotifications().map(
      (items) => unreadNotificationCount(
        items,
        includeChat: includeChat,
      ),
    );
  }

  Stream<int> watchUnreadChatCount() {
    final user = supabase.auth.currentUser!;
    return supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .order('created_at')
        .map((rows) => unreadMessageCountFromRows(rows, user.id));
  }

  Stream<UnreadSummary> watchUnreadSummary() {
    final controller = StreamController<UnreadSummary>();
    StreamSubscription<int>? notificationSubscription;
    StreamSubscription<int>? chatSubscription;
    var notifications = 0;
    var chats = 0;

    void emit() {
      if (!controller.isClosed) {
        controller.add(
          UnreadSummary(notifications: notifications, chats: chats),
        );
      }
    }

    controller.onListen = () {
      notificationSubscription = watchUnreadNotificationCount().listen((value) {
        notifications = value;
        emit();
      }, onError: controller.addError);

      chatSubscription = watchUnreadChatCount().listen((value) {
        chats = value;
        emit();
      }, onError: controller.addError);
    };

    controller.onCancel = () async {
      await notificationSubscription?.cancel();
      await chatSubscription?.cancel();
    };

    return controller.stream;
  }

  Future<void> markRead(String id) async {
    await supabase
        .from('notifications')
        .update({'read_at': DateTime.now().toIso8601String()}).eq('id', id);
  }

  Future<void> markAllRead() async {
    await supabase.rpc('mark_all_notifications_read');
  }

  static int unreadNotificationCount(
    List<AppNotification> items, {
    bool includeChat = false,
  }) {
    return items
        .where((item) => !item.isRead && (includeChat || !item.isChat))
        .length;
  }

  static int unreadMessageCountFromRows(
    List<Map<String, dynamic>> rows,
    String currentUserId,
  ) {
    return rows.where((row) {
      final senderId = row['sender_id'];
      return senderId is String &&
          senderId != currentUserId &&
          row['read_at'] == null;
    }).length;
  }
}
