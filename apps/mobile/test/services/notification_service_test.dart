import 'package:flutter_test/flutter_test.dart';
import 'package:zhao_bang_shou/services/notification_service.dart';

void main() {
  group('AppNotification.fromMap', () {
    test('routes chat notifications to the conversation', () {
      final notification = AppNotification.fromMap({
        'id': 'notification-id',
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
  });
}
