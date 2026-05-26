import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:leevinote/models/note.dart';
import 'package:leevinote/services/api_service.dart';
import 'package:leevinote/services/auth_service.dart';
import 'package:leevinote/services/local_note_service.dart';
import 'package:leevinote/utils/constants.dart';
import 'package:leevinote/screens/note_editor_screen.dart';
import 'package:leevinote/screens/login_screen.dart';

class _FolderNode {
  final String name;
  final String path;
  final List<_FolderNode> children;
  _FolderNode(this.name, this.path, this.children);
}

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => NotesScreenState();
}

class NotesScreenState extends State<NotesScreen> {
  final _searchC = TextEditingController();
  String? _selectedCategory;
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  List<_FolderNode> _buildFolderTree(List<String> folders) {
    final root = <String, _FolderNode>{};

    for (final folder in folders) {
      final parts = folder.split('/');
      String currentPath = '';

      for (int i = 0; i < parts.length; i++) {
        final part = parts[i];
        currentPath = currentPath.isEmpty ? part : '$currentPath/$part';

        if (i == 0) {
          root.putIfAbsent(part, () => _FolderNode(part, currentPath, []));
        } else {
          final parentPath = parts.sublist(0, i).join('/');
          final parentNode = _findNode(root.values.toList(), parentPath);
          if (parentNode != null && !parentNode.children.any((c) => c.name == part)) {
            parentNode.children.add(_FolderNode(part, currentPath, []));
          }
        }
      }
    }

    final result = root.values.toList();
    _sortTreeInPlace(result);
    return result;
  }

  _FolderNode? _findNode(List<_FolderNode> nodes, String path) {
    for (final node in nodes) {
      if (node.path == path) return node;
      final found = _findNode(node.children, path);
      if (found != null) return found;
    }
    return null;
  }

  void _sortTreeInPlace(List<_FolderNode> nodes) {
    nodes.sort((a, b) => a.name.compareTo(b.name));
    for (final node in nodes) {
      if (node.children.isNotEmpty) {
        _sortTreeInPlace(node.children);
      }
    }
  }

  Widget _buildNodeWidget(_FolderNode node, Function(String) onSelect, String? selectedPath) {
    if (node.children.isEmpty) {
      return ListTile(
        dense: true,
        leading: const Icon(Icons.folder, size: 20),
        title: Text(node.name),
        selected: selectedPath == node.path,
        onTap: () => onSelect(node.path),
      );
    }
    return ExpansionTile(
      leading: const Icon(Icons.folder, size: 20),
      title: Text(node.name),
      children: node.children.map((child) => _buildNodeWidget(child, onSelect, selectedPath)).toList(),
    );
  }

  void _showFolderPicker(BuildContext context, Function(String?) onSelect) {
    final cats = _categories;
    if (cats.isEmpty) {
      onSelect(null);
      return;
    }

    final tree = _buildFolderTree(cats);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('选择文件夹'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.folder_special, size: 20),
                  title: const Text('全部文件夹'),
                  onTap: () {
                    final callback = onSelect;
                    Navigator.pop(ctx);
                    callback(null);
                  },
                ),
                const Divider(),
                ...tree.map((node) => _buildNodeWidget(node, (path) {
                  final callback = onSelect;
                  Navigator.pop(ctx);
                  callback(path);
                }, _selectedCategory)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LocalNoteService>().ensureLoaded();
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

  List<Note> get _filteredNotes {
    return _notes.where((n) {
      if (n.syncStatus == 'deleted') return false;
      if (_selectedCategory != null && n.category != _selectedCategory) return false;
      if (_searchC.text.isNotEmpty) {
        final q = _searchC.text.toLowerCase();
        final matchTitle = n.title.toLowerCase().contains(q);
        final matchContent = _plainText(n.content).toLowerCase().contains(q);
        if (!matchTitle && !matchContent) return false;
      }
      return true;
    }).toList();
  }

  List<String> get _categories {
    return _notes
        .map((n) => n.category)
        .where((c) => c != null && c.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList()
      ..sort();
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

    try {
      await local.ensureLoaded();
      final localNotes = local.notes;

      // Push local changes
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

      // Pull remote notes
      final remoteData = await api.getList(ApiConstants.notes);
      for (final e in remoteData) {
        final remote = Note.fromJson(e as Map<String, dynamic>).copyWith(syncStatus: 'synced');
        await local.addOrUpdateFromRemote(remote);
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
    } finally {}
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
                onTap: () => _showFolderPicker(context, (path) {
                  setState(() => _selectedCategory = path);
                }),
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
                      Text(_selectedCategory ?? '全部文件夹', style: const TextStyle(fontSize: 14)),
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
                                        trailing: note.category != null
                                            ? Chip(label: Text(note.category!, style: const TextStyle(fontSize: 12)))
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
