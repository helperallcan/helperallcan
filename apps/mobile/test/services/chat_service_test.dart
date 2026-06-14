import 'package:flutter_test/flutter_test.dart';
import 'package:helper/services/chat_service.dart';

void main() {
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
}
