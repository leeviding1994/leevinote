import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:leevinote/design/app_theme.dart';
import 'package:leevinote/services/auth_service.dart';
import 'package:leevinote/widgets/widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppScaffold.noPadding(
      appBar: AppAppBar(
        leading: AppIconButton(
          icon: Icons.arrow_back,
          onPressed: () => Navigator.pop(context, false),
        ),
        title: _isLogin ? '登录' : '注册',
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/icon.png',
                width: 80,
                height: 80,
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'LeeviNote',
                style: AppTypography.h1Light(color: theme.colorScheme.onSurface),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '你的多功能笔记平台',
                style: AppTypography.captionLight(),
              ),
              const SizedBox(height: AppSpacing.xxl),
              AppInput(
                controller: _usernameController,
                hintText: '用户名',
                prefixIcon: const Icon(Icons.person_outline, size: 20),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.component),
              if (!_isLogin) ...[
                AppInput(
                  controller: _emailController,
                  hintText: '邮箱',
                  prefixIcon: const Icon(Icons.email_outlined, size: 20),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppSpacing.component),
              ],
              AppInput(
                controller: _passwordController,
                hintText: '密码',
                prefixIcon: const Icon(Icons.lock_outline, size: 20),
                obscureText: true,
                textInputAction: TextInputAction.done,
                onEditingComplete: _handleSubmit,
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: _isLogin ? '登录' : '注册',
                isLoading: _isLoading,
                onPressed: _handleSubmit,
              ),
              const SizedBox(height: AppSpacing.component),
              AppButton.secondary(
                label: _isLogin ? '没有账号？注册' : '已有账号？登录',
                onPressed: () => setState(() => _isLogin = !_isLogin),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    setState(() => _isLoading = true);
    final auth = context.read<AuthService>();
    try {
      if (_isLogin) {
        await auth.login(
          _usernameController.text,
          _passwordController.text,
        );
      } else {
        await auth.signup(
          _usernameController.text,
          _passwordController.text,
          _emailController.text.isEmpty ? null : _emailController.text,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    super.dispose();
  }
}
