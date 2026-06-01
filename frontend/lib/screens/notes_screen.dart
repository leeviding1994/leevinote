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
  List<Folder> get _folders => context.watch<LocalFolderService>().folders;

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

  List<Folder> get _rootFolders =>
      _folders.where((f) => f.parentId == null).toList()..sort((a, b) => a.name.compareTo(b.name));

  List<Folder> childFolders(int? parentId) =>
      _folders.where((f) => f.parentId == parentId).toList()..sort((a, b) => a.name.compareTo(b.name));

  String _folderName(int? folderId) {
    if (folderId == null) return '';
    final folder = _folders.where((f) => f.id == folderId || f.localId == _folders.where((f2) => f2.id == folderId).firstOrNull?.localId).firstOrNull;
    return folder?.name ?? '';
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
      final localNotes = local.notes;

      for (final note in List.from(localNotes)) {
        if (note.syncStatus == 'local' && note.id == null) {
          final resp = await api.post(ApiConstants.notes, note.toRemoteJson());
          final remoteId = resp['id'];
          final updated = note.copyWith(
            id: remoteId is int ? remoteId : int.tryParse(remoteId?.toString() ?? ''),
            syncStatus: 'synced',
          );
          await local.updateNote(updated);
        } else if (note.syncStatus == 'modified' && note.id != null) {
          await api.put('${ApiConstants.notes}/${note.id}', note.toRemoteJson());
          await local.updateNote(note.copyWith(syncStatus: 'synced'));
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

      // Sync folders
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

  List<Widget> _buildFolderTreeWidget(List<Folder> folders, Function(int) onSelect) {
    if (folders.isEmpty) return [];
    return folders.map((folder) {
      final children = childFolders(folder.id);
      if (children.isEmpty) {
        return ListTile(
          dense: true,
          leading: const Icon(Icons.folder, size: 20),
          title: Text(folder.name),
          selected: _selectedFolderId == folder.id,
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            onPressed: () => _deleteFolder(folder),
          ),
          onTap: () => onSelect(folder.id!),
        );
      }
      return ExpansionTile(
        leading: const Icon(Icons.folder, size: 20),
        title: Text(folder.name),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 18),
          onPressed: () => _deleteFolder(folder),
        ),
        children: [
          ..._buildFolderTreeWidget(children, onSelect),
          ListTile(
              dense: true,
              leading: const Icon(Icons.folder, size: 20),
              title: Text(folder.name),
              selected: _selectedFolderId == folder.id,
              onTap: () => onSelect(folder.id!),
            ),
          ],
        );
      }).toList();
  }

  void _deleteFolder(Folder folder) async {
    final folderService = context.read<LocalFolderService>();
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
      await folderService.deleteFolder(folder.localId);
      if (_selectedFolderId == folder.id) {
        setState(() => _selectedFolderId = null);
      }
    }
  }

  void _addSubFolder(Folder? parent) async {
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
      ));
    }
  }

  void _showFolderPicker() {
    if (_folders.isEmpty) {
      _addSubFolder(null);
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('选择文件夹'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.folder_special, size: 20),
                  title: const Text('全部文件夹'),
                  selected: _selectedFolderId == null,
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _selectedFolderId = null);
                  },
                ),
                const Divider(),
                ..._buildFolderTreeWidget(_rootFolders, (folderId) {
                  Navigator.pop(ctx);
                  setState(() => _selectedFolderId = folderId);
                }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _addSubFolder(null);
            },
            icon: const Icon(Icons.create_new_folder, size: 18),
            label: const Text('新建文件夹'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredNotes;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              InkWell(
                onTap: _showFolderPicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).colorScheme.outline),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.folder, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        _selectedFolderId == null
                            ? '全部文件夹'
                            : _folderName(_selectedFolderId),
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
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
            ],
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
          child: _notes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.note_add, size: 64,
                          color: Theme.of(context).colorScheme.outline),
                      const SizedBox(height: 16),
                      Text('还没有笔记，点击右下角新建',
                          style: TextStyle(color: Theme.of(context).colorScheme.outline)),
                    ],
                  ),
                )
              : filtered.isEmpty
                  ? const Center(child: Text('没有匹配的笔记'))
                  : RefreshIndicator(
                      onRefresh: () async {},
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final note = filtered[index];
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
                                        trailing: note.folderId != null
                                            ? Chip(label: Text(_folderName(note.folderId), style: const TextStyle(fontSize: 12)))
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