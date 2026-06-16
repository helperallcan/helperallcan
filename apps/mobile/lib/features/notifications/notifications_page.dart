import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../services/notification_service.dart';
import '../../widgets/app_shell.dart';

enum _NotificationFilter { all, unread, chat, task }

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _service = NotificationService();
  late final Stream<List<AppNotification>> _notificationsStream =
      _service.watchNotifications();
  _NotificationFilter _filter = _NotificationFilter.all;

  Future<void> _markAllRead() async {
    await _service.markAllRead();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已全部标记为已读')),
    );
  }

  Future<void> _openNotification(AppNotification item) async {
    if (!item.isRead) {
      await _service.markRead(item.id);
    }

    if (!mounted) {
      return;
    }

    final path = item.routePath;
    if (path != null) {
      context.go(path);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('这条通知已标记为已读')),
    );
  }

  List<AppNotification> _visibleNotifications(List<AppNotification> items) {
    switch (_filter) {
      case _NotificationFilter.unread:
        return items.where((item) => !item.isRead).toList();
      case _NotificationFilter.chat:
        return items.where((item) => item.isChat).toList();
      case _NotificationFilter.task:
        return items.where((item) => !item.isChat && item.isTask).toList();
      case _NotificationFilter.all:
        return items;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: '通知中心',
      child: StreamBuilder<List<AppNotification>>(
        stream: _notificationsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final notifications = snapshot.data ?? [];
          final visibleNotifications = _visibleNotifications(notifications);
          final unreadCount = NotificationService.unreadNotificationCount(
            notifications,
            includeChat: true,
          );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _NotificationSummary(
                totalCount: notifications.length,
                unreadCount: unreadCount,
                chatCount: notifications.where((item) => item.isChat).length,
                taskCount: notifications
                    .where((item) => !item.isChat && item.isTask)
                    .length,
                onMarkAllRead: unreadCount == 0 ? null : _markAllRead,
              ),
              const SizedBox(height: 12),
              _NotificationFilterBar(
                selected: _filter,
                onChanged: (value) => setState(() => _filter = value),
              ),
              const SizedBox(height: 12),
              if (notifications.isEmpty)
                const _NotificationEmptyState(
                  icon: Icons.notifications_none_outlined,
                  title: '暂无通知',
                  message: '任务、聊天、报价和位置更新会显示在这里。',
                )
              else if (visibleNotifications.isEmpty)
                _NotificationEmptyState(
                  icon: Icons.filter_alt_off_outlined,
                  title: '这个分类暂时没有通知',
                  message: '切换到全部通知可以查看完整记录。',
                  actionLabel: '查看全部',
                  onAction: () =>
                      setState(() => _filter = _NotificationFilter.all),
                )
              else
                for (final item in visibleNotifications) ...[
                  _NotificationTile(
                    item: item,
                    onTap: () => _openNotification(item),
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

class _NotificationSummary extends StatelessWidget {
  const _NotificationSummary({
    required this.totalCount,
    required this.unreadCount,
    required this.chatCount,
    required this.taskCount,
    required this.onMarkAllRead,
  });

  final int totalCount;
  final int unreadCount;
  final int chatCount;
  final int taskCount;
  final VoidCallback? onMarkAllRead;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_none_outlined,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        unreadCount > 0 ? '$unreadCount 条未读通知' : '没有未读通知',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '共 $totalCount 条，聊天 $chatCount 条，任务 $taskCount 条',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: onMarkAllRead,
                  icon: const Icon(Icons.done_all_outlined),
                  label: const Text('全部已读'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationFilterBar extends StatelessWidget {
  const _NotificationFilterBar({
    required this.selected,
    required this.onChanged,
  });

  final _NotificationFilter selected;
  final ValueChanged<_NotificationFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<_NotificationFilter>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
            value: _NotificationFilter.all,
            icon: Icon(Icons.inbox_outlined),
            label: Text('全部'),
          ),
          ButtonSegment(
            value: _NotificationFilter.unread,
            icon: Icon(Icons.markunread_outlined),
            label: Text('未读'),
          ),
          ButtonSegment(
            value: _NotificationFilter.chat,
            icon: Icon(Icons.chat_bubble_outline),
            label: Text('聊天'),
          ),
          ButtonSegment(
            value: _NotificationFilter.task,
            icon: Icon(Icons.assignment_outlined),
            label: Text('任务'),
          ),
        ],
        selected: {selected},
        onSelectionChanged: (values) => onChanged(values.first),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.item,
    required this.onTap,
  });

  final AppNotification item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accentColor = _accentColor(context, item);
    final title = item.title.trim().isEmpty ? item.typeLabel : item.title;
    final body = item.body.trim().isEmpty ? '点击查看详情' : item.body;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: !item.isRead || item.routePath != null ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accentColor.withAlpha(24),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_iconFor(item), color: accentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _UnreadDot(isVisible: !item.isRead),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_outlined,
                          size: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${item.typeLabel} · ${formatDate(item.createdAt)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (item.routePath != null) ...[
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(AppNotification item) {
    if (item.isChat) return Icons.chat_bubble_outline;
    if (item.isTracking) return Icons.location_on_outlined;
    if (item.isOffer) return Icons.payments_outlined;
    if (item.isTask) return Icons.assignment_outlined;
    return Icons.notifications_none_outlined;
  }

  Color _accentColor(BuildContext context, AppNotification item) {
    if (item.isChat) return const Color(0xff2563eb);
    if (item.isTracking) return const Color(0xff0f766e);
    if (item.isOffer) return const Color(0xffb45309);
    if (item.isTask) return Theme.of(context).colorScheme.primary;
    return Theme.of(context).colorScheme.onSurfaceVariant;
  }
}

class _NotificationEmptyState extends StatelessWidget {
  const _NotificationEmptyState({
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

class _UnreadDot extends StatelessWidget {
  const _UnreadDot({required this.isVisible});

  final bool isVisible;

  @override
  Widget build(BuildContext context) {
    if (!isVisible) {
      return const SizedBox(width: 10, height: 10);
    }

    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}
