import 'package:flutter_test/flutter_test.dart';
import 'package:helper/services/notification_service.dart';

void main() {
  group('AppNotification.fromMap', () {
    test('routes chat notifications to the conversation', () {
      final notification = AppNotification.fromMap({
        'id': 'notification-id',
        'notification_type': 'chat',
        'title': '报价已通过',
        'body': '可以开始聊天了',
        'created_at': '2026-05-25T08:00:00.000Z',
        'data': {
          'task_id': 'task-id',
          'conversation_id': 'conversation-id',
        },
      });

      expect(notification.taskId, 'task-id');
      expect(notification.conversationId, 'conversation-id');
      expect(notification.routePath, '/chat/conversation-id');
      expect(notification.isRead, isFalse);
      expect(notification.isChat, isTrue);
    });

    test('routes task notifications to the task detail page', () {
      final notification = AppNotification.fromMap({
        'id': 'notification-id',
        'title': '任务完成',
        'body': '请确认任务',
        'created_at': '2026-05-25T08:00:00.000Z',
        'read_at': '2026-05-25T09:00:00.000Z',
        'data': {'task_id': 'task-id'},
      });

      expect(notification.routePath, '/tasks/task-id');
      expect(notification.isRead, isTrue);
    });

    test('ignores missing or invalid notification data', () {
      final notification = AppNotification.fromMap({
        'id': 'notification-id',
        'title': null,
        'body': null,
        'created_at': '2026-05-25T08:00:00.000Z',
        'data': 'not-json',
      });

      expect(notification.title, '');
      expect(notification.body, '');
      expect(notification.data, isEmpty);
      expect(notification.routePath, isNull);
    });

    test('counts unread notifications without double-counting chats', () {
      final notifications = [
        AppNotification.fromMap({
          'id': 'task-notification',
          'notification_type': 'task',
          'title': '任务更新',
          'body': '有新的任务状态',
          'created_at': '2026-05-25T08:00:00.000Z',
        }),
        AppNotification.fromMap({
          'id': 'chat-notification',
          'notification_type': 'chat',
          'title': '新消息',
          'body': '收到一条消息',
          'created_at': '2026-05-25T08:01:00.000Z',
          'data': {'conversation_id': 'conversation-id'},
        }),
        AppNotification.fromMap({
          'id': 'read-notification',
          'notification_type': 'system',
          'title': '已读',
          'body': '这条已读',
          'created_at': '2026-05-25T08:02:00.000Z',
          'read_at': '2026-05-25T09:00:00.000Z',
        }),
      ];

      expect(
        NotificationService.unreadNotificationCount(notifications),
        1,
      );
      expect(
        NotificationService.unreadNotificationCount(
          notifications,
          includeChat: true,
        ),
        2,
      );
    });

    test('counts unread chat messages for the other participant', () {
      final rows = <Map<String, dynamic>>[
        {
          'id': 'message-1',
          'sender_id': 'helper-id',
          'read_at': null,
        },
        {
          'id': 'message-2',
          'sender_id': 'owner-id',
          'read_at': null,
        },
        {
          'id': 'message-3',
          'sender_id': 'helper-id',
          'read_at': '2026-05-25T09:00:00.000Z',
        },
      ];

      expect(
        NotificationService.unreadMessageCountFromRows(rows, 'owner-id'),
        1,
      );
    });
  });
}
