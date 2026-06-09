import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:leevinote/models/note.dart';
import 'package:leevinote/models/folder.dart';
import 'package:leevinote/services/api_service.dart';
import 'package:leevinote/services/auth_service.dart';
import 'package:leevinote/services/local_note_service.dart';
import 'package:leevinote/services/local_folder_service.dart';
import 'package:leevinote/utils/constants.dart';
import 'package:leevinote/screens/note_editor_screen.dart';
import 'package:leevinote/screens/login_screen.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => NotesScreenState();
}

class NotesScreenState extends State<NotesScreen> {
  final _searchC = TextEditingController();
  String? _selectedLocalFolderId;
  String? _longPressedItemId;
  Offset? _longPressPosition;
  VoidCallback? onFolderChanged;

  String? get selectedLocalFolderId => _selectedLocalFolderId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LocalNoteService>().ensureLoaded();
      context.read<LocalFolderService>().ensureLoaded();
    });
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  Future<void> _deleteNote(Note note) async {
    final local = context.read<LocalNoteService>();
    if (note.id != null) {
      await local.updateNote(note.copyWith(syncStatus: 'deleted'));
    } else {
      await local.deleteNote(note.localId);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已删除"${note.title}"')),
      );
    }
  }

  Future<void> _deleteFolder(Folder folder) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除文件夹'),
        content: Text('确定要删除文件夹"${folder.name}"吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确定')),
        ],
      ),
    );
    if (confirm == true) {
      await context.read<LocalFolderService>().deleteFolder(folder.localId);
    }
  }

  Future<String?> _showFolderPicker(
      {required BuildContext context,
      bool includeNull = true,
      String? excludeLocalId,
      String? selectedLocalId}) async {
    final folderService = context.read<LocalFolderService>();
    await folderService.ensureLoaded();

    final expandedFolders = <String>{};

    return showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final allFolders = folderService.folders
              .where((f) => f.syncStatus != 'deleted')
              .toList();
          final idToLocalId = <int, String>{
            for (final f in allFolders)
              if (f.id != null) f.id!: f.localId
          };
          final childrenMap = <String?, List<Folder>>{};
          for (final f in allFolders) {
            final parentKey = f.localParentId ??
                (f.parentId != null ? idToLocalId[f.parentId] : null);
            (childrenMap[parentKey] ??= []).add(f);
          }
          for (final list in childrenMap.values) {
            list.sort((a, b) => a.name.compareTo(b.name));
          }
          final rootFolders = childrenMap[null] ?? const <Folder>[];

          List<Widget> buildTree(List<Folder> items, {int depth = 0}) {
            final leftPadding = 16.0 + depth * 24.0;
            return items.map((folder) {
              if (folder.localId == excludeLocalId)
                return const SizedBox.shrink();
              final children = childrenMap[folder.localId] ?? const <Folder>[];
              final hasChildren = children.isNotEmpty;
              final isExpanded = expandedFolders.contains(folder.localId);
              final isSelected = folder.localId == selectedLocalId;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(ctx, folder.localId),
                    child: Padding(
                      padding: EdgeInsets.only(
                          left: leftPadding, right: 8, top: 8, bottom: 8),
                      child: Row(
                        children: [
                          if (hasChildren)
                            GestureDetector(
                              onTap: () {
                                setSheetState(() {
                                  if (isExpanded) {
                                    expandedFolders.remove(folder.localId);
                                  } else {
                                    expandedFolders.add(folder.localId);
                                  }
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                    isExpanded
                                        ? Icons.arrow_drop_down
                                        : Icons.arrow_right,
                                    size: 20),
                              ),
                            )
                          else
                            const SizedBox(width: 28),
                          const Icon(Icons.folder, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Text(folder.name,
                                  overflow: TextOverflow.ellipsis)),
                          if (isSelected)
                            Icon(Icons.check,
                                size: 18,
                                color: Theme.of(context).colorScheme.primary),
                        ],
                      ),
                    ),
                  ),
                  if (hasChildren && isExpanded)
                    ...buildTree(children, depth: depth + 1),
                ],
              );
            }).toList();
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('选择文件夹',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (includeNull)
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.folder_off, size: 20),
                            title: const Text('无文件夹'),
                            selected: selectedLocalId == null,
                            onTap: () => Navigator.pop(ctx, null),
                          ),
                        if (rootFolders.isNotEmpty) ...[
                          if (includeNull) const Divider(),
                          ...buildTree(rootFolders),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _moveNote(Note note) async {
    final localId = await _showFolderPicker(
      context: context,
      includeNull: true,
      selectedLocalId: note.localFolderId,
    );
    if (localId == null && note.localFolderId == null) return;
    if (localId == note.localFolderId) return;
    if (!mounted) return;

    int? folderId;
    if (localId != null) {
      final allFolders = context.read<LocalFolderService>().folders;
      final folder = allFolders.where((f) => f.localId == localId).firstOrNull;
      folderId = folder?.id;
    }

    final local = context.read<LocalNoteService>();
    final syncStatus = note.id != null && note.syncStatus == 'synced'
        ? 'modified'
        : note.syncStatus;
    await local.updateNote(note.copyWith(
      localFolderId: () => localId,
      folderId: () => folderId,
      syncStatus: syncStatus,
    ));
  }

  Future<void> _moveFolder(Folder folder) async {
    final localId = await _showFolderPicker(
      context: context,
      includeNull: true,
      excludeLocalId: folder.localId,
      selectedLocalId: folder.localParentId,
    );
    if (localId == null && folder.localParentId == null) return;
    if (localId == folder.localParentId) return;
    if (!mounted) return;

    int? parentId;
    if (localId != null) {
      final allFolders = context.read<LocalFolderService>().folders;
      final parent = allFolders.where((f) => f.localId == localId).firstOrNull;
      parentId = parent?.id;
    }

    final folderService = context.read<LocalFolderService>();
    final syncStatus = folder.id != null && folder.syncStatus == 'synced'
        ? 'modified'
        : folder.syncStatus;
    await folderService.updateFolder(folder.copyWith(
      localParentId: () => localId,
      parentId: () => parentId,
      syncStatus: syncStatus,
    ));
  }

  void _showFolderItemMenu(Folder folder, RelativeRect position) async {
    final result = await showMenu<String>(
      context: context,
      position: position,
      items: const [
        PopupMenuItem(
            value: 'delete',
            child: ListTile(
              leading: Icon(Icons.delete_outline, size: 20),
              title: Text('删除'),
              dense: true,
            )),
        PopupMenuItem(
            value: 'move',
            child: ListTile(
              leading: Icon(Icons.drive_file_move_outline, size: 20),
              title: Text('移动'),
              dense: true,
            )),
      ],
    );
    setState(() {
      _longPressedItemId = null;
      _longPressPosition = null;
    });
    if (result == null) return;
    switch (result) {
      case 'delete':
        _deleteFolder(folder);
      case 'move':
        _moveFolder(folder);
    }
  }

  List<Note> get _notes => context.watch<LocalNoteService>().notes;
  List<Folder> get _folders => context
      .watch<LocalFolderService>()
      .folders
      .where((f) => f.syncStatus != 'deleted')
      .toList();

  List<Note> get _filteredNotes {
    return _notes.where((n) {
      if (n.syncStatus == 'deleted') return false;
      if (_searchC.text.isNotEmpty) {
        final q = _searchC.text.toLowerCase();
        final matchTitle = n.title.toLowerCase().contains(q);
        final matchContent = _plainText(n.content).toLowerCase().contains(q);
        if (!matchTitle && !matchContent) return false;
      } else {
        if (_selectedLocalFolderId != null) {
          final noteFolderLocalId = n.localFolderId ??
              (n.folderId != null
                  ? _folders.where((f) => f.id == n.folderId).firstOrNull?.localId
                  : null);
          if (noteFolderLocalId != _selectedLocalFolderId) return false;
        } else if (n.localFolderId != null || n.folderId != null) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  List<Folder> get _childFolders {
    return _folders.where((f) {
      if (f.syncStatus == 'deleted') return false;
      final parentLocalId = f.localParentId ??
          (f.parentId != null
              ? _folders.where((pf) => pf.id == f.parentId).firstOrNull?.localId
              : null);
      return parentLocalId == _selectedLocalFolderId;
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  List<Folder> _buildBreadcrumb(String localFolderId) {
    final path = <Folder>[];
    final localIdMap = <String, Folder>{for (final f in _folders) f.localId: f};
    String? currentId = localFolderId;
    while (currentId != null && localIdMap.containsKey(currentId)) {
      path.insert(0, localIdMap[currentId]!);
      final f = localIdMap[currentId]!;
      currentId = f.localParentId ??
          (f.parentId != null
              ? _folders.where((pf) => pf.id == f.parentId).firstOrNull?.localId
              : null);
    }
    return path;
  }

  Future<void> sync() async {
    final auth = context.read<AuthService>();
    if (!auth.isAuthenticated) {
      final loggedIn = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      if (loggedIn != true) return;
    }

    final api = context.read<ApiService>();
    final local = context.read<LocalNoteService>();
    final folderService = context.read<LocalFolderService>();

    try {
      await local.ensureLoaded();
      await folderService.ensureLoaded();

      // Sync folders first (topological sort: parents before children)
      final localIdToRemoteId = <String, int>{};
      final localFolders = folderService.folders;

      // Build dependency graph and sort
      final sorted = <Folder>[];
      final visited = <String>{};
      final folderByLocalId = <String, Folder>{
        for (final f in localFolders) f.localId: f
      };

      void visit(Folder f) {
        if (visited.contains(f.localId)) return;
        visited.add(f.localId);
        // Visit parent first
        if (f.localParentId != null &&
            folderByLocalId.containsKey(f.localParentId)) {
          visit(folderByLocalId[f.localParentId]!);
        }
        sorted.add(f);
      }

      for (final f in localFolders) {
        visit(f);
      }

      // Sync folders in topological order
      for (final folder in sorted) {
        if (folder.syncStatus == 'deleted' && folder.id != null) {
          try {
            await api.delete('${ApiConstants.folders}/${folder.id}');
            await folderService.deleteFolder(folder.localId, force: true);
          } catch (_) {}
        } else if (folder.syncStatus == 'local' && folder.id == null) {
          // Resolve parentId from localParentId
          int? parentId = folder.parentId;
          if (folder.localParentId != null &&
              localIdToRemoteId.containsKey(folder.localParentId)) {
            parentId = localIdToRemoteId[folder.localParentId];
          }
          final remoteJson = {
            'name': folder.name,
            'parent_id': parentId,
          };
          final resp = await api.post(ApiConstants.folders, remoteJson);
          final remoteId = resp['id'];
          final newId = remoteId is int
              ? remoteId
              : int.tryParse(remoteId?.toString() ?? '');
          if (newId != null) {
            localIdToRemoteId[folder.localId] = newId;
          }
          final updated = folder.copyWith(
            id: newId,
            parentId: () => parentId,
            syncStatus: 'synced',
          );
          await folderService.updateFolder(updated);
        } else if (folder.syncStatus == 'modified' && folder.id != null) {
          int? parentId = folder.parentId;
          if (folder.localParentId != null &&
              localIdToRemoteId.containsKey(folder.localParentId)) {
            parentId = localIdToRemoteId[folder.localParentId];
          }
          final remoteJson = {
            'name': folder.name,
            'parent_id': parentId,
          };
          await api.put('${ApiConstants.folders}/${folder.id}', remoteJson);
          await folderService.updateFolder(folder.copyWith(
            parentId: () => parentId,
            syncStatus: 'synced',
          ));
        } else if (folder.id != null) {
          // Already synced, just record the mapping
          localIdToRemoteId[folder.localId] = folder.id!;
        }
      }

      // Sync notes
      final localNotes = local.notes;
      for (final note in List.from(localNotes)) {
        if (note.syncStatus == 'local' && note.id == null) {
          // Resolve folderId from localFolderId
          int? folderId = note.folderId;
          if (note.localFolderId != null &&
              localIdToRemoteId.containsKey(note.localFolderId)) {
            folderId = localIdToRemoteId[note.localFolderId];
          }
          final remoteJson = {
            'title': note.title,
            'content': note.content,
            'category': note.category,
            'folder_id': folderId,
          };
          final resp = await api.post(ApiConstants.notes, remoteJson);
          final remoteId = resp['id'];
          final updated = note.copyWith(
            id: remoteId is int
                ? remoteId
                : int.tryParse(remoteId?.toString() ?? ''),
            folderId: () => folderId,
            syncStatus: 'synced',
          );
          await local.updateNote(updated);
        } else if (note.syncStatus == 'modified' && note.id != null) {
          int? folderId = note.folderId;
          if (note.localFolderId != null &&
              localIdToRemoteId.containsKey(note.localFolderId)) {
            folderId = localIdToRemoteId[note.localFolderId];
          }
          final remoteJson = {
            'title': note.title,
            'content': note.content,
            'category': note.category,
            'folder_id': folderId,
          };
          await api.put('${ApiConstants.notes}/${note.id}', remoteJson);
          await local.updateNote(note.copyWith(
            folderId: () => folderId,
            syncStatus: 'synced',
          ));
        } else if (note.syncStatus == 'deleted' && note.id != null) {
          try {
            await api.delete('${ApiConstants.notes}/${note.id}');
            await local.deleteNote(note.localId);
          } catch (_) {}
        }
      }

      final remoteData = await api.getList(ApiConstants.notes);
      for (final e in remoteData) {
        final remote = Note.fromJson(e as Map<String, dynamic>)
            .copyWith(syncStatus: 'synced');
        await local.addOrUpdateFromRemote(remote);
      }

      final remoteFolders = await api.getList(ApiConstants.folders);
      final remoteFolderIds = remoteFolders
          .map((e) => (e as Map)['id'] as int?)
          .whereType<int>()
          .toSet();
      for (final folder in List.from(folderService.folders)) {
        if (folder.id != null &&
            folder.syncStatus == 'synced' &&
            !remoteFolderIds.contains(folder.id)) {
          await folderService.deleteFolder(folder.localId, force: true);
        }
      }
      for (final e in remoteFolders) {
        final remote = Folder.fromJson(e as Map<String, dynamic>);
        await folderService
            .addOrUpdateFromRemote(remote.copyWith(syncStatus: 'synced'));
      }

      final remoteNoteIds = remoteData
          .map((e) => (e as Map)['id'] as int?)
          .whereType<int>()
          .toSet();
      for (final note in List.from(local.notes)) {
        if (note.id != null &&
            note.syncStatus == 'synced' &&
            !remoteNoteIds.contains(note.id)) {
          await local.deleteNote(note.localId);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('同步完成'),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.fromLTRB(16, 0, 16, 80),
          ),
        );
      }
    } catch (e, st) {
      debugPrint('同步失败: $e\n$st');
      if (mounted) {
        final token = await auth.read('jwt_token');
        if (token == null) {
          final loggedIn = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
          if (loggedIn == true) {
            sync();
            return;
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('同步失败: $e'),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
          ),
        );
      }
    }
  }

  Future<void> openEditor(Note? note, {String? defaultLocalFolderId}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(
          note: note,
          defaultLocalFolderId: defaultLocalFolderId ?? _selectedLocalFolderId,
        ),
      ),
    );
  }

  Future<void> openEditorInFolder(String? localFolderId) async {
    selectFolder(localFolderId);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(
          note: null,
          defaultLocalFolderId: localFolderId,
        ),
      ),
    );
  }

  void selectFolder(String? localFolderId) {
    setState(() => _selectedLocalFolderId = localFolderId);
    onFolderChanged?.call();
  }

  Future<void> moveFolder(Folder folder) => _moveFolder(folder);

  Widget buildBreadcrumbWidget() {
    final path = _selectedLocalFolderId != null
        ? _buildBreadcrumb(_selectedLocalFolderId!)
        : <Folder>[];
    final theme = Theme.of(context);

    final boldStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.bold,
      color: theme.colorScheme.onSurface,
    );
    final normalStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.normal,
      color: theme.colorScheme.primary,
    );

    const chevronWidth = 18.0;
    const crumbPadding = 8.0;

    double tw(String text, TextStyle style) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      return tp.width;
    }

    double fullWidth = tw('全部', boldStyle) + crumbPadding;
    for (final f in path) {
      fullWidth += chevronWidth + tw(f.name, normalStyle) + crumbPadding;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final useFull = fullWidth <= constraints.maxWidth;

        final chips = <Widget>[];
        chips.add(
            _breadcrumbCrumb('全部', boldStyle, onTap: () => selectFolder(null)));

        if (path.isEmpty) {
          // nop
        } else if (useFull) {
          for (int i = 0; i < path.length; i++) {
            chips.add(_breadcrumbChevron(theme));
            final isLast = i == path.length - 1;
            final folder = path[i];
            chips.add(_breadcrumbCrumb(
              folder.name,
              isLast ? boldStyle : normalStyle,
              onTap: isLast ? null : () => selectFolder(folder.localId),
            ));
          }
        } else if (path.length == 1) {
          chips.add(_breadcrumbChevron(theme));
          chips.add(_breadcrumbCrumb(path[0].name, boldStyle));
        } else {
          chips.add(_breadcrumbChevron(theme));
          chips.add(_breadcrumbCrumb('...', normalStyle));
          chips.add(_breadcrumbChevron(theme));
          final parentFolder = path[path.length - 2];
          chips.add(_breadcrumbCrumb(
            parentFolder.name,
            normalStyle,
            onTap: () => selectFolder(parentFolder.localId),
          ));
          chips.add(_breadcrumbChevron(theme));
          chips.add(_breadcrumbCrumb(path.last.name, boldStyle));
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(mainAxisSize: MainAxisSize.min, children: chips),
        );
      },
    );
  }

  Widget _breadcrumbChevron(ThemeData theme) =>
      Icon(Icons.chevron_right, size: 18, color: theme.colorScheme.outline);

  Widget _breadcrumbCrumb(String text, TextStyle style, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Text(text, style: style, overflow: TextOverflow.ellipsis),
      ),
    );
  }

  String _plainText(String? content) {
    if (content == null || content.isEmpty) return '';
    try {
      final delta = jsonDecode(content) as List;
      return delta
          .map((op) {
            final insert = (op as Map)['insert'];
            if (insert is Map) return '';
            return insert?.toString() ?? '';
          })
          .join()
          .trim();
    } catch (_) {
      return content;
    }
  }

  String? _firstImage(String? content) {
    if (content == null || content.isEmpty) return null;
    try {
      final delta = jsonDecode(content) as List;
      for (final op in delta) {
        final insert = (op as Map)['insert'];
        if (insert is Map && insert.containsKey('image')) {
          return insert['image'] as String;
        }
      }
    } catch (_) {}
    return null;
  }

  Widget _buildThumbnail(String imageUrl) {
    if (imageUrl.startsWith('local://')) {
      final path = imageUrl.substring('local://'.length);
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.file(
          File(path),
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      );
    }
    final fullUrl = imageUrl.startsWith('http')
        ? imageUrl
        : '${ApiConstants.baseUrl}/files/$imageUrl';
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.network(
        fullUrl,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredNotes;
    final childFolders = _searchC.text.isEmpty ? _childFolders : <Folder>[];
    final totalItems = childFolders.length + filtered.length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: SearchBar(
            controller: _searchC,
            hintText: '搜索标题或内容...',
            padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 12)),
            leading: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(Icons.search,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            trailing: [
              if (_searchC.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchC.clear();
                    setState(() {});
                  },
                ),
            ],
            onChanged: (_) => setState(() {}),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: totalItems == 0
              ? const SizedBox.shrink()
              : RefreshIndicator(
                  onRefresh: () async {},
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: totalItems,
                    itemBuilder: (context, index) {
                      if (index < childFolders.length) {
                        final folder = childFolders[index];
                        return Builder(
                          builder: (ctx) {
                            final isLongPressed =
                                _longPressedItemId == folder.localId;
                            return GestureDetector(
                              onLongPressStart: (details) {
                                setState(() {
                                  _longPressedItemId = folder.localId;
                                  _longPressPosition = details.globalPosition;
                                });
                              },
                              onLongPress: () {
                                if (_longPressPosition == null) return;
                                final overlay = Overlay.of(context)
                                    .context
                                    .findRenderObject() as RenderBox;
                                _showFolderItemMenu(
                                    folder,
                                    RelativeRect.fromRect(
                                      Rect.fromPoints(_longPressPosition!,
                                          _longPressPosition!),
                                      Offset.zero & overlay.size,
                                    ));
                              },
                              child: Card(
                                color: isLongPressed
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primaryContainer
                                    : null,
                                child: ListTile(
                                  leading: const Icon(Icons.folder, size: 24),
                                  title: Text(folder.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  onTap: () => selectFolder(folder.localId),
                                ),
                              ),
                            );
                          },
                        );
                      }
                      final note = filtered[index - childFolders.length];
                      final preview = _plainText(note.content);
                      final thumbnail = _firstImage(note.content);
                      return Builder(
                        builder: (ctx) {
                          final isLongPressed =
                              _longPressedItemId == note.localId;
                          return GestureDetector(
                            onLongPressStart: (details) {
                              setState(() {
                                _longPressedItemId = note.localId;
                                _longPressPosition = details.globalPosition;
                              });
                            },
                            onLongPress: () async {
                              if (_longPressPosition == null) return;
                              final overlay = Overlay.of(context)
                                  .context
                                  .findRenderObject() as RenderBox;
                              final result = await showMenu<String>(
                                context: context,
                                position: RelativeRect.fromRect(
                                  Rect.fromPoints(
                                      _longPressPosition!, _longPressPosition!),
                                  Offset.zero & overlay.size,
                                ),
                                items: const [
                                  PopupMenuItem(
                                      value: 'delete',
                                      child: ListTile(
                                        leading: Icon(Icons.delete_outline,
                                            size: 20),
                                        title: Text('删除'),
                                        dense: true,
                                      )),
                                  PopupMenuItem(
                                      value: 'move',
                                      child: ListTile(
                                        leading: Icon(
                                            Icons.drive_file_move_outline,
                                            size: 20),
                                        title: Text('移动'),
                                        dense: true,
                                      )),
                                ],
                              );
                              setState(() {
                                _longPressedItemId = null;
                                _longPressPosition = null;
                              });
                              if (result == null) return;
                              switch (result) {
                                case 'delete':
                                  _deleteNote(note);
                                case 'move':
                                  _moveNote(note);
                              }
                            },
                            child: Card(
                              color: isLongPressed
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                  : null,
                              child: InkWell(
                                onTap: () => openEditor(note),
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: ListTile(
                                          title: Text(
                                            note.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          subtitle: preview.isNotEmpty
                                              ? Text(
                                                  preview,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                                )
                                              : null,
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (thumbnail != null) ...[
                                                _buildThumbnail(thumbnail),
                                                const SizedBox(width: 8),
                                              ],
                                              if (note.syncStatus != 'synced')
                                                Icon(Icons.cloud_off,
                                                    size: 14,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .outline),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
