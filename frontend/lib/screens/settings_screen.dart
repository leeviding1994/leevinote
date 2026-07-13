import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:leevinote/design/app_theme.dart';
import 'package:leevinote/services/settings_service.dart';
import 'package:leevinote/services/auth_service.dart';
import 'package:leevinote/services/local_note_service.dart';
import 'package:leevinote/services/local_folder_service.dart';
import 'package:leevinote/widgets/widgets.dart';
import 'login_screen.dart';

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

    return AppScaffold.noPadding(
      appBar: AppAppBar(
        title: '设置',
        actions: [
          AppIconButton(
            icon: _syncing ? Icons.hourglass_empty : Icons.sync,
            onPressed: _syncing ? null : () => _manualSync(settings),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        children: [
          _buildSectionHeader('外观'),
          _buildThemeTile(settings),
          _buildThemeColorTile(settings),
          const SizedBox(height: AppSpacing.module),
          _buildSectionHeader('布局'),
          _buildModuleSortTile(settings),
          _buildModuleVisibilityTile(settings),
          const SizedBox(height: AppSpacing.module),
          _buildSectionHeader('其他'),
          _buildDangerTile(
            icon: Icons.cleaning_services_outlined,
            title: '清除本地笔记数据',
            subtitle: '删除所有本地缓存的笔记和文件夹',
            onTap: _confirmClearLocalData,
          ),
          _buildDangerTile(
            icon: Icons.restore_outlined,
            title: '恢复默认设置',
            subtitle: '所有自定义设置将被重置',
            onTap: () => _confirmReset(settings),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.sm,
        AppSpacing.pageHorizontal,
        AppSpacing.sm,
      ),
      child: Text(
        title,
        style: AppTypography.captionMediumLight(color: AppColors.brand),
      ),
    );
  }

  Widget _buildThemeTile(SettingsService settings) {
    final labels = {
      AppThemeMode.system: '跟随系统',
      AppThemeMode.light: '浅色',
      AppThemeMode.dark: '深色',
    };
    return AppListTile(
      leading: const Icon(Icons.dark_mode_outlined),
      title: '主题',
      subtitle: labels[settings.themeMode] ?? '',
      onTap: () => _showThemePicker(settings),
    );
  }

  void _showThemePicker(SettingsService settings) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('选择主题', style: AppTypography.h2Light()),
                const SizedBox(height: AppSpacing.lg),
                for (final mode in AppThemeMode.values)
                  AppListTile(
                    leading: Icon(
                      mode == AppThemeMode.dark
                          ? Icons.dark_mode_outlined
                          : mode == AppThemeMode.light
                              ? Icons.light_mode_outlined
                              : Icons.settings_brightness_outlined,
                    ),
                    title: {
                      AppThemeMode.system: '跟随系统',
                      AppThemeMode.light: '浅色',
                      AppThemeMode.dark: '深色',
                    }[mode]!,
                    trailing: settings.themeMode == mode
                        ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                        : null,
                    onTap: () {
                      settings.setThemeMode(mode);
                      Navigator.pop(ctx);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildThemeColorTile(SettingsService settings) {
    return AppListTile(
      leading: const Icon(Icons.color_lens_outlined),
      title: '主题颜色',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: settings.availableColors.map((c) {
          final isSelected = c.toARGB32() == settings.themeColor.toARGB32();
          return Container(
            width: 18,
            height: 18,
            margin: const EdgeInsets.only(left: AppSpacing.xs),
            decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(color: Theme.of(context).colorScheme.surface, width: 2)
                  : null,
              boxShadow: isSelected ? AppShadows.input : null,
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
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('选择主题颜色', style: AppTypography.h2Light()),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: settings.availableColors.map((c) {
                    final isSelected = c.toARGB32() == settings.themeColor.toARGB32();
                    return GestureDetector(
                      onTap: () {
                        settings.setThemeColor(c);
                        Navigator.pop(ctx);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(context).colorScheme.surface
                                : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: isSelected ? AppShadows.medium : null,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModuleSortTile(SettingsService settings) {
    return AppListTile(
      leading: const Icon(Icons.reorder),
      title: '模块排序',
      subtitle: settings.modules.map((m) => m.label).join(' / '),
      onTap: () => _showModuleSortSheet(settings),
    );
  }

  Widget _buildModuleVisibilityTile(SettingsService settings) {
    final visibleCount = settings.moduleVisibility.values.where((v) => v).length - 1;
    final totalCount = settings.moduleVisibility.length - 1;
    return AppListTile(
      leading: const Icon(Icons.visibility_outlined),
      title: '模块显示',
      subtitle: '$visibleCount / $totalCount 个模块显示（"我的"必显）',
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
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('模块显示', style: AppTypography.h2Light()),
                        const Spacer(),
                        AppButton.secondary(
                          label: '完成',
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '"我的"模块必显且固定在最后',
                      style: AppTypography.smallLight(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: moduleMap.length - 1,
                      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.listItemGap),
                      itemBuilder: (context, index) {
                        final module = moduleMap.values.elementAt(index);
                        if (module.id == 'profile') return const SizedBox.shrink();
                        final isVisible = visibility[module.id] ?? true;
                        return AppCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.sm,
                          ),
                          shadows: const [],
                          child: Row(
                            children: [
                              Icon(module.icon),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(child: Text(module.label, style: AppTypography.bodyLight())),
                              Switch(
                                value: isVisible,
                                onChanged: (value) {
                                  setSheetState(() {
                                    visibility[module.id] = value;
                                  });
                                  settings.setModuleVisibility(module.id, value);
                                },
                              ),
                            ],
                          ),
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
    final moduleMap = {for (final m in settings.allModules) m.id: m};
    final savedOrder = settings.moduleOrder.where((id) => moduleMap.containsKey(id)).toList();
    final defaultOrder = settings.allModules.map((m) => m.id).toList();
    final order = List<String>.from(
      savedOrder.length == defaultOrder.length ? savedOrder : defaultOrder,
    );
    if (savedOrder.length != defaultOrder.length) {
      // 本地/服务器数据异常，重置为默认顺序
      settings.setModuleOrder(defaultOrder);
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('模块排序', style: AppTypography.h2Light()),
                        const Spacer(),
                        AppButton.secondary(
                          label: '保存',
                          onPressed: () {
                            settings.setModuleOrder(order);
                            Navigator.pop(ctx);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '长按拖拽调整顺序',
                      style: AppTypography.smallLight(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: order.length,
                      itemBuilder: (context, index) {
                        final id = order[index];
                        final m = moduleMap[id];
                        if (m == null) return const SizedBox.shrink(key: ValueKey(''));
                        return AppCard(
                          key: ValueKey(id),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.md,
                          ),
                          shadows: const [],
                          child: Row(
                            children: [
                              Icon(m.icon),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(child: Text(m.label, style: AppTypography.bodyLight())),
                              const Icon(Icons.drag_handle, color: AppColors.tertiaryText),
                            ],
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

  Widget _buildDangerTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return AppListTile(
      leading: Icon(icon, color: AppColors.error),
      title: title,
      subtitle: subtitle,
      onTap: onTap,
    );
  }

  Future<void> _manualSync(SettingsService settings) async {
    final auth = context.read<AuthService>();
    if (!auth.isAuthenticated) {
      final loggedIn = await Navigator.push<bool>(
        context,
        AppPageRoute(builder: (_) => const LoginScreen()),
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
    AppDialog.confirm(
      context: context,
      title: '清除本地笔记数据',
      content: '将删除所有本地缓存的笔记和文件夹，同步后会重新从服务器拉取。确定继续吗？',
      confirmLabel: '清除',
      destructive: true,
    ).then((confirmed) async {
      if (confirmed != true || !mounted) return;
      final noteService = context.read<LocalNoteService>();
      final folderService = context.read<LocalFolderService>();
      await noteService.clearAll();
      await folderService.clearAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('本地数据已清除')),
        );
      }
    });
  }

  void _confirmReset(SettingsService settings) {
    AppDialog.confirm(
      context: context,
      title: '恢复默认设置',
      content: '所有自定义设置将被重置，确定继续吗？',
      confirmLabel: '恢复',
      destructive: true,
    ).then((confirmed) {
      if (confirmed != true || !mounted) return;
      settings.resetToDefault();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已恢复默认设置')),
      );
    });
  }
}
