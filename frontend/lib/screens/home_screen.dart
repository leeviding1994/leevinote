import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:leevinote/design/app_theme.dart';
import 'package:leevinote/models/folder.dart';
import 'package:leevinote/screens/notes_screen.dart';
import 'package:leevinote/screens/alarms_screen.dart';
import 'package:leevinote/screens/music_screen.dart';
import 'package:leevinote/screens/videos_screen.dart';
import 'package:leevinote/screens/schedules_screen.dart';
import 'package:leevinote/screens/transactions_screen.dart';
import 'package:leevinote/screens/profile_screen.dart';
import 'package:leevinote/screens/settings_screen.dart';
import 'package:leevinote/services/auth_service.dart';
import 'package:leevinote/services/settings_service.dart';
import 'package:leevinote/services/local_folder_service.dart';
import 'package:leevinote/widgets/widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final _notesKey = GlobalKey<NotesScreenState>();
  final _alarmsKey = GlobalKey<AlarmsScreenState>();
  final _musicKey = GlobalKey<MusicScreenState>();
  final _videosKey = GlobalKey<VideosScreenState>();
  final _schedulesKey = GlobalKey<SchedulesScreenState>();
  final _transactionsKey = GlobalKey<TransactionsScreenState>();
  final Set<String> _expandedFolders = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notesKey.currentState?.onFolderChanged = () => setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final settings = context.watch<SettingsService>();
    final modules = settings.modules;
    final ids = modules.map((m) => m.id).toList();

    if (_currentIndex >= ids.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _currentIndex = 0);
      });
    }

    final selectedModuleId = ids.isNotEmpty ? ids[_currentIndex] : 'notes';
    final isNotes = selectedModuleId == 'notes';
    final isSchedules = selectedModuleId == 'schedules';
    final isTransactions = selectedModuleId == 'transactions';
    final isProfile = selectedModuleId == 'profile';

    final title = isNotes && _notesKey.currentState != null
        ? _notesKey.currentState!.buildBreadcrumbWidget()
        : isSchedules
            ? GestureDetector(
                onTap: () => _schedulesKey.currentState?.resetToDayView(),
                child: Text(modules[_currentIndex].label),
              )
            : Text(modules[_currentIndex].label);

    final actions = <Widget>[
      if (isNotes)
        AppIconButton(
          icon: Icons.sync,
          tooltip: auth.isAuthenticated ? '同步' : '登录并同步',
          onPressed: () => _notesKey.currentState?.sync(),
        ),
      if (isSchedules) ...[
        AppIconButton(
          icon: Icons.search,
          tooltip: '搜索日程',
          onPressed: () => _schedulesKey.currentState?.toggleSearch(),
        ),
        AppIconButton(
          icon: Icons.sync,
          tooltip: auth.isAuthenticated ? '同步' : '登录并同步',
          onPressed: () => _schedulesKey.currentState?.sync(),
        ),
      ],
      if (isProfile)
        AppIconButton(
          icon: Icons.settings_outlined,
          tooltip: '设置',
          onPressed: () => Navigator.push(
            context,
            AppPageRoute(builder: (_) => const SettingsScreen()),
          ),
        ),
      if (selectedModuleId == 'alarms')
        AppIconButton(
          icon: Icons.sync,
          tooltip: auth.isAuthenticated ? '同步' : '登录并同步',
          onPressed: () => _alarmsKey.currentState?.sync(),
        ),
      if (selectedModuleId == 'music')
        AppIconButton(
          icon: Icons.sync,
          tooltip: auth.isAuthenticated ? '同步' : '登录并同步',
          onPressed: () => _musicKey.currentState?.sync(),
        ),
      if (selectedModuleId == 'videos')
        AppIconButton(
          icon: Icons.sync,
          tooltip: auth.isAuthenticated ? '同步' : '登录并同步',
          onPressed: () => _videosKey.currentState?.sync(),
        ),
      if (selectedModuleId == 'transactions')
        AppIconButton(
          icon: Icons.sync,
          tooltip: auth.isAuthenticated ? '同步' : '登录并同步',
          onPressed: () => _transactionsKey.currentState?.sync(),
        ),
    ];

    final widgetMap = {
      'notes': NotesScreen(key: _notesKey),
      'alarms': AlarmsScreen(key: _alarmsKey),
      'music': MusicScreen(key: _musicKey),
      'videos': VideosScreen(key: _videosKey),
      'schedules': SchedulesScreen(key: _schedulesKey),
      'transactions': TransactionsScreen(key: _transactionsKey),
      'profile': const ProfileScreen(),
    };
    final children = ids.map((id) => widgetMap[id]!).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppAppBar(
        titleWidget: title,
        actions: actions,
      ),
      drawer: isNotes ? _buildFolderDrawer() : null,
      body: IndexedStack(
        index: _currentIndex,
        children: children,
      ),
      floatingActionButton: isNotes
          ? AppFAB(
              heroTag: 'notes_fab',
              onPressed: () => _notesKey.currentState?.openEditor(
                null,
                defaultLocalFolderId: _notesKey.currentState?.selectedLocalFolderId,
              ),
              icon: Icons.add,
            )
          : isTransactions
              ? AppFAB(
                  heroTag: 'transactions_fab',
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.white,
                  onPressed: () => _transactionsKey.currentState?.openEditor(null),
                  icon: Icons.add,
                )
              : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: modules.map((m) => NavigationDestination(
          icon: Icon(m.icon),
          label: m.label,
        )).toList(),
      ),
    );
  }

  Widget _buildFolderDrawer() {
    final folderService = context.watch<LocalFolderService>();
    final allFolders = folderService.folders.where((f) => f.syncStatus != 'deleted').toList();

    final idToLocalId = <int, String>{for (final f in allFolders) if (f.id != null) f.id!: f.localId};
    final childrenMap = <String?, List<Folder>>{};
    for (final f in allFolders) {
      final parentKey = f.localParentId ?? (f.parentId != null ? idToLocalId[f.parentId] : null);
      (childrenMap[parentKey] ??= []).add(f);
    }
    for (final list in childrenMap.values) {
      list.sort((a, b) => a.name.compareTo(b.name));
    }
    final rootFolders = childrenMap[null] ?? const <Folder>[];

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            AppListTile(
              leading: const Icon(Icons.notes),
              title: '全部笔记',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIconButton(
                    icon: Icons.create_new_folder_outlined,
                    tooltip: '新建文件夹',
                    onPressed: () => _addFolder(null),
                  ),
                  AppIconButton(
                    icon: Icons.close,
                    tooltip: '关闭',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              onTap: () {
                Navigator.pop(context);
                _notesKey.currentState?.selectFolder(null);
              },
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: _buildDrawerFolderTree(rootFolders, childrenMap),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildDrawerFolderTree(
    List<Folder> folders,
    Map<String?, List<Folder>> childrenMap, {
    int depth = 0,
  }) {
    final leftPadding = AppSpacing.pageHorizontal + depth * 24.0;
    final result = <Widget>[];

    for (final folder in folders) {
      final children = childrenMap[folder.localId] ?? const <Folder>[];
      final hasChildren = children.isNotEmpty;
      final isExpanded = _expandedFolders.contains(folder.localId);

      result.add(
        InkWell(
          onLongPress: () => _showFolderMenu(folder),
          onTap: () {
            Navigator.pop(context);
            _notesKey.currentState?.selectFolder(folder.localId);
          },
          child: Padding(
            padding: EdgeInsets.only(
              left: leftPadding,
              right: AppSpacing.pageHorizontal,
              top: AppSpacing.sm,
              bottom: AppSpacing.sm,
            ),
            child: Row(
              children: [
                if (hasChildren)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isExpanded) {
                          _expandedFolders.remove(folder.localId);
                        } else {
                          _expandedFolders.add(folder.localId);
                        }
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      child: Icon(
                        isExpanded ? Icons.arrow_drop_down : Icons.arrow_right,
                        size: 20,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 28),
                const Icon(Icons.folder_outlined, size: 20, color: AppColors.brand),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    folder.name,
                    style: AppTypography.bodyLight(),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      if (hasChildren && isExpanded) {
        result.addAll(_buildDrawerFolderTree(children, childrenMap, depth: depth + 1));
      }
    }

    return result;
  }

  void _showFolderMenu(Folder folder) {
    showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(100, 200, 100, 200),
      items: [
        const PopupMenuItem(
          value: 'note',
          child: AppListTile(
            leading: Icon(Icons.note_add, size: 20),
            title: '新建笔记',
            padding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'subfolder',
          child: AppListTile(
            leading: Icon(Icons.create_new_folder_outlined, size: 20),
            title: '新建子文件夹',
            padding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: AppListTile(
            leading: Icon(Icons.delete_outline, size: 20),
            title: '删除文件夹',
            padding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'move',
          child: AppListTile(
            leading: Icon(Icons.drive_file_move_outline, size: 20),
            title: '移动',
            padding: EdgeInsets.zero,
          ),
        ),
      ],
    ).then((value) {
      if (value == null || !mounted) return;
      switch (value) {
        case 'note':
          Navigator.pop(context);
          _notesKey.currentState?.openEditorInFolder(folder.localId);
        case 'subfolder':
          _addFolder(folder);
        case 'delete':
          _deleteFolder(folder);
        case 'move':
          Navigator.pop(context);
          _notesKey.currentState?.moveFolder(folder);
      }
    });
  }

  void _addFolder(Folder? parent) async {
    final nameC = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  parent == null ? '新建文件夹' : '在"${parent.name}"下新建',
                  style: AppTypography.h2Light(),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppInput(
                  controller: nameC,
                  hintText: '文件夹名称',
                  autofocus: true,
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: AppButton.secondary(
                        label: '取消',
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: AppButton(
                        label: '确定',
                        onPressed: () => Navigator.pop(ctx, nameC.text.trim()),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result != null && result.isNotEmpty) {
      if (!mounted) return;
      final folderService = context.read<LocalFolderService>();
      await folderService.addFolder(Folder(
        name: result,
        parentId: parent?.id,
        localParentId: parent?.localId,
      ));
    }
  }

  void _deleteFolder(Folder folder) async {
    final confirm = await AppDialog.confirm(
      context: context,
      title: '删除文件夹',
      content: '确定要删除文件夹"${folder.name}"吗？',
      confirmLabel: '删除',
      destructive: true,
    );
    if (confirm == true) {
      if (!mounted) return;
      final folderService = context.read<LocalFolderService>();
      await folderService.deleteFolder(folder.localId);
    }
  }
}
