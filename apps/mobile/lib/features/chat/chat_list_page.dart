import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../models/conversation.dart';
import '../../models/task.dart';
import '../../services/chat_service.dart';
import '../../widgets/app_shell.dart';

enum _ChatFilter { all, unread, active }

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final _service = ChatService();
  late final Stream<List<ChatConversationSummary>> _conversationStream =
      _service.watchConversationSummaries();
  _ChatFilter _filter = _ChatFilter.all;

  List<ChatConversationSummary> _visibleConversations(
    List<ChatConversationSummary> conversations,
  ) {
    switch (_filter) {
      case _ChatFilter.unread:
        return conversations
            .where((conversation) => conversation.hasUnread)
            .toList();
      case _ChatFilter.active:
        return conversations
            .where((conversation) => conversation.isActiveTask)
            .toList();
      case _ChatFilter.all:
        return conversations;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: '聊天',
      child: StreamBuilder<List<ChatConversationSummary>>(
        stream: _conversationStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final conversations = snapshot.data ?? [];
          final visibleConversations = _visibleConversations(conversations);
          final unreadCount = conversations
              .where((conversation) => conversation.hasUnread)
              .length;
          final activeCount = conversations
              .where((conversation) => conversation.isActiveTask)
              .length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ChatSummaryCard(
                totalCount: conversations.length,
                unreadCount: unreadCount,
                activeCount: activeCount,
              ),
              const SizedBox(height: 12),
              _ChatFilterBar(
                selected: _filter,
                onChanged: (value) => setState(() => _filter = value),
              ),
              const SizedBox(height: 12),
              if (conversations.isEmpty)
                const _ChatEmptyState(
                  icon: Icons.chat_bubble_outline,
                  title: '暂无聊天',
                  message: '选择帮手后，任务相关聊天会显示在这里。',
                )
              else if (visibleConversations.isEmpty)
                _ChatEmptyState(
                  icon: Icons.filter_alt_off_outlined,
                  title: '这个分类暂时没有会话',
                  message: '切换到全部聊天可以查看完整记录。',
                  actionLabel: '查看全部',
                  onAction: () => setState(() => _filter = _ChatFilter.all),
                )
              else
                for (final conversation in visibleConversations) ...[
                  _ConversationTile(
                    conversation: conversation,
                    onTap: () => context.go('/chat/${conversation.id}'),
                  ),
                  const SizedBox(height: 10),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _ChatSummaryCard extends StatelessWidget {
  const _ChatSummaryCard({
    required this.totalCount,
    required this.unreadCount,
    required this.activeCount,
  });

  final int totalCount;
  final int unreadCount;
  final int activeCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: colorScheme.primary.withAlpha(24),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                unreadCount > 0
                    ? Icons.mark_chat_unread_outlined
                    : Icons.chat_bubble_outline,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    unreadCount > 0 ? '$unreadCount 个会话有新消息' : '没有未读聊天',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '共 $totalCount 个会话，进行中 $activeCount 个',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatFilterBar extends StatelessWidget {
  const _ChatFilterBar({
    required this.selected,
    required this.onChanged,
  });

  final _ChatFilter selected;
  final ValueChanged<_ChatFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<_ChatFilter>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
            value: _ChatFilter.all,
            icon: Icon(Icons.inbox_outlined),
            label: Text('全部'),
          ),
          ButtonSegment(
            value: _ChatFilter.unread,
            icon: Icon(Icons.markunread_outlined),
            label: Text('未读'),
          ),
          ButtonSegment(
            value: _ChatFilter.active,
            icon: Icon(Icons.work_history_outlined),
            label: Text('进行中'),
          ),
        ],
        selected: {selected},
        onSelectionChanged: (values) => onChanged(values.first),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.onTap,
  });

  final ChatConversationSummary conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasUnread = conversation.hasUnread;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PeerAvatar(conversation: conversation),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation.peerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatDate(conversation.lastActivityAt),
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      conversation.taskTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontWeight:
                            hasUnread ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      conversation.lastMessagePreview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _StatusChip(status: conversation.taskStatus),
                        _MetaChip(
                          icon: Icons.place_outlined,
                          label: conversation.locationLabel,
                        ),
                        if (conversation.isTaskUrgent)
                          const _MetaChip(
                            icon: Icons.bolt_outlined,
                            label: '加急',
                            isUrgent: true,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  if (conversation.unreadCount > 0)
                    _UnreadCount(count: conversation.unreadCount),
                  const SizedBox(height: 8),
                  Icon(Icons.chevron_right,
                      color: colorScheme.onSurfaceVariant),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeerAvatar extends StatelessWidget {
  const _PeerAvatar({required this.conversation});

  final ChatConversationSummary conversation;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final initial = conversation.peerName.trim().isEmpty
        ? '?'
        : conversation.peerName.trim().substring(0, 1);

    return CircleAvatar(
      radius: 22,
      backgroundColor: colorScheme.primary.withAlpha(24),
      foregroundColor: colorScheme.primary,
      child: Text(
        initial,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final TaskStatus status;

  @override
  Widget build(BuildContext context) {
    return _MetaChip(
      icon: status.isClosed ? Icons.flag_outlined : Icons.pending_actions,
      label: status.label,
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    this.isUrgent = false,
  });

  final IconData icon;
  final String label;
  final bool isUrgent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isUrgent ? const Color(0xffb45309) : colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _UnreadCount extends StatelessWidget {
  const _UnreadCount({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : count.toString();
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: colorScheme.error,
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: colorScheme.onError,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}

class _ChatEmptyState extends StatelessWidget {
  const _ChatEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 42),
      child: Column(
        children: [
          Icon(icon, size: 38, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.inbox_outlined),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
