import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase_client.dart';
import '../../core/validators.dart';
import '../../models/profile.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';
import '../../services/settings_preferences_service.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/primary_button.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _profileService = ProfileService();
  final _authService = AuthService();
  final _settingsService = SettingsPreferencesService();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _city = TextEditingController();
  final _district = TextEditingController();
  final _bio = TextEditingController();
  AppRole _role = AppRole.user;
  SettingsPreferences _settings = const SettingsPreferences();
  bool _loading = true;
  bool _saving = false;
  bool _savingSettings = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    for (final controller in [_name, _phone, _city, _district, _bio]) {
      controller.addListener(_refreshOverview);
    }
    _load();
  }

  @override
  void dispose() {
    for (final controller in [_name, _phone, _city, _district, _bio]) {
      controller.removeListener(_refreshOverview);
    }
    _name.dispose();
    _phone.dispose();
    _city.dispose();
    _district.dispose();
    _bio.dispose();
    super.dispose();
  }

  void _refreshOverview() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final profileFuture = _profileService.ensureCurrentProfile();
      final settingsFuture = _settingsService.load();
      final profile = await profileFuture;
      final settings = await settingsFuture;
      if (!mounted) return;
      setState(() {
        _name.text = profile.displayName;
        _phone.text = profile.phone ?? '';
        _city.text = profile.city ?? '';
        _district.text = profile.district ?? '';
        _bio.text = profile.bio ?? '';
        _role = profile.role == AppRole.admin ? AppRole.user : profile.role;
        _settings = settings;
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
      await _profileService.saveProfile(
        displayName: _name.text,
        role: _role,
        phone: _phone.text,
        city: _city.text,
        district: _district.text,
        bio: _bio.text,
      );

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: const Text('资料已保存'),
          action: _role == AppRole.helper
              ? SnackBarAction(
                  label: '完善帮手资料',
                  onPressed: () {
                    if (mounted) context.go('/helper-profile');
                  },
                )
              : null,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败：$error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _updateSettings(SettingsPreferences settings) async {
    setState(() {
      _settings = settings;
      _savingSettings = true;
    });
    try {
      await _settingsService.save(settings);
    } finally {
      if (mounted) setState(() => _savingSettings = false);
    }
  }

  Future<void> _signOut() async {
    await _authService.signOut();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: '我的设置',
      actions: [
        IconButton(
          tooltip: '重新加载',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh_outlined),
        ),
        IconButton(
          tooltip: '退出登录',
          onPressed: _signOut,
          icon: const Icon(Icons.logout),
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
              const Text('资料加载失败'),
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

    return Form(
      key: _formKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final profileColumn = Column(
            children: [
              _AccountOverview(
                displayName: _name.text,
                role: _role,
                city: _city.text,
                district: _district.text,
                completion: _profileCompletion,
              ),
              const SizedBox(height: 16),
              _buildProfileSection(context),
              const SizedBox(height: 16),
              _buildRoleSection(context),
            ],
          );

          final settingsColumn = Column(
            children: [
              _buildNotificationSection(context),
              const SizedBox(height: 16),
              _buildSecuritySection(context),
              const SizedBox(height: 16),
              _buildRulesSection(context),
            ],
          );

          final content = constraints.maxWidth >= 980
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 6, child: profileColumn),
                    const SizedBox(width: 16),
                    Expanded(flex: 4, child: settingsColumn),
                  ],
                )
              : Column(
                  children: [
                    profileColumn,
                    const SizedBox(height: 16),
                    settingsColumn,
                  ],
                );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [content],
          );
        },
      ),
    );
  }

  Widget _buildProfileSection(BuildContext context) {
    return _SettingsPanel(
      icon: Icons.manage_accounts_outlined,
      title: '账号资料',
      trailing: _saving
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      children: [
        TextFormField(
          controller: _name,
          decoration: const InputDecoration(
            labelText: '昵称',
            prefixIcon: Icon(Icons.badge_outlined),
          ),
          validator: AppValidators.displayName,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _phone,
          decoration: const InputDecoration(
            labelText: '电话',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
          keyboardType: TextInputType.phone,
          validator: AppValidators.optionalPhone,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _city,
                decoration: const InputDecoration(labelText: '城市'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _district,
                decoration: const InputDecoration(labelText: '地区'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _bio,
          maxLines: 3,
          maxLength: 160,
          decoration: const InputDecoration(
            labelText: '简介',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 4),
        PrimaryButton(
          label: '保存资料',
          icon: Icons.save_outlined,
          isLoading: _saving,
          onPressed: _save,
        ),
      ],
    );
  }

  Widget _buildRoleSection(BuildContext context) {
    return _SettingsPanel(
      icon: Icons.verified_user_outlined,
      title: '身份与能力',
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 420;
            return SegmentedButton<AppRole>(
              showSelectedIcon: false,
              segments: AppRole.selectable
                  .map(
                    (role) => ButtonSegment(
                      value: role,
                      label: Text(
                        role.label,
                        overflow: TextOverflow.ellipsis,
                      ),
                      icon: compact ? null : Icon(_iconForRole(role)),
                    ),
                  )
                  .toList(),
              selected: {_role},
              onSelectionChanged: _saving
                  ? null
                  : (value) => setState(() => _role = value.first),
            );
          },
        ),
        const SizedBox(height: 12),
        _ActionRow(
          icon: Icons.handyman_outlined,
          title: '帮手资料',
          subtitle: _role == AppRole.helper ? '可编辑技能、地区和认证' : '切换为帮手后可接单',
          action: TextButton.icon(
            onPressed: () => context.go('/helper-profile'),
            icon: const Icon(Icons.arrow_forward),
            label: const Text('打开'),
          ),
        ),
        const Divider(height: 1),
        _ActionRow(
          icon: Icons.storefront_outlined,
          title: '商家入驻',
          subtitle: '资料入口已预留',
          action: const _StatusChip(label: '即将开放'),
        ),
      ],
    );
  }

  Widget _buildNotificationSection(BuildContext context) {
    return _SettingsPanel(
      icon: Icons.notifications_none_outlined,
      title: '通知偏好',
      trailing: _savingSettings
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      children: [
        _SettingsSwitchTile(
          icon: Icons.assignment_outlined,
          title: '任务进度',
          subtitle: '报价、接单、完成状态',
          value: _settings.taskUpdates,
          onChanged: (value) =>
              _updateSettings(_settings.copyWith(taskUpdates: value)),
        ),
        const Divider(height: 1),
        _SettingsSwitchTile(
          icon: Icons.chat_bubble_outline,
          title: '聊天消息',
          subtitle: '任务双方的新消息',
          value: _settings.chatMessages,
          onChanged: (value) =>
              _updateSettings(_settings.copyWith(chatMessages: value)),
        ),
        const Divider(height: 1),
        _SettingsSwitchTile(
          icon: Icons.flash_on_outlined,
          title: '加急提醒',
          subtitle: '附近加急任务提示',
          value: _settings.urgentTasks,
          onChanged: (value) =>
              _updateSettings(_settings.copyWith(urgentTasks: value)),
        ),
        const Divider(height: 1),
        _SettingsSwitchTile(
          icon: Icons.campaign_outlined,
          title: '平台动态',
          subtitle: '活动、公告和商家消息',
          value: _settings.platformNews,
          onChanged: (value) =>
              _updateSettings(_settings.copyWith(platformNews: value)),
        ),
      ],
    );
  }

  Widget _buildSecuritySection(BuildContext context) {
    final email = supabase.auth.currentUser?.email ?? '未绑定邮箱';
    return _SettingsPanel(
      icon: Icons.lock_outline,
      title: '安全与隐私',
      children: [
        _ActionRow(
          icon: Icons.email_outlined,
          title: '登录邮箱',
          subtitle: email,
          action: const _StatusChip(label: '已保护'),
        ),
        const Divider(height: 1),
        _SettingsSwitchTile(
          icon: Icons.phone_locked_outlined,
          title: '隐藏电话',
          subtitle: '对非任务相关用户隐藏',
          value: _settings.hidePhone,
          onChanged: (value) =>
              _updateSettings(_settings.copyWith(hidePhone: value)),
        ),
        const Divider(height: 1),
        _SettingsSwitchTile(
          icon: Icons.location_on_outlined,
          title: '显示地区',
          subtitle: '任务匹配时展示城市和地区',
          value: _settings.showDistrict,
          onChanged: (value) =>
              _updateSettings(_settings.copyWith(showDistrict: value)),
        ),
      ],
    );
  }

  Widget _buildRulesSection(BuildContext context) {
    return _SettingsPanel(
      icon: Icons.policy_outlined,
      title: '平台规则',
      children: [
        _ActionRow(
          icon: Icons.report_gmailerrorred_outlined,
          title: '举报与客服',
          subtitle: '处理诈骗、骚扰和违规任务',
          action: TextButton.icon(
            onPressed: () => _showNotice('举报中心会在 Admin 审核模块完成后开放'),
            icon: const Icon(Icons.arrow_forward),
            label: const Text('查看'),
          ),
        ),
        const Divider(height: 1),
        _ActionRow(
          icon: Icons.privacy_tip_outlined,
          title: '隐私保护',
          subtitle: '实名认证和付款接口已预留',
          action: const _StatusChip(label: 'MVP'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _signOut,
          icon: const Icon(Icons.logout),
          label: const Text('退出登录'),
        ),
      ],
    );
  }

  void _showNotice(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  int get _profileCompletion {
    final fields = [
      _name.text.trim(),
      _phone.text.trim(),
      _city.text.trim(),
      _district.text.trim(),
      _bio.text.trim(),
    ];
    final filled = fields.where((value) => value.isNotEmpty).length;
    return (filled / fields.length * 100).round();
  }

  IconData _iconForRole(AppRole role) {
    return switch (role) {
      AppRole.user => Icons.person_outline,
      AppRole.helper => Icons.handyman_outlined,
      AppRole.merchant => Icons.storefront_outlined,
      AppRole.admin => Icons.admin_panel_settings_outlined,
    };
  }
}

class _AccountOverview extends StatelessWidget {
  const _AccountOverview({
    required this.displayName,
    required this.role,
    required this.city,
    required this.district,
    required this.completion,
  });

  final String displayName;
  final AppRole role;
  final String city;
  final String district;
  final int completion;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final location = [city.trim(), district.trim()]
        .where((value) => value.isNotEmpty)
        .join(' · ');
    final name = displayName.trim().isEmpty ? '新用户' : displayName.trim();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: colorScheme.onPrimary.withAlpha(24),
            child: Text(
              name.characters.first,
              style: TextStyle(
                color: colorScheme.onPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: colorScheme.onPrimary,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    _LightChip(label: role.label),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  location.isEmpty ? '完善城市和地区，方便本地匹配' : location,
                  style: TextStyle(color: colorScheme.onPrimary.withAlpha(220)),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: completion / 100,
                    backgroundColor: colorScheme.onPrimary.withAlpha(36),
                    valueColor: AlwaysStoppedAnimation(colorScheme.onPrimary),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '资料完整度 $completion%',
                  style: TextStyle(
                    color: colorScheme.onPrimary.withAlpha(230),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({
    required this.icon,
    required this.title,
    required this.children,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  const _SettingsSwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: Icon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          action,
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withAlpha(20),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _LightChip extends StatelessWidget {
  const _LightChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.onPrimary.withAlpha(34),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          style: TextStyle(
            color: colorScheme.onPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
