import 'dart:convert';
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
  int? _selectedFolderId;
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

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

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final count = _selectedIds.length;
    final local = context.read<LocalNoteService>();
    final allNotes = local.notes;
    for (final id in _selectedIds.toList()) {
      final note = allNotes.where((n) => n.localId == id).firstOrNull;
      if (note == null) continue;
      if (note.id != null) {
        await local.updateNote(note.copyWith(syncStatus: 'deleted'));
      } else {
        await local.deleteNote(id);
      }
    }
    _exitSelectionMode();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已删除 $count 条笔记')),
      );
    }
  }

  List<Note> get _notes => context.watch<LocalNoteService>().notes;
  List<Folder> get _folders => context.watch<LocalFolderService>().folders.where((f) => f.syncStatus != 'deleted').toList();

  List<Note> get _filteredNotes {
    return _notes.where((n) {
      if (n.syncStatus == 'deleted') return false;
      if (_selectedFolderId != null && n.folderId != _selectedFolderId) return false;
      if (_searchC.text.isNotEmpty) {
        final q = _searchC.text.toLowerCase();
        final matchTitle = n.title.toLowerCase().contains(q);
        final matchContent = _plainText(n.content).toLowerCase().contains(q);
        if (!matchTitle && !matchContent) return false;
      }
      return true;
    }).toList();
  }

  List<Folder> get _childFolders {
    return _folders.where((f) {
      if (f.syncStatus == 'deleted') return false;
      return _getParentIdOf(f) == _selectedFolderId;
    }).toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  int? _getParentIdOf(Folder folder) {
    if (folder.localParentId != null) {
      final parent = _folders.firstWhere((f) => f.localId == folder.localParentId, orElse: () => Folder(name: ''));
      return parent.id;
    }
    return folder.parentId;
  }

  List<Folder> _buildBreadcrumb(int folderId) {
    final path = <Folder>[];
    final idMap = <int, Folder>{for (final f in _folders) if (f.id != null) f.id!: f};
    int? currentId = folderId;
    while (currentId != null && idMap.containsKey(currentId)) {
      path.insert(0, idMap[currentId]!);
      currentId = _getParentIdOf(idMap[currentId]!);
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
      final folderByLocalId = <String, Folder>{for (final f in localFolders) f.localId: f};
      
      void visit(Folder f) {
        if (visited.contains(f.localId)) return;
        visited.add(f.localId);
        // Visit parent first
        if (f.localParentId != null && folderByLocalId.containsKey(f.localParentId)) {
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
          if (folder.localParentId != null && localIdToRemoteId.containsKey(folder.localParentId)) {
            parentId = localIdToRemoteId[folder.localParentId];
          }
          final remoteJson = {
            'name': folder.name,
            'parent_id': parentId,
          };
          final resp = await api.post(ApiConstants.folders, remoteJson);
          final remoteId = resp['id'];
          final newId = remoteId is int ? remoteId : int.tryParse(remoteId?.toString() ?? '');
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
          if (folder.localParentId != null && localIdToRemoteId.containsKey(folder.localParentId)) {
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
          if (note.localFolderId != null && localIdToRemoteId.containsKey(note.localFolderId)) {
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
            id: remoteId is int ? remoteId : int.tryParse(remoteId?.toString() ?? ''),
            folderId: () => folderId,
            syncStatus: 'synced',
          );
          await local.updateNote(updated);
        } else if (note.syncStatus == 'modified' && note.id != null) {
          int? folderId = note.folderId;
          if (note.localFolderId != null && localIdToRemoteId.containsKey(note.localFolderId)) {
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
        final remote = Note.fromJson(e as Map<String, dynamic>).copyWith(syncStatus: 'synced');
        await local.addOrUpdateFromRemote(remote);
      }

      final remoteFolders = await api.getList(ApiConstants.folders);
      for (final e in remoteFolders) {
        final remote = Folder.fromJson(e as Map<String, dynamic>);
        await folderService.addOrUpdateFromRemote(remote.copyWith(syncStatus: 'synced'));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('同步完成')),
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
          SnackBar(content: Text('同步失败: $e')),
        );
      }
    }
  }

  Future<void> openEditor(Note? note) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note)),
    );
  }

  Future<void> openEditorInFolder(int? folderId) async {
    setState(() => _selectedFolderId = folderId);
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NoteEditorScreen(note: null)),
    );
  }

  void selectFolder(int? folderId) {
    setState(() => _selectedFolderId = folderId);
  }

  String _plainText(String? content) {
    if (content == null || content.isEmpty) return '';
    try {
      final delta = jsonDecode(content) as List;
      return delta
          .map((op) => (op as Map)['insert']?.toString() ?? '')
          .join()
          .trim();
    } catch (_) {
      return content;
    }
  }



  @override
  Widget build(BuildContext context) {
    final filtered = _filteredNotes;
    final childFolders = _searchC.text.isEmpty ? _childFolders : <Folder>[];
    final totalItems = childFolders.length + filtered.length;

    return Column(
      children: [
        if (_selectedFolderId != null)
          Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () => setState(() => _selectedFolderId = null),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                      child: Text('全部', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 14)),
                    ),
                  ),
                  ..._buildBreadcrumb(_selectedFolderId!).expand((folder) => [
                    Icon(Icons.chevron_right, size: 18, color: Theme.of(context).colorScheme.outline),
                    InkWell(
                      onTap: () => setState(() => _selectedFolderId = folder.id),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                        child: Text(
                          folder.name,
                          style: TextStyle(
                            color: folder.id == _selectedFolderId
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(context).colorScheme.primary,
                            fontSize: 14,
                            fontWeight: folder.id == _selectedFolderId ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            controller: _searchC,
            decoration: InputDecoration(
              hintText: '搜索标题或内容...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchC.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchC.clear();
                        setState(() {});
                      },
                    )
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const Divider(height: 1),
        if (_selectionMode)
          Container(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _exitSelectionMode,
                ),
                Text('已选 ${_selectedIds.length} 项'),
                const Spacer(),
                TextButton.icon(
                  onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('删除'),
                ),
              ],
            ),
          ),
        Expanded(
          child: totalItems == 0 && !_selectionMode
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.note_add, size: 64,
                          color: Theme.of(context).colorScheme.outline),
                      const SizedBox(height: 16),
                      Text('还没有内容，点击右下角新建',
                          style: TextStyle(color: Theme.of(context).colorScheme.outline)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {},
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: totalItems,
                    itemBuilder: (context, index) {
                      if (index < childFolders.length) {
                        final folder = childFolders[index];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.folder, size: 24),
                            title: Text(folder.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                            onTap: () => setState(() => _selectedFolderId = folder.id),
                          ),
                        );
                      }
                      final note = filtered[index - childFolders.length];
                      final preview = _plainText(note.content);
                      return Card(
                        child: InkWell(
                          onTap: () {
                            if (_selectionMode) {
                              setState(() {
                                if (_selectedIds.contains(note.localId)) {
                                  _selectedIds.remove(note.localId);
                                  if (_selectedIds.isEmpty) _selectionMode = false;
                                } else {
                                  _selectedIds.add(note.localId);
                                }
                              });
                            } else {
                              openEditor(note);
                            }
                          },
                          onLongPress: () {
                            setState(() {
                              _selectionMode = true;
                              _selectedIds.add(note.localId);
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Row(
                              children: [
                                if (_selectionMode)
                                  Checkbox(
                                    value: _selectedIds.contains(note.localId),
                                    onChanged: (v) {
                                      setState(() {
                                        if (v == true) {
                                          _selectedIds.add(note.localId);
                                        } else {
                                          _selectedIds.remove(note.localId);
                                          if (_selectedIds.isEmpty) _selectionMode = false;
                                        }
                                      });
                                    },
                                  ),
                                Expanded(
                                  child: ListTile(
                                    title: Row(
                                      children: [
                                        Expanded(child: Text(note.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
                                        if (note.syncStatus != 'synced')
                                          Padding(
                                            padding: const EdgeInsets.only(left: 4),
                                            child: Icon(Icons.cloud_off, size: 14,
                                                color: Theme.of(context).colorScheme.outline),
                                          ),
                                      ],
                                    ),
                                    subtitle: preview.isNotEmpty
                                        ? Text(preview, maxLines: 2, overflow: TextOverflow.ellipsis)
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}