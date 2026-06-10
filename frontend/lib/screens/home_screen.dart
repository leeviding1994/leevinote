import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:leevinote/models/folder.dart';
import 'package:leevinote/screens/notes_screen.dart';
import 'package:leevinote/screens/alarms_screen.dart';
import 'package:leevinote/screens/music_screen.dart';
import 'package:leevinote/screens/videos_screen.dart';
import 'package:leevinote/screens/schedules_screen.dart';
import 'package:leevinote/services/auth_service.dart';
import 'package:leevinote/services/local_folder_service.dart';

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
  final Set<String> _expandedFolders = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notesKey.currentState?.onFolderChanged = () => setState(() {});
    });
  }

  final List<String> _titles = [
    '笔记',
    '闹钟',
    '音乐',
    '视频',
    '日程',
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return Scaffold(
      appBar: AppBar(
        title: _currentIndex == 4
            ? GestureDetector(
                onTap: () => _schedulesKey.currentState?.resetToDayView(),
                child: Text(_titles[_currentIndex]),
              )
            : (_currentIndex == 0 && _notesKey.currentState != null
                ? _notesKey.currentState!.buildBreadcrumbWidget()
                : Text(_titles[_currentIndex])),
        actions: [
          if (_currentIndex == 0)
            IconButton(
              icon: const Icon(Icons.sync),
              tooltip: auth.isAuthenticated ? '同步' : '登录并同步',
              onPressed: () => _notesKey.currentState?.sync(),
            ),
          if (_currentIndex == 1)
            IconButton(
              icon: const Icon(Icons.sync),
              tooltip: auth.isAuthenticated ? '同步' : '登录并同步',
              onPressed: () => _alarmsKey.currentState?.sync(),
            ),
          if (_currentIndex == 2)
            IconButton(
              icon: const Icon(Icons.sync),
              tooltip: auth.isAuthenticated ? '同步' : '登录并同步',
              onPressed: () => _musicKey.currentState?.sync(),
            ),
          if (_currentIndex == 3)
            IconButton(
              icon: const Icon(Icons.sync),
              tooltip: auth.isAuthenticated ? '同步' : '登录并同步',
              onPressed: () => _videosKey.currentState?.sync(),
            ),
          if (_currentIndex == 4)
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: '搜索日程',
              onPressed: () => _schedulesKey.currentState?.toggleSearch(),
            ),
          if (_currentIndex == 4)
            IconButton(
              icon: const Icon(Icons.sync),
              tooltip: auth.isAuthenticated ? '同步' : '登录并同步',
              onPressed: () => _schedulesKey.currentState?.sync(),
            ),
        ],
      ),
      drawer: _currentIndex == 0 ? _buildFolderDrawer() : null,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          NotesScreen(key: _notesKey),
          AlarmsScreen(key: _alarmsKey),
          MusicScreen(key: _musicKey),
          VideosScreen(key: _videosKey),
          SchedulesScreen(key: _schedulesKey),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: () => _notesKey.currentState?.openEditor(
                null,
                defaultLocalFolderId: _notesKey.currentState?.selectedLocalFolderId,
              ),
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.note), label: '笔记'),
          NavigationDestination(icon: Icon(Icons.alarm), label: '闹钟'),
          NavigationDestination(icon: Icon(Icons.music_note), label: '音乐'),
          NavigationDestination(icon: Icon(Icons.video_library), label: '视频'),
          NavigationDestination(icon: Icon(Icons.calendar_today), label: '日程'),
        ],
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
            ListTile(
              leading: const Icon(Icons.notes),
              title: const Text('全部笔记'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.create_new_folder_outlined),
                    tooltip: '新建文件夹',
                    onPressed: () => _addFolder(null),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
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
    final leftPadding = 16.0 + depth * 24.0;
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
            padding: EdgeInsets.only(left: leftPadding, right: 16, top: 8, bottom: 8),
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
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        isExpanded ? Icons.arrow_drop_down : Icons.arrow_right,
                        size: 20,
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 28),
                const Icon(Icons.folder, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(folder.name, overflow: TextOverflow.ellipsis)),
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
        const PopupMenuItem(value: 'note', child: ListTile(
          leading: Icon(Icons.note_add, size: 20),
          title: Text('新建笔记'),
          dense: true,
        )),
        const PopupMenuItem(value: 'subfolder', child: ListTile(
          leading: Icon(Icons.create_new_folder_outlined, size: 20),
          title: Text('新建子文件夹'),
          dense: true,
        )),
        const PopupMenuItem(value: 'delete', child: ListTile(
          leading: Icon(Icons.delete_outline, size: 20),
          title: Text('删除文件夹'),
          dense: true,
        )),
        const PopupMenuItem(value: 'move', child: ListTile(
          leading: Icon(Icons.drive_file_move_outline, size: 20),
          title: Text('移动'),
          dense: true,
        )),
      ],
    ).then((value) {
      if (value == null) return;
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
      builder: (ctx) => AlertDialog(
        title: Text(parent == null ? '新建文件夹' : '在"${parent.name}"下新建'),
        content: TextField(
          controller: nameC,
          autofocus: true,
          decoration: const InputDecoration(hintText: '文件夹名称'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, nameC.text.trim()), child: const Text('确定')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      final folderService = context.read<LocalFolderService>();
      await folderService.addFolder(Folder(
        name: result,
        parentId: parent?.id,
        localParentId: parent?.localId,
      ));
    }
  }

  void _deleteFolder(Folder folder) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除文件夹'),
        content: Text('确定要删除文件夹"${folder.name}"吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确定')),
        ],
      ),
    );
    if (confirm == true) {
      final folderService = context.read<LocalFolderService>();
      await folderService.deleteFolder(folder.localId);
    }
  }
}
