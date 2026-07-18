import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:leevinote/design/app_theme.dart';
import 'package:leevinote/services/auth_service.dart';
import 'package:leevinote/widgets/widgets.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditing = false;
  final _nicknameController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _nicknameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return AppScaffold.noPadding(
      body: auth.isAuthenticated
          ? _buildAuthenticatedProfile(auth)
          : _buildUnauthenticatedProfile(),
    );
  }

  Widget _buildAuthenticatedProfile(AuthService auth) {
    _nicknameController.text = auth.nickname ?? '';
    _emailController.text = auth.email ?? '';

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      children: [
        Center(
          child: Column(
            children: [
              _buildAvatar(auth),
              const SizedBox(height: AppSpacing.lg),
              Text(
                auth.displayName,
                style: AppTypography.h2Light(),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                auth.username ?? '',
                style: AppTypography.captionLight(),
              ),
              const SizedBox(height: AppSpacing.lg),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
                child: AppButton.secondary(
                  label: _isEditing ? '保存' : '编辑资料',
                  icon: _isEditing ? Icons.save : Icons.edit,
                  onPressed: () {
                    if (_isEditing) _saveProfile(auth);
                    setState(() => _isEditing = !_isEditing);
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            boxShadow: Theme.of(context).brightness == Brightness.dark
                ? AppShadows.dark
                : AppShadows.light,
          ),
          child: Column(
            children: [
              if (_isEditing) ...[
                _buildTextField(
                  label: '昵称',
                  controller: _nicknameController,
                  icon: Icons.person_outline,
                ),
                const Divider(height: 1, indent: AppSpacing.pageHorizontal),
                _buildTextField(
                  label: '邮箱',
                  controller: _emailController,
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
              ] else ...[
                _buildInfoTile(
                  icon: Icons.person_outline,
                  title: '昵称',
                  value: auth.nickname ?? '未设置',
                ),
                const Divider(height: 1, indent: AppSpacing.pageHorizontal),
                _buildInfoTile(
                  icon: Icons.email_outlined,
                  title: '邮箱',
                  value: auth.email ?? '未设置',
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
          child: AppButton(
            label: '退出登录',
            destructive: true,
            icon: Icons.logout,
            onPressed: _confirmLogout,
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar(AuthService auth) {
    Uint8List? imageBytes;
    if (auth.avatarBase64 != null && auth.avatarBase64!.isNotEmpty) {
      try {
        imageBytes = base64Decode(auth.avatarBase64!);
      } catch (_) {
        imageBytes = null;
      }
    }

    return Stack(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            image: imageBytes != null
                ? DecorationImage(
                    image: MemoryImage(imageBytes),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: imageBytes == null
              ? Icon(
                  Icons.person,
                  size: 44,
                  color: Theme.of(context).colorScheme.primary,
                )
              : null,
        ),
        if (_isEditing)
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _pickAvatar,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                  boxShadow: AppShadows.light,
                ),
                child: const Icon(
                  Icons.camera_alt,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _pickAvatar() async {
    final auth = context.read<AuthService>();
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final bytes = result.files.first.bytes;
    if (bytes == null || bytes.isEmpty) return;

    final base64Str = base64Encode(bytes);
    if (!mounted) return;
    await auth.updateProfile(avatarBase64: base64Str);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('头像已更新')),
      );
    }
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: AppInput(
        controller: controller,
        hintText: label,
        prefixIcon: Icon(icon, size: 20),
        keyboardType: keyboardType,
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return AppListTile(
      leading: Icon(icon, color: AppColors.secondaryText),
      title: title,
      subtitle: value,
    );
  }

  Future<void> _saveProfile(AuthService auth) async {
    await auth.updateProfile(
      nickname: _nicknameController.text.trim(),
      email: _emailController.text.trim(),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('资料已保存')),
      );
    }
  }

  void _confirmLogout() {
    AppDialog.confirm(
      context: context,
      title: '退出登录',
      content: '确定要退出登录吗？',
      confirmLabel: '退出',
      destructive: true,
    ).then((confirmed) async {
      if (confirmed == true && mounted) {
        await context.read<AuthService>().logout();
        if (!mounted) return;
        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已退出登录')),
        );
      }
    });
  }

  Widget _buildUnauthenticatedProfile() {
    return AppEmptyState(
      icon: Icons.account_circle,
      title: '未登录',
      subtitle: '登录后可同步数据和管理个人信息',
      action: AppButton(
        label: '登录 / 注册',
        icon: Icons.login,
        onPressed: _goLogin,
      ),
    );
  }

  Future<void> _goLogin() async {
    final result = await Navigator.push<bool>(
      context,
      AppPageRoute(builder: (_) => const LoginScreen()),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('登录成功')),
      );
    }
  }
}
