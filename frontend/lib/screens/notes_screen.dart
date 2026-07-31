import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:leevinote/design/app_theme.dart';
import 'package:leevinote/models/note.dart';
import 'package:leevinote/models/folder.dart';
import 'package:leevinote/services/api_service.dart';
import 'package:leevinote/services/auth_service.dart';
import 'package:leevinote/services/local_note_service.dart';
import 'package:leevinote/services/local_folder_service.dart';
import 'package:leevinote/utils/constants.dart';
import 'package:leevinote/widgets/widgets.dart';
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
  late final LocalNoteService _noteService;
  late final LocalFolderService _folderService;
  bool _servicesInitialized = false;

  String? get selectedLocalFolderId => _selectedLocalFolderId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_servicesInitialized) {
      _noteService = context.read<LocalNoteService>();
      _folderService = context.read<LocalFolderService>();
      _noteService.addListener(_updateFilteredNotes);
      _folderService.addListener(_updateFilteredNotes);
      _servicesInitialized = true;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _noteService.ensureLoaded();
      await _folderService.ensureLoaded();
      if (!mounted) return;
      await _updateFilteredNotes();
    });
  }

  @override
  void dispose() {
    _searchC.dispose();
    if (_servicesInitialized) {
      _noteService.removeListener(_updateFilteredNotes);
      _folderService.removeListener(_updateFilteredNotes);
    }
    super.dispose();
  }

  Future<void> _deleteNote(Note note) async {
    if (note.id != null) {
      await _noteService.forceDeleteNote(note.localId);
    } else {
      await _noteService.deleteNote(note.localId);
    }
    await _updateFilteredNotes();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已删除"${note.title}"')),
      );
    }
  }

  Future<void> _deleteFolder(Folder folder) async {
    final confirm = await AppDialog.confirm(
      context: context,
      title: '删除文件夹',
      content: '确定要删除文件夹"${folder.name}"吗？',
      confirmLabel: '删除',
      destructive: true,
    );
    if (confirm == true) {
      if (!mounted) return;
      await _folderService.deleteFolder(folder.localId);
    }
  }

  Future<String?> _showFolderPicker({
    bool includeNull = true,
    String? excludeLocalId,
    String? selectedLocalId,
  }) async {
    await _folderService.ensureLoaded();
    if (!mounted) return null;

    final expandedFolders = <String>{};

    return showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final allFolders = _folderService.folders
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
            final leftPadding = AppSpacing.pageHorizontal + depth * 24.0;
            return items.map((folder) {
              if (folder.localId == excludeLocalId) {
                return const SizedBox.shrink();
              }
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
                                setSheetState(() {
                                  if (isExpanded) {
                                    expandedFolders.remove(folder.localId);
                                  } else {
                                    expandedFolders.add(folder.localId);
                                  }
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.xs),
                                child: Icon(
                                  isExpanded
                                      ? Icons.arrow_drop_down
                                      : Icons.arrow_right,
                                  size: 20,
                                  color: AppColors.secondaryText,
                                ),
                              ),
                            )
                          else
                            const SizedBox(width: 28),
                          const Icon(Icons.folder_outlined,
                              size: 20, color: AppColors.brand),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              folder.name,
                              style: AppTypography.bodyLight(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
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
              left: AppSpacing.pageHorizontal,
              right: AppSpacing.pageHorizontal,
              top: AppSpacing.xl,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('选择文件夹', style: AppTypography.h2Light()),
                const SizedBox(height: AppSpacing.lg),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (includeNull)
                          AppListTile(
                            leading: const Icon(Icons.folder_off, size: 20),
                            title: '无文件夹',
                            onTap: () => Navigator.pop(ctx, null),
                            trailing: selectedLocalId == null
                                ? Icon(Icons.check,
                                    color:
                                        Theme.of(context).colorScheme.primary)
                                : null,
                          ),
                        if (rootFolders.isNotEmpty) ...[
                          const Divider(height: 1),
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
      includeNull: true,
      selectedLocalId: note.localFolderId,
    );
    if (localId == null && note.localFolderId == null) return;
    if (localId == note.localFolderId) return;
    if (!mounted) return;

    int? folderId;
    if (localId != null) {
      final allFolders = _folderService.folders;
      final folder = allFolders.where((f) => f.localId == localId).firstOrNull;
      folderId = folder?.id;
    }

    final syncStatus = note.id != null && note.syncStatus == 'synced'
        ? 'modified'
        : note.syncStatus;
    await _noteService.updateNote(note.copyWith(
      localFolderId: () => localId,
      folderId: () => folderId,
      syncStatus: syncStatus,
    ));
  }

  Future<void> _moveFolder(Folder folder) async {
    final localId = await _showFolderPicker(
      includeNull: true,
      excludeLocalId: folder.localId,
      selectedLocalId: folder.localParentId,
    );
    if (localId == null && folder.localParentId == null) return;
    if (localId == folder.localParentId) return;
    if (!mounted) return;

    int? parentId;
    if (localId != null) {
      final allFolders = _folderService.folders;
      final parent = allFolders.where((f) => f.localId == localId).firstOrNull;
      parentId = parent?.id;
    }

    final syncStatus = folder.id != null && folder.syncStatus == 'synced'
        ? 'modified'
        : folder.syncStatus;
    await _folderService.updateFolder(folder.copyWith(
      localParentId: () => localId,
      parentId: () => parentId,
      syncStatus: syncStatus,
    ));
  }

  void _showFolderItemMenu(Folder folder, RelativeRect position) async {
    final result = await showMenu<String>(
      context: context,
      position: position,
      items: [
        const PopupMenuItem(
          value: 'delete',
          child: AppListTile(
            leading: Icon(Icons.delete_outline, size: 20),
            title: '删除',
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

  List<Folder> get _folders => context
      .watch<LocalFolderService>()
      .folders
      .where((f) => f.syncStatus != 'deleted')
      .toList();

  List<Note> _filteredNotes = [];

  Future<void> _updateFilteredNotes() async {
    await _noteService.ensureLoaded();
    if (_searchC.text.isNotEmpty) {
      final results = await _noteService.searchNotes(_searchC.text);
      if (mounted) {
        setState(() {
          _filteredNotes = results;
        });
      }
    } else {
      final results =
          await _noteService.getNotesByFolder(_selectedLocalFolderId);
      if (mounted) {
        setState(() {
          _filteredNotes = results;
        });
      }
    }
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
    final api = context.read<ApiService>();
    if (!auth.isAuthenticated) {
      final loggedIn = await Navigator.push<bool>(
        context,
        AppPageRoute(builder: (_) => const LoginScreen()),
      );
      if (loggedIn != true) return;
    }
    if (!mounted) return;

    try {
      await _noteService.ensureLoaded();
      await _folderService.ensureLoaded();

      final localIdToRemoteId = <String, int>{};
      final localFolders = _folderService.folders;

      final sorted = <Folder>[];
      final visited = <String>{};
      final folderByLocalId = <String, Folder>{
        for (final f in localFolders) f.localId: f
      };

      void visit(Folder f) {
        if (visited.contains(f.localId)) return;
        visited.add(f.localId);
        if (f.localParentId != null &&
            folderByLocalId.containsKey(f.localParentId)) {
          visit(folderByLocalId[f.localParentId]!);
        }
        sorted.add(f);
      }

      for (final f in localFolders) {
        visit(f);
      }

      for (final folder in sorted) {
        if (folder.syncStatus == 'deleted' && folder.id != null) {
          try {
            await api.delete('${ApiConstants.folders}/${folder.id}');
            await _folderService.deleteFolder(folder.localId, force: true);
          } catch (_) {}
        } else if (folder.syncStatus == 'local' && folder.id == null) {
          int? parentId = folder.parentId;
          if (folder.localParentId != null) {
            if (localIdToRemoteId.containsKey(folder.localParentId)) {
              parentId = localIdToRemoteId[folder.localParentId];
            } else {
              final allFolders = _folderService.folders;
              final parentFolder = allFolders
                  .where((f) => f.localId == folder.localParentId)
                  .firstOrNull;
              if (parentFolder != null && parentFolder.id != null) {
                parentId = parentFolder.id;
              }
            }
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
          if (newId == null) {
            throw Exception('创建文件夹失败：服务器未返回 ID');
          }
          localIdToRemoteId[folder.localId] = newId;
          final updated = folder.copyWith(
            id: newId,
            parentId: () => parentId,
            syncStatus: 'synced',
          );
          await _folderService.updateFolder(updated);
        } else if (folder.syncStatus == 'modified' && folder.id != null) {
          int? parentId = folder.parentId;
          if (folder.localParentId != null) {
            if (localIdToRemoteId.containsKey(folder.localParentId)) {
              parentId = localIdToRemoteId[folder.localParentId];
            } else {
              final allFolders = _folderService.folders;
              final parentFolder = allFolders
                  .where((f) => f.localId == folder.localParentId)
                  .firstOrNull;
              if (parentFolder != null && parentFolder.id != null) {
                parentId = parentFolder.id;
              }
            }
          }
          final remoteJson = {
            'name': folder.name,
            'parent_id': parentId,
          };
          await api.put('${ApiConstants.folders}/${folder.id}', remoteJson);
          await _folderService.updateFolder(folder.copyWith(
            parentId: () => parentId,
            syncStatus: 'synced',
          ));
        } else if (folder.id != null) {
          localIdToRemoteId[folder.localId] = folder.id!;
        }
      }

      final localNotes = _noteService.notes;
      for (final note in List.from(localNotes)) {
        if (note.syncStatus == 'local' && note.id == null) {
          int? folderId = note.folderId;
          if (note.localFolderId != null) {
            if (localIdToRemoteId.containsKey(note.localFolderId)) {
              folderId = localIdToRemoteId[note.localFolderId];
            } else {
              final allFolders = _folderService.folders;
              final folder = allFolders
                  .where((f) => f.localId == note.localFolderId)
                  .firstOrNull;
              if (folder != null && folder.id != null) {
                folderId = folder.id;
              }
            }
          }
          final remoteJson = {
            'title': note.title,
            'content': note.content,
            'category': note.category,
            'folder_id': folderId,
          };
          final resp = await api.post(ApiConstants.notes, remoteJson);
          final remoteId = resp['id'];
          final newId = remoteId is int
              ? remoteId
              : int.tryParse(remoteId?.toString() ?? '');
          if (newId == null) {
            throw Exception('创建笔记失败：服务器未返回 ID');
          }
          final updated = note.copyWith(
            id: newId,
            folderId: () => folderId,
            syncStatus: 'synced',
          );
          await _noteService.updateNote(updated);
        } else if (note.syncStatus == 'modified' && note.id != null) {
          int? folderId = note.folderId;
          if (note.localFolderId != null) {
            if (localIdToRemoteId.containsKey(note.localFolderId)) {
              folderId = localIdToRemoteId[note.localFolderId];
            } else {
              final allFolders = _folderService.folders;
              final folder = allFolders
                  .where((f) => f.localId == note.localFolderId)
                  .firstOrNull;
              if (folder != null && folder.id != null) {
                folderId = folder.id;
              }
            }
          }
          final remoteJson = {
            'title': note.title,
            'content': note.content,
            'category': note.category,
            'folder_id': folderId,
          };
          await api.put('${ApiConstants.notes}/${note.id}', remoteJson);
          await _noteService.updateNote(note.copyWith(
            folderId: () => folderId,
            syncStatus: 'synced',
          ));
        } else if (note.syncStatus == 'deleted' && note.id != null) {
          try {
            await api.delete('${ApiConstants.notes}/${note.id}');
            await _noteService.forceDeleteNote(note.localId);
          } catch (_) {}
        }
      }

      final remoteFolderList = (await api.getList(ApiConstants.folders))
          .map((e) => Folder.fromJson(e as Map<String, dynamic>))
          .toList();
      final remoteFolderIds =
          remoteFolderList.map((f) => f.id).whereType<int>().toSet();
      for (final folder in List.from(_folderService.folders)) {
        if (folder.id != null &&
            folder.syncStatus == 'synced' &&
            !remoteFolderIds.contains(folder.id)) {
          await _folderService.deleteFolder(folder.localId, force: true);
        }
      }

      final folderByRemoteId = <int, Folder>{
        for (final f in remoteFolderList)
          if (f.id != null) f.id!: f
      };
      final sortedRemoteFolders = <Folder>[];
      final remoteVisited = <int>{};
      void visitFolder(Folder f) {
        if (f.id == null || remoteVisited.contains(f.id)) return;
        remoteVisited.add(f.id!);
        final parentId = f.parentId;
        if (parentId != null && folderByRemoteId.containsKey(parentId)) {
          visitFolder(folderByRemoteId[parentId]!);
        }
        sortedRemoteFolders.add(f);
      }

      for (final f in remoteFolderList) {
        visitFolder(f);
      }

      for (final remote in sortedRemoteFolders) {
        await _folderService
            .addOrUpdateFromRemote(remote.copyWith(syncStatus: 'synced'));
      }

      final remoteFolderIdToLocalId = <int, String>{
        for (final f in _folderService.folders)
          if (f.id != null) f.id!: f.localId
      };

      final remoteData = await api.getList(ApiConstants.notes);
      final remoteNoteIds = remoteData
          .map((e) => (e as Map)['id'] as int?)
          .whereType<int>()
          .toSet();
      for (final note in List.from(_noteService.notes)) {
        if (note.id != null &&
            note.syncStatus == 'synced' &&
            !remoteNoteIds.contains(note.id)) {
          await _noteService.deleteNote(note.localId);
        }
      }
      for (final e in remoteData) {
        final remote = Note.fromJson(e as Map<String, dynamic>)
            .copyWith(syncStatus: 'synced');
        final localFolderId = remote.folderId != null
            ? remoteFolderIdToLocalId[remote.folderId]
            : null;
        await _noteService.addOrUpdateFromRemote(
          remote.copyWith(localFolderId: () => localFolderId),
        );
      }

      await _updateFilteredNotes();

      if (mounted) {
        AppToast.success(context, '同步完成');
      }
    } catch (e, st) {
      debugPrint('同步失败: $e\n$st');
      if (mounted) {
        final token = await auth.read('jwt_token');
        if (!mounted) return;
        if (token == null) {
          final loggedIn = await Navigator.push<bool>(
            context,
            AppPageRoute(builder: (_) => const LoginScreen()),
          );
          if (loggedIn == true) {
            sync();
            return;
          }
        }
        if (!mounted) return;
        AppToast.error(context, '同步失败: $e');
      }
    }
  }

  Future<void> openEditor(Note? note, {String? defaultLocalFolderId}) async {
    await Navigator.push(
      context,
      AppPageRoute(
        builder: (_) => NoteEditorScreen(
          note: note,
          defaultLocalFolderId: defaultLocalFolderId ?? _selectedLocalFolderId,
        ),
      ),
    );
    if (!mounted) return;
    await _updateFilteredNotes();
  }

  Future<void> openEditorInFolder(String? localFolderId) async {
    selectFolder(localFolderId);
    await Navigator.push(
      context,
      AppPageRoute(
        builder: (_) => NoteEditorScreen(
          note: null,
          defaultLocalFolderId: localFolderId,
        ),
      ),
    );
    if (!mounted) return;
    await _updateFilteredNotes();
  }

  void selectFolder(String? localFolderId) {
    setState(() => _selectedLocalFolderId = localFolderId);
    _updateFilteredNotes();
    onFolderChanged?.call();
  }

  Future<void> moveFolder(Folder folder) => _moveFolder(folder);

  Widget buildBreadcrumbWidget() {
    final path = _selectedLocalFolderId != null
        ? _buildBreadcrumb(_selectedLocalFolderId!)
        : <Folder>[];

    final boldStyle = AppTypography.captionMediumLight(
        color: Theme.of(context).colorScheme.onSurface);
    final normalStyle = AppTypography.captionMediumLight(
        color: Theme.of(context).colorScheme.primary);

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
            chips.add(_breadcrumbChevron());
            final isLast = i == path.length - 1;
            final folder = path[i];
            chips.add(_breadcrumbCrumb(
              folder.name,
              isLast ? boldStyle : normalStyle,
              onTap: isLast ? null : () => selectFolder(folder.localId),
            ));
          }
        } else if (path.length == 1) {
          chips.add(_breadcrumbChevron());
          chips.add(_breadcrumbCrumb(path[0].name, boldStyle));
        } else {
          chips.add(_breadcrumbChevron());
          chips.add(_breadcrumbCrumb('...', normalStyle));
          chips.add(_breadcrumbChevron());
          final parentFolder = path[path.length - 2];
          chips.add(_breadcrumbCrumb(
            parentFolder.name,
            normalStyle,
            onTap: () => selectFolder(parentFolder.localId),
          ));
          chips.add(_breadcrumbChevron());
          chips.add(_breadcrumbCrumb(path.last.name, boldStyle));
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(mainAxisSize: MainAxisSize.min, children: chips),
        );
      },
    );
  }

  Widget _breadcrumbChevron() =>
      const Icon(Icons.chevron_right, size: 18, color: AppColors.tertiaryText);

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
        borderRadius: BorderRadius.circular(AppRadius.xs),
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
      borderRadius: BorderRadius.circular(AppRadius.xs),
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
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageHorizontal,
            AppSpacing.sm,
            AppSpacing.pageHorizontal,
            AppSpacing.sm,
          ),
          child: AppInput(
            controller: _searchC,
            hintText: '搜索标题或内容...',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _searchC.text.isNotEmpty
                ? AppIconButton(
                    icon: Icons.clear,
                    iconSize: 18,
                    onPressed: () {
                      _searchC.clear();
                      _updateFilteredNotes();
                    },
                  )
                : null,
            onChanged: (_) => _updateFilteredNotes(),
          ),
        ),
        Expanded(
          child: totalItems == 0
              ? const SizedBox.shrink()
              : RefreshIndicator(
                  onRefresh: () async {},
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
                    itemCount: totalItems,
                    itemBuilder: (context, index) {
                      if (index < childFolders.length) {
                        final folder = childFolders[index];
                        return AnimatedListItem(
                          index: index,
                          child: Padding(
                            padding: const EdgeInsets.only(
                                bottom: AppSpacing.listItemGap),
                            child: _buildFolderCard(folder),
                          ),
                        );
                      }
                      final note = filtered[index - childFolders.length];
                      return AnimatedListItem(
                        index: index,
                        child: Padding(
                          padding: const EdgeInsets.only(
                              bottom: AppSpacing.listItemGap),
                          child: _buildNoteCard(note),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildFolderCard(Folder folder) {
    final isLongPressed = _longPressedItemId == folder.localId;

    return GestureDetector(
      onLongPressStart: (details) {
        setState(() {
          _longPressedItemId = folder.localId;
          _longPressPosition = details.globalPosition;
        });
      },
      onLongPress: () {
        if (_longPressPosition == null) return;
        final overlay =
            Overlay.of(context).context.findRenderObject() as RenderBox;
        _showFolderItemMenu(
          folder,
          RelativeRect.fromRect(
            Rect.fromPoints(_longPressPosition!, _longPressPosition!),
            Offset.zero & overlay.size,
          ),
        );
      },
      child: AppCard(
        color: isLongPressed
            ? Theme.of(context).colorScheme.primaryContainer
            : null,
        onTap: () => selectFolder(folder.localId),
        child: Row(
          children: [
            const Icon(Icons.folder_outlined, color: AppColors.brand),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                folder.name,
                style: AppTypography.bodyMediumLight(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.tertiaryText),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteCard(Note note) {
    final preview = _plainText(note.content);
    final thumbnail = _firstImage(note.content);

    return GestureDetector(
      onLongPressStart: (details) {
        setState(() {
          _longPressedItemId = note.localId;
          _longPressPosition = details.globalPosition;
        });
      },
      onLongPress: () async {
        if (_longPressPosition == null) return;
        final overlay =
            Overlay.of(context).context.findRenderObject() as RenderBox;
        final result = await showMenu<String>(
          context: context,
          position: RelativeRect.fromRect(
            Rect.fromPoints(_longPressPosition!, _longPressPosition!),
            Offset.zero & overlay.size,
          ),
          items: [
            const PopupMenuItem(
              value: 'delete',
              child: AppListTile(
                leading: Icon(Icons.delete_outline, size: 20),
                title: '删除',
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
      child: AppCard(
        onTap: () => openEditor(note),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    note.title,
                    style: AppTypography.bodyMediumLight(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (preview.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.captionLight(),
                    ),
                  ],
                ],
              ),
            ),
            if (thumbnail != null || note.syncStatus != 'synced') ...[
              const SizedBox(width: AppSpacing.md),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (thumbnail != null) _buildThumbnail(thumbnail),
                  if (note.syncStatus != 'synced')
                    const Icon(Icons.cloud_off,
                        size: 14, color: AppColors.tertiaryText),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
