import 'dart:async';

import '../core/supabase_client.dart';
import '../models/conversation.dart';
import '../models/message.dart';

class ChatService {
  static const conversationSummarySelect =
      'id, task_id, requester_id, helper_id, status, last_message_at, created_at, updated_at, '
      'task:tasks!conversations_task_id_fkey(title, status, is_urgent, city, district), '
      'requester:profiles!conversations_requester_id_fkey(display_name, avatar_url), '
      'helper:profiles!conversations_helper_id_fkey(display_name, avatar_url), '
      'messages:messages!messages_conversation_id_fkey(id, sender_id, body, read_at, created_at)';

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

  static List<ChatConversationSummary> normalizeConversationRows(
    Iterable<Map<String, dynamic>> rows,
    String currentUserId,
  ) {
    final conversationsById = <String, ChatConversationSummary>{};
    for (final row in rows) {
      final summary = ChatConversationSummary.fromMap(
        Map<String, dynamic>.from(row),
        currentUserId: currentUserId,
      );
      if (summary.id.isNotEmpty) {
        conversationsById[summary.id] = summary;
      }
    }

    return conversationsById.values.toList()
      ..sort((left, right) {
        final activityOrder =
            right.lastActivityAt.compareTo(left.lastActivityAt);
        if (activityOrder != 0) return activityOrder;
        return left.id.compareTo(right.id);
      });
  }

  Future<List<ChatConversationSummary>> fetchConversationSummaries() async {
    final user = supabase.auth.currentUser!;
    final rows = await supabase
        .from('conversations')
        .select(conversationSummarySelect)
        .or('requester_id.eq.${user.id},helper_id.eq.${user.id}')
        .order('updated_at', ascending: false);

    return normalizeConversationRows(
      (rows as List<dynamic>).map(
        (row) => Map<String, dynamic>.from(row as Map),
      ),
      user.id,
    );
  }

  Stream<List<ChatConversationSummary>> watchConversationSummaries() {
    final controller = StreamController<List<ChatConversationSummary>>();
    StreamSubscription<List<Map<String, dynamic>>>? conversationSubscription;
    StreamSubscription<List<Map<String, dynamic>>>? messageSubscription;
    Timer? debounce;
    var isFetching = false;
    var shouldRefetch = false;

    Future<void> emit() async {
      if (controller.isClosed) {
        return;
      }
      if (isFetching) {
        shouldRefetch = true;
        return;
      }

      isFetching = true;
      try {
        controller.add(await fetchConversationSummaries());
      } catch (error, stackTrace) {
        if (!controller.isClosed) {
          controller.addError(error, stackTrace);
        }
      } finally {
        isFetching = false;
        if (shouldRefetch && !controller.isClosed) {
          shouldRefetch = false;
          unawaited(emit());
        }
      }
    }

    void scheduleEmit() {
      debounce?.cancel();
      debounce = Timer(const Duration(milliseconds: 150), () {
        unawaited(emit());
      });
    }

    controller.onListen = () {
      unawaited(emit());
      conversationSubscription = supabase
          .from('conversations')
          .stream(primaryKey: ['id'])
          .order('updated_at')
          .listen((_) => scheduleEmit(), onError: controller.addError);
      messageSubscription = supabase
          .from('messages')
          .stream(primaryKey: ['id'])
          .order('created_at')
          .listen((_) => scheduleEmit(), onError: controller.addError);
    };

    controller.onCancel = () async {
      debounce?.cancel();
      await conversationSubscription?.cancel();
      await messageSubscription?.cancel();
    };

    return controller.stream;
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
