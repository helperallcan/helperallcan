import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../models/helper_profile.dart';
import '../../models/offer.dart';
import '../../services/profile_service.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/primary_button.dart';

class HelperProfilePage extends StatefulWidget {
  const HelperProfilePage({super.key});

  @override
  State<HelperProfilePage> createState() => _HelperProfilePageState();
}

class _HelperProfilePageState extends State<HelperProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _service = ProfileService();
  final _headline = TextEditingController();
  final _bio = TextEditingController();
  final _skills = TextEditingController();
  final _areas = TextEditingController();
  final _rate = TextEditingController();
  HelperDashboardData? _dashboard;
  bool _loading = true;
  bool _saving = false;
  bool _requestingVerification = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _headline.dispose();
    _bio.dispose();
    _skills.dispose();
    _areas.dispose();
    _rate.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final dashboard = await _service.helperDashboard();
      if (!mounted) return;
      final helper = dashboard.profile;
      _headline.text = helper?.headline ?? '';
      _bio.text = helper?.bio ?? '';
      _skills.text = helper?.skills.join('，') ?? '';
      _areas.text = helper?.serviceAreas.join('，') ?? '';
      _rate.text = helper?.hourlyRate?.toStringAsFixed(0) ?? '';
      setState(() {
        _dashboard = dashboard;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _service.saveHelperProfile(
        headline: _headline.text,
        bio: _bio.text,
        skills: _splitTags(_skills.text),
        serviceAreas: _splitTags(_areas.text),
        hourlyRate: double.tryParse(_rate.text),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('帮手资料已保存')),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败：$error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _requestVerification() async {
    setState(() => _requestingVerification = true);
    try {
      await _service.requestHelperVerification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('认证申请已提交，等待后台审核')),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('申请失败：$error')),
      );
    } finally {
      if (mounted) setState(() => _requestingVerification = false);
    }
  }

  List<String> _splitTags(String value) {
    return value
        .split(RegExp(r'[,，]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: '我要做帮手',
      actions: [
        IconButton(
          tooltip: '浏览任务',
          onPressed: () => context.go('/tasks'),
          icon: const Icon(Icons.near_me_outlined),
        ),
      ],
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40),
              const SizedBox(height: 12),
              const Text('帮手工作台加载失败'),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    final dashboard =
        _dashboard ?? const HelperDashboardData(profile: null, workItems: []);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _HelperOverviewCard(
          helper: dashboard.profile,
          requestingVerification: _requestingVerification,
          onBrowseTasks: () => context.go('/tasks'),
          onRequestVerification: _requestVerification,
        ),
        const SizedBox(height: 12),
        _WorkHistoryCard(items: dashboard.workItems),
        const SizedBox(height: 12),
        _HelperProfileForm(
          formKey: _formKey,
          headline: _headline,
          bio: _bio,
          skills: _skills,
          areas: _areas,
          rate: _rate,
          saving: _saving,
          splitTags: _splitTags,
          onSave: _save,
        ),
      ],
    );
  }
}

class _HelperOverviewCard extends StatelessWidget {
  const _HelperOverviewCard({
    required this.helper,
    required this.requestingVerification,
    required this.onBrowseTasks,
    required this.onRequestVerification,
  });

  final HelperProfile? helper;
  final bool requestingVerification;
  final VoidCallback onBrowseTasks;
  final VoidCallback onRequestVerification;

