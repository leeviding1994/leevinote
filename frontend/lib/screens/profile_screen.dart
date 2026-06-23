import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:leevinote/services/auth_service.dart';
import 'package:leevinote/screens/login_screen.dart';

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

    return Scaffold(
      body: auth.isAuthenticated
          ? _buildAuthenticatedProfile(auth)
          : _buildUnauthenticatedProfile(),
    );
  }

  Widget _buildAuthenticatedProfile(AuthService auth) {
    final theme = Theme.of(context);
    _nicknameController.text = auth.nickname ?? '';
    _emailController.text = auth.email ?? '';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 头像区域
        Center(
          child: Column(
            children: [
              const SizedBox(height: 16),
              _buildAvatar(auth),
              const SizedBox(height: 12),
              Text(
                auth.displayName,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                auth.username ?? '',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),
              // 编辑/保存按钮
              OutlinedButton.icon(
                onPressed: () {
                  if (_isEditing) {
                    _saveProfile(auth);
                  }
                  setState(() => _isEditing = !_isEditing);
                },
                icon: Icon(_isEditing ? Icons.save : Icons.edit),
                label: Text(_isEditing ? '保存' : '编辑资料'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Divider(),
        // 信息列表
        if (_isEditing) ...[
          _buildTextField(
            label: '昵称',
            controller: _nicknameController,
            icon: Icons.person_outline,
          ),
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
          _buildInfoTile(
            icon: Icons.email_outlined,
            title: '邮箱',
            value: auth.email ?? '未设置',
          ),
        ],
        const SizedBox(height: 24),
        const Divider(),
        // 退出登录
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: const Text('退出登录', style: TextStyle(color: Colors.red)),
          onTap: () => _confirmLogout(),
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
        CircleAvatar(
          radius: 48,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          backgroundImage: imageBytes != null ? MemoryImage(imageBytes) : null,
          child: imageBytes == null
              ? Icon(
                  Icons.person,
                  size: 48,
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
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
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
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final bytes = result.files.first.bytes;
    if (bytes == null || bytes.isEmpty) return;

    // 压缩提示：如果图片太大，简单裁剪
    final base64Str = base64Encode(bytes);
    await context.read<AuthService>().updateProfile(avatarBase64: base64Str);
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
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey.shade600),
      title: Text(title),
      subtitle: Text(value),
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              context.read<AuthService>().logout();
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }

  Widget _buildUnauthenticatedProfile() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_circle,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              '未登录',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '登录后可同步数据和管理个人信息',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: () => _goLogin(),
                icon: const Icon(Icons.login),
                label: const Text('登录 / 注册'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _goLogin() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('登录成功')),
      );
    }
  }
}
