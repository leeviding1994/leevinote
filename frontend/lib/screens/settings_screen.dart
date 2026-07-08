import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:leevinote/services/settings_service.dart';
import 'package:leevinote/services/auth_service.dart';
import 'package:leevinote/services/local_note_service.dart';
import 'package:leevinote/services/local_folder_service.dart';
import 'package:leevinote/screens/login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _syncing = false;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        actions: [
          IconButton(
            icon: _syncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            onPressed: _syncing ? null : () => _manualSync(settings),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          _buildSectionHeader('外观'),
          _buildThemeTile(settings),
          _buildThemeColorTile(settings),
          const Divider(),
          _buildSectionHeader('布局'),
          _buildModuleSortTile(settings),
          _buildModuleVisibilityTile(settings),
          const Divider(),
          _buildSectionHeader('其他'),
          ListTile(
            leading: const Icon(Icons.cleaning_services),
            title: const Text('清除本地笔记数据'),
            subtitle: const Text('删除所有本地缓存的笔记和文件夹'),
            onTap: () => _confirmClearLocalData(),
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('恢复默认设置'),
            onTap: () => _confirmReset(settings),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildThemeTile(SettingsService settings) {
    final labels = {
      AppThemeMode.system: '跟随系统',
      AppThemeMode.light: '浅色',
      AppThemeMode.dark: '深色',
    };
    return ListTile(
      leading: const Icon(Icons.dark_mode_outlined),
      title: const Text('主题'),
      subtitle: Text(labels[settings.themeMode] ?? ''),
      onTap: () => _showThemePicker(settings),
    );
  }

  void _showThemePicker(SettingsService settings) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('选择主题', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              for (final mode in AppThemeMode.values)
                RadioListTile<AppThemeMode>(
                  title: Text({
                    AppThemeMode.system: '跟随系统',
                    AppThemeMode.light: '浅色',
                    AppThemeMode.dark: '深色',
                  }[mode]!),
                  value: mode,
                  groupValue: settings.themeMode,
                  onChanged: (v) {
                    if (v != null) {
                      settings.setThemeMode(v);
                      Navigator.pop(ctx);
                    }
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThemeColorTile(SettingsService settings) {
    return ListTile(
      leading: const Icon(Icons.color_lens_outlined),
      title: const Text('主题颜色'),
      subtitle: Wrap(
        spacing: 4,
        children: settings.availableColors.map((c) {
          final isSelected = c.value == settings.themeColor.value;
          return Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
              boxShadow: isSelected
                  ? [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 4)]
                  : null,
            ),
          );
        }).toList(),
      ),
      onTap: () => _showColorPicker(settings),
    );
  }

  void _showColorPicker(SettingsService settings) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('选择主题颜色', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: settings.availableColors.map((c) {
                    final isSelected = c.value == settings.themeColor.value;
                    return GestureDetector(
                      onTap: () {
                        settings.setThemeColor(c);
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 3)
                              : Border.all(color: Colors.grey.shade300, width: 1),
                          boxShadow: isSelected
                              ? [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 8)]
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModuleSortTile(SettingsService settings) {
    return ListTile(
      leading: const Icon(Icons.reorder),
      title: const Text('模块排序'),
      subtitle: Text(settings.modules.map((m) => m.label).join(' / ')),
      onTap: () => _showModuleSortSheet(settings),
    );
  }

  Widget _buildModuleVisibilityTile(SettingsService settings) {
    final visibleCount = settings.moduleVisibility.values.where((v) => v).length - 1; // exclude profile
    final totalCount = settings.moduleVisibility.length - 1; // exclude profile
    return ListTile(
      leading: const Icon(Icons.visibility_outlined),
      title: const Text('模块显示'),
      subtitle: Text('$visibleCount / $totalCount 个模块显示（"我的"必显）'),
      onTap: () => _showModuleVisibilitySheet(settings),
    );
  }

  void _showModuleVisibilitySheet(SettingsService settings) {
    final visibility = Map<String, bool>.from(settings.moduleVisibility);
    final moduleMap = {for (final m in settings.allModules) m.id: m};
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('模块显示', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('完成'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('"我的"模块必显且固定在最后', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: moduleMap.length - 1, // exclude profile
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final module = moduleMap.values.elementAt(index);
                        if (module.id == 'profile') return const SizedBox.shrink();
                        final isVisible = visibility[module.id] ?? true;
                        return SwitchListTile(
                          secondary: Icon(module.icon),
                          title: Text(module.label),
                          value: isVisible,
                          onChanged: (value) {
                            setSheetState(() {
                              visibility[module.id] = value;
                            });
                            settings.setModuleVisibility(module.id, value);
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showModuleSortSheet(SettingsService settings) {
    final order = List<String>.from(settings.moduleOrder);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final moduleMap = {for (final m in settings.allModules) m.id: m};
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('模块排序', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        TextButton(
                          onPressed: () => settings.setModuleOrder(order),
                          child: const Text('保存'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('长按拖拽调整顺序', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: order.length,
                      itemBuilder: (context, index) {
                        final id = order[index];
                        final m = moduleMap[id]!;
                        return Card(
                          key: ValueKey(id),
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Icon(m.icon),
                            title: Text(m.label),
                            trailing: const Icon(Icons.drag_handle),
                          ),
                        );
                      },
                      onReorder: (oldIndex, newIndex) {
                        setSheetState(() {
                          if (newIndex > oldIndex) newIndex--;
                          final item = order.removeAt(oldIndex);
                          order.insert(newIndex, item);
                        });
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _manualSync(SettingsService settings) async {
    final auth = context.read<AuthService>();
    if (!auth.isAuthenticated) {
      final loggedIn = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      if (loggedIn != true) return;
    }
    setState(() => _syncing = true);
    try {
      await settings.syncToServer();
      await settings.syncFromServer();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('设置同步完成')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('同步失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  void _confirmClearLocalData() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清除本地笔记数据'),
        content: const Text('将删除所有本地缓存的笔记和文件夹，同步后会重新从服务器拉取。确定继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final noteService = context.read<LocalNoteService>();
              final folderService = context.read<LocalFolderService>();
              await noteService.clearAll();
              await folderService.clearAll();
              Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('本地数据已清除')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('清除'),
          ),
        ],
      ),
    );
  }

  void _confirmReset(SettingsService settings) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('恢复默认设置'),
        content: const Text('所有自定义设置将被重置，确定继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              settings.resetToDefault();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已恢复默认设置')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('恢复'),
          ),
        ],
      ),
    );
  }
}
