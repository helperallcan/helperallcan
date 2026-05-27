import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_assets.dart';
import '../../core/validators.dart';
import '../../services/auth_service.dart';
import '../../widgets/primary_button.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _auth = AuthService();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _displayName = TextEditingController();
  bool _isRegister = false;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _displayName.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final result = _isRegister
          ? await _auth.signUp(
              email: _email.text,
              password: _password.text,
              displayName: _displayName.text,
            )
          : await _auth.signIn(
              email: _email.text,
              password: _password.text,
            );

      if (!mounted) return;
      if (result.needsEmailConfirmation) {
        setState(() => _isRegister = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('注册成功，请先到邮箱确认账号后再登录。')),
        );
        return;
      }

      context.go('/profile');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_isRegister ? '注册' : '登录'}失败：$error')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isRegister ? '创建账号' : '欢迎回来';
    final subtitle =
        _isRegister ? '注册后可以发布需求、报价接单和管理自己的本地服务资料。' : '登录后继续发布任务、聊天和查看帮手报价。';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _AuthArtwork(),
                    const SizedBox(height: 22),
                    Text(
                      'Helper',
                      style:
                          Theme.of(context).textTheme.headlineLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '本地生活互助、技能服务、找答案、找东西和找资源。',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 28),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(subtitle),
                    const SizedBox(height: 20),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('登录')),
                        ButtonSegment(value: true, label: Text('注册')),
                      ],
                      selected: {_isRegister},
                      onSelectionChanged: _isLoading
                          ? null
                          : (value) {
                              setState(() => _isRegister = value.first);
                            },
                    ),
                    const SizedBox(height: 20),
                    if (_isRegister) ...[
                      TextFormField(
                        controller: _displayName,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: '昵称',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        validator: AppValidators.displayName,
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _email,
                      decoration: const InputDecoration(
                        labelText: '邮箱',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: AppValidators.email,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      decoration: InputDecoration(
                        labelText: '密码',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword ? '显示密码' : '隐藏密码',
                          onPressed: () {
                            setState(
                                () => _obscurePassword = !_obscurePassword);
                          },
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      obscureText: _obscurePassword,
                      textInputAction: _isRegister
                          ? TextInputAction.next
                          : TextInputAction.done,
                      validator: AppValidators.password,
                      onFieldSubmitted: (_) {
                        if (!_isRegister) _submit();
                      },
                    ),
                    if (_isRegister) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirmPassword,
                        decoration: const InputDecoration(
                          labelText: '确认密码',
                          prefixIcon: Icon(Icons.lock_reset_outlined),
                        ),
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        validator: (value) => AppValidators.confirmPassword(
                          value,
                          _password.text,
                        ),
                        onFieldSubmitted: (_) => _submit(),
                      ),
                    ],
                    const SizedBox(height: 20),
                    PrimaryButton(
                      label: _isRegister ? '创建账号' : '登录',
                      icon: _isRegister
                          ? Icons.person_add_alt_1_outlined
                          : Icons.login,
                      isLoading: _isLoading,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthArtwork extends StatelessWidget {
  const _AuthArtwork();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xfff8fafc),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          AppAssets.authHero,
          height: 210,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
