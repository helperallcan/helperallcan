import 'task.dart';

class ChatConversationSummary {
  const ChatConversationSummary({
    required this.id,
    required this.taskId,
    required this.requesterId,
    required this.helperId,
    required this.status,
    required this.taskTitle,
    required this.taskStatus,
    required this.peerId,
    required this.peerName,
    required this.lastMessagePreview,
    required this.lastActivityAt,
    required this.unreadCount,
    this.peerAvatarUrl,
    this.city,
    this.district,
    this.isTaskUrgent = false,
  });

  final String id;
  final String taskId;
  final String requesterId;
  final String helperId;
  final String status;
  final String taskTitle;
  final TaskStatus taskStatus;
  final String peerId;
  final String peerName;
  final String? peerAvatarUrl;
  final String? city;
  final String? district;
  final bool isTaskUrgent;
  final String lastMessagePreview;
  final DateTime lastActivityAt;
  final int unreadCount;

  bool get hasUnread => unreadCount > 0;

  bool get isActiveTask =>
      taskStatus == TaskStatus.assigned || taskStatus == TaskStatus.inProgress;

  String get locationLabel {
    final parts = [
      if (city != null && city!.trim().isNotEmpty) city!.trim(),
      if (district != null && district!.trim().isNotEmpty) district!.trim(),
    ];
    return parts.isEmpty ? '未填写地点' : parts.join(' · ');
  }

  factory ChatConversationSummary.fromMap(
    Map<String, dynamic> map, {
    required String currentUserId,
  }) {
    final requesterId = map['requester_id'] as String? ?? '';
    final helperId = map['helper_id'] as String? ?? '';
    final task = _readMap(map['task']) ?? _readMap(map['tasks']);
    final requester = _readMap(map['requester']);
    final helper = _readMap(map['helper']);
    final peer = currentUserId == requesterId ? helper : requester;
    final peerId = currentUserId == requesterId ? helperId : requesterId;
    final messages = _readMessages(map['messages']);
    final lastMessage = messages.isEmpty ? null : messages.last;
    final createdAt = _readDate(map['created_at']);
    final updatedAt = _readDate(map['updated_at']);
    final lastMessageAt =
        _readDate(map['last_message_at']) ?? lastMessage?.createdAt;

    return ChatConversationSummary(
      id: map['id'] as String? ?? '',
      taskId: map['task_id'] as String? ?? '',
      requesterId: requesterId,
      helperId: helperId,
      status: map['status'] as String? ?? 'open',
      taskTitle: _readString(task?['title'], fallback: '未命名任务'),
      taskStatus: TaskStatus.fromValue(task?['status'] as String?),
      peerId: peerId,
      peerName: _readString(peer?['display_name'], fallback: '对方'),
      peerAvatarUrl: peer?['avatar_url'] as String?,
      city: task?['city'] as String?,
      district: task?['district'] as String?,
      isTaskUrgent: task?['is_urgent'] as bool? ?? false,
      lastMessagePreview:
          _readString(lastMessage?.body, fallback: '还没有消息，打个招呼吧'),
      lastActivityAt: lastMessageAt ?? updatedAt ?? createdAt ?? DateTime.now(),
      unreadCount: messages
          .where((message) =>
              message.senderId != currentUserId && message.readAt == null)
          .length,
    );
  }

  static Map<String, dynamic>? _readMap(Object? value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  static List<_ConversationMessage> _readMessages(Object? value) {
    if (value is! List) {
      return const [];
    }

    return value
        .whereType<Map>()
        .map((item) =>
            _ConversationMessage.fromMap(Map<String, dynamic>.from(item)))
        .toList()
      ..sort((left, right) {
        final createdAtOrder = left.createdAt.compareTo(right.createdAt);
        if (createdAtOrder != 0) return createdAtOrder;
        return left.id.compareTo(right.id);
      });
  }

  static DateTime? _readDate(Object? value) {
    if (value is! String) {
      return null;
    }
    return DateTime.tryParse(value);
  }

  static String _readString(Object? value, {required String fallback}) {
    if (value is! String) {
      return fallback;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }
}

class _ConversationMessage {
  const _ConversationMessage({
    required this.id,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String senderId;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;

  factory _ConversationMessage.fromMap(Map<String, dynamic> map) {
    return _ConversationMessage(
      id: map['id'] as String? ?? '',
      senderId: map['sender_id'] as String? ?? '',
      body: map['body'] as String? ?? '',
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      readAt: DateTime.tryParse(map['read_at'] as String? ?? ''),
    );
  }
}
