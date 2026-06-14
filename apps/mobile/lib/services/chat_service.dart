import '../core/supabase_client.dart';
import '../models/message.dart';

class ChatService {
  static List<ChatMessage> normalizeMessageRows(
    Iterable<Map<String, dynamic>> rows,
  ) {
    final messagesById = <String, ChatMessage>{};
    for (final row in rows) {
      final message = ChatMessage.fromMap(Map<String, dynamic>.from(row));
      messagesById[message.id] = message;
    }

    return messagesById.values.toList()
      ..sort((left, right) {
        final createdAtOrder = left.createdAt.compareTo(right.createdAt);
        if (createdAtOrder != 0) return createdAtOrder;
        return left.id.compareTo(right.id);
      });
  }

  Stream<List<ChatMessage>> watchMessages(String conversationId) {
    return supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at')
        .map(normalizeMessageRows);
  }

  Future<void> sendMessage({
    required String conversationId,
    required String body,
  }) async {
    final user = supabase.auth.currentUser!;
    await supabase.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': user.id,
      'message_type': 'text',
      'body': body.trim(),
    });
  }

  Future<int> markConversationRead(String conversationId) async {
    final count = await supabase.rpc(
      'mark_conversation_read',
      params: {'p_conversation_id': conversationId},
    );
    return count as int? ?? 0;
  }

  Future<String?> findConversationForTask(String taskId) async {
    final user = supabase.auth.currentUser!;
    final row = await supabase
        .from('conversations')
        .select('id')
        .eq('task_id', taskId)
        .or('requester_id.eq.${user.id},helper_id.eq.${user.id}')
        .maybeSingle();

    return row == null ? null : row['id'] as String;
  }
}
