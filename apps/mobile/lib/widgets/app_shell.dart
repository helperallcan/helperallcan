import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/notification_service.dart';
import 'unread_icon_badge.dart';

class AppShellBreakpoints {
  static const desktopWidth = 900.0;

  static bool isDesktop(double width) => width >= desktopWidth;
}

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.showNotificationAction = true,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;
  final bool showNotificationAction;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final location = GoRouterState.of(context).matchedLocation;
        final index = _indexForLocation(location);
        final effectiveActions = <Widget>[
          if (showNotificationAction) const _AppShellNotificationButton(),
          ...?actions,
        ];

        if (AppShellBreakpoints.isDesktop(constraints.maxWidth)) {
          return _DesktopShell(
            title: title,
            selectedIndex: index,
            actions: effectiveActions,
            child: child,
          );
        }

        return _MobileShell(
          title: title,
          selectedIndex: index,
          actions: effectiveActions,
          child: child,
        );
      },
    );
  }

  int _indexForLocation(String location) {
    if (location.startsWith('/tasks')) return 1;
    if (location.startsWith('/chat') || location.startsWith('/chats')) {
      return 2;
    }
    if (location.startsWith('/helper-profile')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }
}

class _AppShellNotificationButton extends StatelessWidget {
  const _AppShellNotificationButton();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UnreadSummary>(
      stream: NotificationService().watchUnreadSummary(),
      builder: (context, snapshot) {
        final summary = snapshot.data ??
            const UnreadSummary(
              notifications: 0,
              chats: 0,
            );
        final count = summary.total;

        return IconButton(
          tooltip: summary.tooltipLabel,
          onPressed: () => context.go('/notifications'),
          icon: UnreadIconBadge(
            icon: count > 0
                ? Icons.notifications_active_outlined
                : Icons.notifications_none_outlined,
            count: count,
          ),
        );
      },
    );
  }
}

class _MobileShell extends StatelessWidget {
  const _MobileShell({
    required this.title,
    required this.selectedIndex,
    required this.child,
    this.actions,
  });

  final String title;
  final int selectedIndex;
  final Widget child;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: actions,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: child,
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) => _goToIndex(context, index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: '首页'),
          NavigationDestination(
              icon: Icon(Icons.list_alt_outlined), label: '任务'),
          NavigationDestination(
            icon: _UnreadChatIcon(icon: Icons.chat_bubble_outline),
            selectedIcon: _UnreadChatIcon(icon: Icons.chat_bubble),
            label: '聊天',
          ),
          NavigationDestination(
              icon: Icon(Icons.handyman_outlined), label: '帮手'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: '我的'),
        ],
      ),
    );
  }
}

class _UnreadChatIcon extends StatelessWidget {
  const _UnreadChatIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: NotificationService().watchUnreadChatCount(),
      builder: (context, snapshot) {
        return UnreadIconBadge(
          icon: icon,
          count: snapshot.data ?? 0,
        );
      },
    );
  }
}

class _DesktopShell extends StatelessWidget {
  const _DesktopShell({
    required this.title,
    required this.selectedIndex,
    required this.child,
    this.actions,
  });

  final String title;
  final int selectedIndex;
  final Widget child;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            _DesktopSidebar(selectedIndex: selectedIndex),
            const VerticalDivider(width: 1),
            Expanded(
              child: Column(
                children: [
                  _DesktopTopBar(title: title, actions: actions),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1180),
                        child: child,
                      ),
                    ),
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

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({required this.selectedIndex});

  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 248,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child:
                      const Icon(Icons.handshake_outlined, color: Colors.white),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Helper',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      SizedBox(height: 2),
                      Text('本地互助平台', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            _NavItem(
              index: 0,
              selectedIndex: selectedIndex,
              icon: Icons.home_outlined,
              selectedIcon: Icons.home,
              label: '首页',
            ),
            _NavItem(
              index: 1,
              selectedIndex: selectedIndex,
              icon: Icons.list_alt_outlined,
              selectedIcon: Icons.list_alt,
              label: '任务大厅',
            ),
            _UnreadChatNavItem(selectedIndex: selectedIndex),
            _NavItem(
              index: 3,
              selectedIndex: selectedIndex,
              icon: Icons.handyman_outlined,
              selectedIcon: Icons.handyman,
              label: '做帮手',
            ),
            _NavItem(
              index: 4,
              selectedIndex: selectedIndex,
              icon: Icons.person_outline,
              selectedIcon: Icons.person,
              label: '我的资料',
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: () => context.go('/tasks/new/help'),
              icon: const Icon(Icons.add),
              label: const Text('发布需求'),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnreadChatNavItem extends StatelessWidget {
  const _UnreadChatNavItem({required this.selectedIndex});

  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: NotificationService().watchUnreadChatCount(),
      builder: (context, snapshot) {
        return _NavItem(
          index: 2,
          selectedIndex: selectedIndex,
          icon: Icons.chat_bubble_outline,
          selectedIcon: Icons.chat_bubble,
          label: '聊天中心',
          badgeCount: snapshot.data ?? 0,
        );
      },
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.index,
    required this.selectedIndex,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.badgeCount = 0,
  });

  final int index;
  final int selectedIndex;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final selected = index == selectedIndex;
    final colorScheme = Theme.of(context).colorScheme;
    final iconColor =
        selected ? colorScheme.primary : colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _goToIndex(context, index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected
                ? colorScheme.primary.withAlpha(24)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              IconTheme(
                data: IconThemeData(color: iconColor),
                child: UnreadIconBadge(
                  icon: selected ? selectedIcon : icon,
                  count: badgeCount,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color:
                        selected ? colorScheme.primary : colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopTopBar extends StatelessWidget {
  const _DesktopTopBar({required this.title, this.actions});

  final String title;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom:
              BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const Spacer(),
          if (actions != null) ...actions!,
        ],
      ),
    );
  }
}

void _goToIndex(BuildContext context, int index) {
  switch (index) {
    case 0:
      context.go('/');
      break;
    case 1:
      context.go('/tasks');
      break;
    case 2:
      context.go('/chats');
      break;
    case 3:
      context.go('/helper-profile');
      break;
    case 4:
      context.go('/profile');
      break;
  }
}