  @override
  Widget build(BuildContext context) {
    final profile = helper;
    final status = profile?.verificationStatus ?? HelperVerificationStatus.none;
    final canRequest = profile != null && status.canRequest;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  child: Icon(
                    status == HelperVerificationStatus.approved
                        ? Icons.verified_outlined
                        : Icons.handyman_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile?.headline?.trim().isNotEmpty == true
                            ? profile!.headline!
                            : '先创建帮手资料',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profile == null
                            ? '完善技能、服务地区和说明后，就可以开始报价接单。'
                            : '管理接单状态、认证和历史报价。',
                      ),
                    ],
                  ),
                ),
                _VerificationChip(status: status),
              ],
            ),
            if (profile != null) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _MetricPill(
                    icon: Icons.task_alt_outlined,
                    label: '${profile.completedTasks} 单完成',
                  ),
                  _MetricPill(
                    icon: Icons.star_outline,
                    label: profile.ratingLabel,
                  ),
                  _MetricPill(
                    icon: Icons.place_outlined,
                    label: profile.serviceAreas.isEmpty
                        ? '未设置地区'
                        : profile.serviceAreas.take(2).join(' / '),
                  ),
                ],
              ),
              if (profile.verificationNote?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 10),
                Text(
                  profile.verificationNote!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: onBrowseTasks,
                  icon: const Icon(Icons.near_me_outlined),
                  label: const Text('浏览附近任务'),
                ),
                OutlinedButton.icon(
                  onPressed: canRequest && !requestingVerification
                      ? onRequestVerification
                      : null,
                  icon: requestingVerification
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.verified_user_outlined),
                  label: Text(_verificationActionLabel(profile, status)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _verificationActionLabel(
    HelperProfile? profile,
    HelperVerificationStatus status,
  ) {
    if (profile == null) return '先保存资料';
    return switch (status) {
      HelperVerificationStatus.none => '申请认证帮手',
      HelperVerificationStatus.rejected => '重新申请认证',
      HelperVerificationStatus.pending => '认证审核中',
      HelperVerificationStatus.approved => '已认证',
    };
  }
}

class _VerificationChip extends StatelessWidget {
  const _VerificationChip({required this.status});

  final HelperVerificationStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      HelperVerificationStatus.approved => Colors.green.shade700,
      HelperVerificationStatus.pending => Colors.blue.shade700,
      HelperVerificationStatus.rejected => Colors.red.shade700,
      HelperVerificationStatus.none => Theme.of(context).colorScheme.outline,
    };

    return Chip(
      visualDensity: VisualDensity.compact,
      side: BorderSide(color: color.withAlpha(80)),
      label: Text(status.label),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w700),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 6),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _WorkHistoryCard extends StatelessWidget {
  const _WorkHistoryCard({required this.items});

  final List<HelperWorkItem> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '历史接单',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              items.isEmpty ? '还没有报价记录，先去浏览附近任务。' : '查看最近报价、接单和完成记录。',
            ),
            if (items.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...items.map(
                (item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    item.offerStatus == OfferStatus.accepted
                        ? Icons.check_circle_outline
                        : Icons.local_offer_outlined,
                  ),
                  title: Text(item.task.title),
                  subtitle: Text(
                    '${item.task.status.label} · ${formatDate(item.createdAt)}',
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(formatMoney(item.amount)),
                      Text(item.offerStatus.label),
                    ],
                  ),
                  onTap: () => context.go('/tasks/${item.task.id}'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HelperProfileForm extends StatelessWidget {
  const _HelperProfileForm({
    required this.formKey,
    required this.headline,
    required this.bio,
    required this.skills,
    required this.areas,
    required this.rate,
    required this.saving,
    required this.splitTags,
    required this.onSave,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController headline;
  final TextEditingController bio;
  final TextEditingController skills;
  final TextEditingController areas;
  final TextEditingController rate;
  final bool saving;
  final List<String> Function(String value) splitTags;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '帮手资料',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              const Text('添加技能标签和服务地区，之后可以报价或接单。'),
              const SizedBox(height: 18),
              TextFormField(
                controller: headline,
                decoration: const InputDecoration(labelText: '一句话介绍'),
                validator: (value) =>
                    (value?.trim().isEmpty ?? true) ? '请填写介绍' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: bio,
                maxLines: 4,
                decoration: const InputDecoration(labelText: '服务说明'),
                validator: (value) =>
                    (value?.trim().length ?? 0) >= 10 ? null : '请至少填写 10 个字',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: skills,
                decoration: const InputDecoration(
                  labelText: '技能标签',
                  hintText: '维修，跑腿，电脑，清洁',
                ),
                validator: (value) =>
                    splitTags(value ?? '').isEmpty ? '请至少填写一个技能' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: areas,
                decoration: const InputDecoration(
                  labelText: '服务地区',
                  hintText: 'KL，Cheras，PJ',
                ),
                validator: (value) =>
                    splitTags(value ?? '').isEmpty ? '请至少填写一个地区' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: rate,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '参考时薪 RM（可选）'),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: '保存帮手资料',
                icon: Icons.save_outlined,
                isLoading: saving,
                onPressed: onSave,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
