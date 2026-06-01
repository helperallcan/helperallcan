import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../services/notification_service.dart';
import '../../widgets/app_shell.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  Future<void> _markAllRead(
    BuildContext context,
    NotificationService service,
  ) async {
    await service.markAllRead();

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已全部标记为已读')),
    );
  }

  Future<void> _openNotification(
    BuildContext context,
    NotificationService service,
    AppNotification item,
  ) async {
    if (!item.isRead) {
      await service.markRead(item.id);
    }

    if (!context.mounted) {
      return;
    }

    final path = item.routePath;
    if (path != null) {
      context.go(path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = NotificationService();

    return AppShell(
      title: '通知',
      child: StreamBuilder<List<AppNotification>>(
        stream: service.watchNotifications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final notifications = snapshot.data ?? [];
          if (notifications.isEmpty) {
            return const Center(child: Text('暂无通知'));
          }
          final unreadCount = NotificationService.unreadNotificationCount(
            notifications,
            includeChat: true,
          );

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _NotificationSummary(
                  unreadCount: unreadCount,
                  onMarkAllRead: unreadCount == 0
                      ? null
                      : () => _markAllRead(context, service),
                );
              }

              final item = notifications[index - 1];
              return Card(
                child: ListTile(
                  leading: Icon(
                    item.isRead
                        ? Icons.notifications_none_outlined
                        : Icons.notifications_active_outlined,
                  ),
                  title: Text(item.title),
                  subtitle: Text('${item.body}\n${formatDate(item.createdAt)}'),
                  trailing: item.routePath == null
                      ? _UnreadDot(isVisible: !item.isRead)
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _UnreadDot(isVisible: !item.isRead),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                  isThreeLine: true,
                  onTap: item.isRead && item.routePath == null
                      ? null
                      : () => _openNotification(context, service, item),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _NotificationSummary extends StatelessWidget {
  const _NotificationSummary({
    required this.unreadCount,
    required this.onMarkAllRead,
  });

  final int unreadCount;
  final VoidCallback? onMarkAllRead;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              unreadCount > 0
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_none_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                unreadCount > 0 ? '$unreadCount 条未读通知' : '没有未读通知',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            TextButton.icon(
              onPressed: onMarkAllRead,
              icon: const Icon(Icons.done_all_outlined),
              label: const Text('全部已读'),
            ),
          ],
        ),
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
