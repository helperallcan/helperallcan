import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_assets.dart';
import '../../models/task.dart';
import '../../services/profile_service.dart';
import '../../widgets/app_shell.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final profileFuture = ProfileService().currentProfile();

    return AppShell(
      title: 'Helper',
      actions: [
        IconButton(
          tooltip: '我的资料',
          onPressed: () => context.go('/profile'),
          icon: const Icon(Icons.person_outline),
        ),
      ],
      child: FutureBuilder(
        future: profileFuture,
        builder: (context, snapshot) {
          final name = snapshot.data?.displayName ?? '你好';
          return LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 920;
              return ListView(
                padding: EdgeInsets.fromLTRB(
                  wide ? 28 : 16,
                  wide ? 28 : 16,
                  wide ? 28 : 16,
                  32,
                ),
                children: [
                  _WelcomeHeader(name: name, wide: wide),
                  const SizedBox(height: 22),
                  _EntryGrid(
                    entries: [
                      _Entry(
                        title: '我要找帮手',
                        subtitle: '跑腿、维修、清洁、临时协助',
                        icon: Icons.handshake_outlined,
                        color: const Color(0xff0f766e),
                        onTap: () =>
                            context.go('/tasks/new/${TaskKind.help.value}'),
                      ),
                      _Entry(
                        title: '我要找答案',
                        subtitle: '学习、职场、电脑手机问题',
                        icon: Icons.lightbulb_outline,
                        color: const Color(0xff2563eb),
                        onTap: () =>
                            context.go('/tasks/new/${TaskKind.answer.value}'),
                      ),
                      _Entry(
                        title: '我要找东西',
                        subtitle: '失物、二手、本地线索',
                        icon: Icons.search_outlined,
                        color: const Color(0xffb45309),
                        onTap: () =>
                            context.go('/tasks/new/${TaskKind.findItem.value}'),
                      ),
                      _Entry(
                        title: '我要做帮手',
                        subtitle: '创建技能资料，浏览附近任务',
                        icon: Icons.work_outline,
                        color: const Color(0xff7c3aed),
                        onTap: () => context.go('/helper-profile'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _QuickLinks(wide: wide),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader({required this.name, required this.wide});

  final String name;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final titleStyle = wide
        ? Theme.of(context).textTheme.displaySmall
        : Theme.of(context).textTheme.headlineSmall;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: EdgeInsets.all(wide ? 28 : 18),
        child: wide
            ? Row(
                children: [
                  Expanded(
                      flex: 3,
                      child: _WelcomeCopy(name: name, style: titleStyle)),
                  const SizedBox(width: 24),
                  const Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _WelcomeArt(height: 188),
                        SizedBox(height: 16),
                        _WelcomeActions(alignment: WrapAlignment.end),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _WelcomeCopy(name: name, style: titleStyle),
                  const SizedBox(height: 16),
                  const _WelcomeArt(height: 156),
                  const SizedBox(height: 18),
                  const _WelcomeActions(alignment: WrapAlignment.start),
                ],
              ),
      ),
    );
  }
}

class _WelcomeArt extends StatelessWidget {
  const _WelcomeArt({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xfff8fafc),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          AppAssets.homeHero,
          height: height,
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),
      ),
    );
  }
}

class _WelcomeCopy extends StatelessWidget {
  const _WelcomeCopy({required this.name, required this.style});

  final String name;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$name，需要什么帮忙？',
          style: style?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '发布需求、找本地帮手、报价聊天并确认完成。',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _WelcomeActions extends StatelessWidget {
  const _WelcomeActions({required this.alignment});

  final WrapAlignment alignment;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: alignment,
      children: [
        FilledButton.icon(
          onPressed: () => context.go('/tasks/new/${TaskKind.help.value}'),
          icon: const Icon(Icons.add),
          label: const Text('发布需求'),
        ),
        OutlinedButton.icon(
          onPressed: () => context.go('/tasks'),
          icon: const Icon(Icons.near_me_outlined),
          label: const Text('浏览任务'),
        ),
      ],
    );
  }
}

class _EntryGrid extends StatelessWidget {
  const _EntryGrid({required this.entries});

  final List<_Entry> entries;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 980
            ? 4
            : constraints.maxWidth > 560
                ? 2
                : 1;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: columns == 4
              ? 1.38
              : columns == 2
                  ? 2.15
                  : 3.2,
          children: entries.map((entry) => _EntryCard(entry: entry)).toList(),
        );
      },
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry});

  final _Entry entry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 150;
          return InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: entry.onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: compact
                  ? _CompactEntry(entry: entry)
                  : _ExpandedEntry(entry: entry),
            ),
          );
        },
      ),
    );
  }
}

class _ExpandedEntry extends StatelessWidget {
  const _ExpandedEntry({required this.entry});

  final _Entry entry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _EntryIcon(entry: entry),
            const Spacer(),
            Icon(
              Icons.arrow_forward,
              size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
        const Spacer(),
        Text(
          entry.title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          entry.subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _CompactEntry extends StatelessWidget {
  const _CompactEntry({required this.entry});

  final _Entry entry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _EntryIcon(entry: entry),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                entry.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              Text(entry.subtitle,
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        const Icon(Icons.chevron_right),
      ],
    );
  }
}

class _EntryIcon extends StatelessWidget {
  const _EntryIcon({required this.entry});

  final _Entry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: entry.color.withAlpha(24),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(entry.icon, color: entry.color),
    );
  }
}

class _QuickLinks extends StatelessWidget {
  const _QuickLinks({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    final links = [
      _QuickLink(
        title: '浏览附近任务',
        subtitle: '按分类、地点、最新和加急筛选',
        icon: Icons.near_me_outlined,
        onTap: () => context.go('/tasks'),
      ),
      _QuickLink(
        title: '申请认证帮手',
        subtitle: '提升信任度，后续可接入会员体系',
        icon: Icons.verified_user_outlined,
        onTap: () => context.go('/helper-profile'),
      ),
    ];

    if (wide) {
      return Row(
        children: [
          for (var i = 0; i < links.length; i++) ...[
            Expanded(child: _QuickLinkTile(link: links[i])),
            if (i != links.length - 1) const SizedBox(width: 12),
          ],
        ],
      );
    }

    return Column(
      children: [
        for (var i = 0; i < links.length; i++) ...[
          _QuickLinkTile(link: links[i]),
          if (i != links.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _QuickLinkTile extends StatelessWidget {
  const _QuickLinkTile({required this.link});

  final _QuickLink link;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(link.icon),
        title: Text(link.title),
        subtitle: Text(link.subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: link.onTap,
      ),
    );
  }
}

class _Entry {
  const _Entry({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

class _QuickLink {
  const _QuickLink({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
}
