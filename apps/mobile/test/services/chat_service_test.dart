import 'package:helper/services/chat_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatService', () {
    test('conversation summary select disambiguates profile relationships', () {
      expect(
        ChatService.conversationSummarySelect,
        contains('profiles!conversations_requester_id_fkey'),
      );
      expect(
        ChatService.conversationSummarySelect,
        contains('profiles!conversations_helper_id_fkey'),
      );
    });

    test('normalizes realtime message rows by id and created time', () {
      final messages = ChatService.normalizeMessageRows([
        {
          'id': 'message-2',
          'conversation_id': 'conversation-1',
          'sender_id': 'user-2',
          'body': 'later',
          'created_at': '2026-01-01T00:02:00Z',
        },
        {
          'id': 'message-1',
          'conversation_id': 'conversation-1',
          'sender_id': 'user-1',
          'body': 'first',
          'created_at': '2026-01-01T00:01:00Z',
        },
        {
          'id': 'message-2',
          'conversation_id': 'conversation-1',
          'sender_id': 'user-2',
          'body': 'later updated',
          'created_at': '2026-01-01T00:02:00Z',
          'read_at': '2026-01-01T00:03:00Z',
        },
      ]);

      expect(messages.map((message) => message.id), [
        'message-1',
        'message-2',
      ]);
      expect(messages.last.body, 'later updated');
      expect(messages.last.readAt, isNotNull);
    });

    test('normalizes conversation summaries for the current user', () {
      final summaries = ChatService.normalizeConversationRows([
        {
          'id': 'conversation-older',
          'task_id': 'task-older',
          'requester_id': 'owner-id',
          'helper_id': 'helper-id',
          'status': 'open',
          'created_at': '2026-01-01T00:00:00Z',
          'updated_at': '2026-01-01T00:01:00Z',
          'task': {
            'title': '搬一个小书柜',
            'status': 'completed',
            'city': 'Kuala Lumpur',
            'district': 'Bukit Bintang',
          },
          'requester': {'display_name': '任务用户'},
          'helper': {'display_name': '本地帮手'},
          'messages': [
            {
              'id': 'message-1',
              'sender_id': 'helper-id',
              'body': '我已经完成了',
              'created_at': '2026-01-01T00:03:00Z',
              'read_at': '2026-01-01T00:04:00Z',
            },
          ],
        },
        {
          'id': 'conversation-newer',
          'task_id': 'task-newer',
          'requester_id': 'owner-id',
          'helper_id': 'helper-id',
          'status': 'open',
          'last_message_at': '2026-01-01T00:07:00Z',
          'created_at': '2026-01-01T00:00:00Z',
          'updated_at': '2026-01-01T00:06:00Z',
          'task': {
            'title': '今晚帮忙取文件',
            'status': 'in_progress',
            'is_urgent': true,
            'city': 'Petaling Jaya',
          },
          'requester': {'display_name': '任务用户'},
          'helper': {'display_name': '本地帮手'},
          'messages': [
            {
              'id': 'message-3',
              'sender_id': 'helper-id',
              'body': '我马上出发',
              'created_at': '2026-01-01T00:07:00Z',
              'read_at': null,
            },
            {
              'id': 'message-2',
              'sender_id': 'owner-id',
              'body': '地址发你了',
              'created_at': '2026-01-01T00:05:00Z',
              'read_at': null,
            },
          ],
        },
      ], 'owner-id');

      expect(summaries.map((summary) => summary.id), [
        'conversation-newer',
        'conversation-older',
      ]);
      expect(summaries.first.peerName, '本地帮手');
      expect(summaries.first.lastMessagePreview, '我马上出发');
      expect(summaries.first.unreadCount, 1);
      expect(summaries.first.isActiveTask, isTrue);
      expect(summaries.first.isTaskUrgent, isTrue);
      expect(summaries.first.locationLabel, 'Petaling Jaya');
      expect(summaries.last.unreadCount, 0);
      expect(summaries.last.locationLabel, 'Kuala Lumpur · Bukit Bintang');
    });

    test('uses safe fallback values for sparse conversation rows', () {
      final summaries = ChatService.normalizeConversationRows([
        {
          'id': 'conversation-id',
          'task_id': 'task-id',
          'requester_id': 'owner-id',
          'helper_id': 'helper-id',
          'created_at': '2026-01-01T00:00:00Z',
        },
      ], 'helper-id');

      expect(summaries.single.peerName, '对方');
      expect(summaries.single.taskTitle, '未命名任务');
      expect(summaries.single.lastMessagePreview, '还没有消息，打个招呼吧');
      expect(summaries.single.locationLabel, '未填写地点');
      expect(summaries.single.unreadCount, 0);
    });
  });
}
