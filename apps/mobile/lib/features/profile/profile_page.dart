import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/validators.dart';
import '../../models/profile.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';
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
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _city = TextEditingController();
  final _district = TextEditingController();
  final _bio = TextEditingController();
  AppRole _role = AppRole.user;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _city.dispose();
    _district.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final profile = await _profileService.ensureCurrentProfile();
      if (!mounted) return;
      setState(() {
        _name.text = profile.displayName;
        _phone.text = profile.phone ?? '';
        _city.text = profile.city ?? '';
        _district.text = profile.district ?? '';
        _bio.text = profile.bio ?? '';
        _role = profile.role == AppRole.admin ? AppRole.user : profile.role;
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

  Future<void> _signOut() async {
    await _authService.signOut();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: '我的资料',
      actions: [
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
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '选择身份',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          SegmentedButton<AppRole>(
            showSelectedIcon: false,
            segments: AppRole.selectable
                .map(
                  (role) => ButtonSegment(
                    value: role,
                    label: Text(role.label),
                    icon: Icon(_iconForRole(role)),
                  ),
                )
                .toList(),
            selected: {_role},
            onSelectionChanged:
                _saving ? null : (value) => setState(() => _role = value.first),
          ),
          const SizedBox(height: 20),
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
          const SizedBox(height: 20),
          PrimaryButton(
            label: '保存资料',
            icon: Icons.save_outlined,
            isLoading: _saving,
            onPressed: _save,
          ),
        ],
      ),
    );
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
