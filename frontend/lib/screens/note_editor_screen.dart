import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:leevinote/models/note.dart';
import 'package:leevinote/models/folder.dart';
import 'package:leevinote/services/api_service.dart';
import 'package:leevinote/services/local_note_service.dart';
import 'package:leevinote/services/local_folder_service.dart';
import 'package:leevinote/screens/image_embed_builder.dart';

class _MoreAction {
  final IconData icon;
  final String label;
  final Attribute? toggleAttr;

  const _MoreAction({required this.icon, required this.label, this.toggleAttr});
}

class NoteEditorScreen extends StatefulWidget {
  final Note? note;

  const NoteEditorScreen({super.key, this.note});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  String _title = '';
  int? _selectedFolderId;
  String? _selectedLocalFolderId;
  late final QuillController _quillC;
  final _focusNode = FocusNode();
  Timer? _saveTimer;
  Note? _currentNote;
  StreamSubscription? _quillSubscription;

  @override
  void initState() {
    super.initState();
    _currentNote = widget.note;

    _title = widget.note?.title ?? '';
    _selectedFolderId = widget.note?.folderId;
    _selectedLocalFolderId = widget.note?.localFolderId;

    if (widget.note?.content != null && widget.note!.content!.isNotEmpty) {
      final delta = Delta.fromJson(jsonDecode(widget.note!.content!) as List);
      _quillC = QuillController(
        document: Document.fromDelta(delta),
        selection: const TextSelection.collapsed(offset: 0),
      );
    } else {
      _quillC = QuillController.basic();
    }

    _quillSubscription = _quillC.document.changes.listen((_) => _onChanged());
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _quillSubscription?.cancel();
    _quillC.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), _autoSave);
  }

  Future<void> _autoSave() async {
    if (!mounted) return;
    if (_title.trim().isEmpty && _quillC.document.isEmpty()) return;

    final local = context.read<LocalNoteService>();
    final delta = _quillC.document.toDelta().toJson();
    final content = jsonEncode(delta);

    final existing = _currentNote;
    if (existing == null) {
      final note = Note(
        title: _title.trim().isEmpty ? '无标题' : _title.trim(),
        content: content,
        folderId: _selectedFolderId,
        localFolderId: _selectedLocalFolderId,
        syncStatus: 'local',
      );
      await local.addNote(note);
      _currentNote = note;
    } else {
      final updated = existing.copyWith(
        title: _title.trim().isEmpty ? '无标题' : _title.trim(),
        content: content,
        folderId: _selectedFolderId != null ? () => _selectedFolderId : null,
        localFolderId: _selectedLocalFolderId != null ? () => _selectedLocalFolderId : null,
        updatedAt: DateTime.now(),
        syncStatus:
            existing.syncStatus == 'synced' ? 'modified' : existing.syncStatus,
      );
      await local.updateNote(updated);
      _currentNote = updated;
    }
  }

  void _close() {
    _saveTimer?.cancel();
    if (mounted) {
      _autoSave().then((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  Future<void> _pickAndInsertImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    if (!mounted) return;
    final api = context.read<ApiService>();

    try {
      Map<String, dynamic> resp;
      if (file.bytes != null) {
        resp = await api.uploadBytes('/files/upload', file.bytes!, file.name);
      } else if (file.path != null) {
        resp = await api.uploadFile('/files/upload', file.path!);
      } else {
        return;
      }

      final filename = resp['url'] as String;
      if (!mounted) return;
      final index = _quillC.selection.baseOffset;
      final length = _quillC.selection.extentOffset - index;

      _quillC.replaceText(
        index,
        length,
        BlockEmbed.image(filename),
        TextSelection.collapsed(offset: index + 1),
      );
    } catch (e, st) {
      debugPrint('图片上传失败: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('图片上传失败: $e')),
        );
      }
    }
  }

  void _toggleAttr(Attribute attr) {
    final sel = _quillC.selection;
    _quillC.formatText(sel.baseOffset, sel.extentOffset - sel.baseOffset, attr);
  }

  List<_MoreAction> get _moreActions => [
        const _MoreAction(
            icon: Icons.format_bold, label: '粗体', toggleAttr: Attribute.bold),
        const _MoreAction(
            icon: Icons.format_italic,
            label: '斜体',
            toggleAttr: Attribute.italic),
        const _MoreAction(
            icon: Icons.format_underline,
            label: '下划线',
            toggleAttr: Attribute.underline),
        const _MoreAction(
            icon: Icons.format_strikethrough,
            label: '删除线',
            toggleAttr: Attribute.strikeThrough),
        const _MoreAction(icon: Icons.format_size, label: '字号'),
        const _MoreAction(icon: Icons.title, label: '字体'),
        const _MoreAction(
            icon: Icons.format_quote,
            label: '引用',
            toggleAttr: Attribute.blockQuote),
        const _MoreAction(
            icon: Icons.code, label: '代码块', toggleAttr: Attribute.codeBlock),
        const _MoreAction(icon: Icons.format_align_left, label: '对齐'),
        const _MoreAction(icon: Icons.format_indent_increase, label: '缩进'),
        const _MoreAction(icon: Icons.link, label: '链接'),
        const _MoreAction(icon: Icons.subscript, label: '下标'),
        const _MoreAction(icon: Icons.superscript, label: '上标'),
        const _MoreAction(icon: Icons.format_clear, label: '清除格式'),
      ];

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _moreActions.map((a) {
            return InkWell(
              onTap: () {
                Navigator.pop(ctx);
                if (a.toggleAttr != null) _toggleAttr(a.toggleAttr!);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(a.icon, size: 24),
                  const SizedBox(height: 4),
                  Text(a.label, style: const TextStyle(fontSize: 11)),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _editTitle() async {
    final textController = TextEditingController(text: _title);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改标题'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(hintText: '标题'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, textController.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (result != null && result.isNotEmpty) {
      _title = result;
      setState(() {});
      Future.microtask(() {
        if (mounted) _onChanged();
      });
    }
  }

  Future<void> _editCategory() async {
    final folderService = context.read<LocalFolderService>();
    await folderService.ensureLoaded();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final folders = folderService.folders.where((f) => f.syncStatus != 'deleted').toList();
          final idToLocalId = <int, String>{for (final f in folders) if (f.id != null) f.id!: f.localId};
          final childrenMap = <String?, List<Folder>>{};
          for (final f in folders) {
            final parentKey = f.localParentId ?? (f.parentId != null ? idToLocalId[f.parentId] : null);
            (childrenMap[parentKey] ??= []).add(f);
          }
          for (final list in childrenMap.values) {
            list.sort((a, b) => a.name.compareTo(b.name));
          }
          final rootFolders = childrenMap[null] ?? const <Folder>[];

          Future<void> addSubFolder(Folder parent) async {
            final nameC = TextEditingController();
            final name = await showDialog<String>(
              context: context,
              builder: (dCtx) => AlertDialog(
                title: Text('在"${parent.name}"下新建'),
                content: TextField(
                  controller: nameC,
                  autofocus: true,
                  decoration: const InputDecoration(hintText: '文件夹名称'),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('取消')),
                  TextButton(onPressed: () => Navigator.pop(dCtx, nameC.text.trim()), child: const Text('确定')),
                ],
              ),
            );
            if (name != null && name.isNotEmpty) {
              await folderService.addFolder(Folder(
                name: name,
                parentId: parent.id,
                localParentId: parent.localId,
              ));
              setSheetState(() {});
            }
          }

          List<Widget> buildFolderTree(List<Folder> items) {
            return items.map((folder) {
              final children = childrenMap[folder.localId] ?? const <Folder>[];
              final addBtn = IconButton(
                icon: const Icon(Icons.add, size: 18),
                tooltip: '新建子文件夹',
                onPressed: () => addSubFolder(folder),
              );
              void selectFolder() {
                setState(() {
                  _selectedFolderId = folder.id;
                  _selectedLocalFolderId = folder.localId;
                });
                Navigator.pop(ctx);
              }
              if (children.isEmpty) {
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.folder, size: 20),
                  title: Text(folder.name),
                  selected: _selectedFolderId == folder.id,
                  trailing: addBtn,
                  onTap: selectFolder,
                );
              }
              return ExpansionTile(
                leading: const Icon(Icons.folder, size: 20),
                title: Text(folder.name),
                trailing: addBtn,
                children: buildFolderTree(children),
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
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.folder_off, size: 20),
                          title: const Text('无文件夹'),
                          selected: _selectedFolderId == null && _selectedLocalFolderId == null,
                          onTap: () {
                            setState(() {
                              _selectedFolderId = null;
                              _selectedLocalFolderId = null;
                            });
                            Navigator.pop(ctx);
                          },
                        ),
                        if (rootFolders.isNotEmpty) ...[
                          const Divider(),
                          ...buildFolderTree(rootFolders),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: '新建文件夹名称',
                          border: OutlineInputBorder(),
                          prefixIcon:
                              Icon(Icons.create_new_folder_outlined, size: 20),
                        ),
                        onSubmitted: (v) async {
                          if (v.trim().isNotEmpty) {
                            await folderService
                                .addFolder(Folder(name: v.trim()));
                            setSheetState(() {});
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('确定'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _title.isEmpty ? (_currentNote != null ? '未命名' : '新建笔记') : _title;
    final folders = context.watch<LocalFolderService>().folders.where((f) => f.syncStatus != 'deleted').toList();
    final selectedFolder = _selectedFolderId != null
        ? folders.where((f) => f.id == _selectedFolderId).firstOrNull
        : null;

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: _editTitle,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(title, style: const TextStyle(fontSize: 16)),
          ),
        ),
        centerTitle: false,
        actions: [
          TextButton(
            onPressed: _editCategory,
            child: Text(
              selectedFolder != null ? selectedFolder.name : '文件夹',
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const Divider(height: 1),
          QuillSimpleToolbar(
            controller: _quillC,
            config: QuillSimpleToolbarConfig(
              showBoldButton: false,
              showItalicButton: false,
              showUnderLineButton: false,
              showStrikeThrough: false,
              showInlineCode: false,
              showFontFamily: false,
              showFontSize: false,
              showHeaderStyle: false,
              showQuote: false,
              showCodeBlock: false,
              showListNumbers: true,
              showListBullets: true,
              showListCheck: true,
              showAlignmentButtons: false,
              showIndent: false,
              showLink: false,
              showUndo: true,
              showRedo: true,
              showColorButton: true,
              showBackgroundColorButton: false,
              showClearFormat: false,
              showSubscript: false,
              showSuperscript: false,
              showDirection: false,
              showSearchButton: false,
              showLineHeightButton: false,
              customButtons: [
                QuillToolbarCustomButtonOptions(
                  icon:
                      const Icon(Icons.add_photo_alternate_outlined, size: 20),
                  tooltip: '插入图片',
                  onPressed: _pickAndInsertImage,
                ),
                QuillToolbarCustomButtonOptions(
                  icon: const Icon(Icons.more_horiz, size: 20),
                  tooltip: '更多',
                  onPressed: _showMoreOptions,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: QuillEditor.basic(
              controller: _quillC,
              focusNode: _focusNode,
              scrollController: ScrollController(),
              config: QuillEditorConfig(
                placeholder: '开始写点什么...',
                padding: const EdgeInsets.symmetric(horizontal: 16),
                embedBuilders: [NoteImageEmbedBuilder()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
