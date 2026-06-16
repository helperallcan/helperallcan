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
      expect(notification.typeLabel, '聊天');
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
      expect(notification.typeLabel, '任务');
    });

    test('uses safe explicit route paths for tracking notifications', () {
      final notification = AppNotification.fromMap({
        'id': 'notification-id',
        'title': '任务位置已更新',
        'body': '对方共享了当前位置',
        'created_at': '2026-05-25T08:00:00.000Z',
        'data': {
          'task_id': 'task-id',
          'route_path': '/tasks/task-id/tracking',
        },
      });

      expect(notification.routePath, '/tasks/task-id/tracking');
      expect(notification.typeLabel, '位置');
    });

    test('labels offer and system notifications for display', () {
      final offerNotification = AppNotification.fromMap({
        'id': 'offer-notification',
        'notification_type': 'offer',
        'title': '收到新的帮手报价',
        'body': '有人报价',
        'created_at': '2026-05-25T08:00:00.000Z',
      });
      final systemNotification = AppNotification.fromMap({
        'id': 'system-notification',
        'notification_type': 'system',
        'title': '系统通知',
        'body': '资料已更新',
        'created_at': '2026-05-25T08:00:00.000Z',
      });

      expect(offerNotification.typeLabel, '报价');
      expect(systemNotification.typeLabel, '系统');
    });

    test('ignores unsafe explicit route paths and falls back safely', () {
      final notification = AppNotification.fromMap({
        'id': 'notification-id',
        'title': '任务位置已更新',
        'body': '对方共享了当前位置',
        'created_at': '2026-05-25T08:00:00.000Z',
        'data': {
          'task_id': 'task-id',
          'route_path': 'https://example.com/phishing',
        },
      });

      expect(notification.routePath, '/tasks/task-id');
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

    test('describes unread summary for the app shell badge', () {
      expect(
        const UnreadSummary(notifications: 0, chats: 0).tooltipLabel,
        '通知',
      );
      expect(
        const UnreadSummary(notifications: 2, chats: 1).tooltipLabel,
        '通知，2 条通知，1 条聊天未读',
      );
      expect(
        const UnreadSummary(notifications: 0, chats: 3).tooltipLabel,
        '通知，3 条聊天未读',
      );
    });
  });
}
