import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:leevinote/design/app_theme.dart';
import 'package:leevinote/models/note.dart';
import 'package:leevinote/models/folder.dart';
import 'package:leevinote/services/api_service.dart';
import 'package:leevinote/services/local_note_service.dart';
import 'package:leevinote/services/local_folder_service.dart';
import 'package:leevinote/screens/image_embed_builder.dart';
import 'package:leevinote/widgets/widgets.dart';

class _MoreAction {
  final IconData icon;
  final String label;
  final Attribute? toggleAttr;

  const _MoreAction({required this.icon, required this.label, this.toggleAttr});
}

class NoteEditorScreen extends StatefulWidget {
  final Note? note;
  final String? defaultLocalFolderId;

  const NoteEditorScreen({super.key, this.note, this.defaultLocalFolderId});

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
  bool _showMoreToolbar = false;

  @override
  void initState() {
    super.initState();
    _currentNote = widget.note;

    _title = widget.note?.title ?? '';
    _selectedFolderId = widget.note?.folderId;
    _selectedLocalFolderId = widget.note?.localFolderId ?? widget.defaultLocalFolderId;

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

    // 监听选区变化，实时更新工具栏按钮激活状态
    _quillC.addListener(() {
      if (mounted) setState(() {});
    });
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

    final title = _title.trim().isEmpty ? '无标题' : _title.trim();

    final existing = _currentNote;
    if (existing == null) {
      final note = Note(
        title: title,
        content: content,
        folderId: _selectedFolderId,
        localFolderId: _selectedLocalFolderId,
        syncStatus: 'local',
      );
      await local.addNote(note);
      _currentNote = note;
    } else {
      final updated = existing.copyWith(
        title: title,
        content: content,
        folderId: () => _selectedFolderId,
        localFolderId: () => _selectedLocalFolderId,
        updatedAt: DateTime.now(),
        syncStatus: existing.syncStatus == 'synced' ? 'modified' : existing.syncStatus,
      );
      await local.updateNote(updated);
      _currentNote = updated;
    }
  }

  void _close() {
    _saveTimer?.cancel();
    if (!mounted) return;

    _autoSave().then((_) {
      if (mounted) Navigator.pop(context);
    }).catchError((e, st) {
      debugPrint('保存失败: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
        Navigator.pop(context);
      }
    });
  }

  Future<void> _pickAndInsertImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    if (!mounted) return;

    try {
      String imagePath;
      if (kIsWeb) {
        final api = context.read<ApiService>();
        Map<String, dynamic> resp;
        if (file.bytes != null) {
          resp = await api.uploadBytes('/files/upload', file.bytes!, file.name);
        } else {
          return;
        }
        imagePath = resp['url'] as String;
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final imageDir = Directory('${dir.path}/leevinote/images');
        if (!await imageDir.exists()) {
          await imageDir.create(recursive: true);
        }
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final ext = file.extension ?? 'png';
        final localFile = File('${imageDir.path}/$timestamp.$ext');
        if (file.bytes != null) {
          await localFile.writeAsBytes(file.bytes!);
        } else if (file.path != null) {
          await File(file.path!).copy(localFile.path);
        }
        imagePath = 'local://${localFile.path}';
      }

      final index = _quillC.selection.baseOffset;
      final length = _quillC.selection.extentOffset - index;

      _quillC.replaceText(
        index,
        length,
        BlockEmbed.image(imagePath),
        TextSelection.collapsed(offset: index + 1),
      );
    } catch (e, st) {
      debugPrint('图片插入失败: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('图片插入失败: $e')),
        );
      }
    }
  }

  void _toggleAttr(Attribute attr) {
    final sel = _quillC.selection;
    _quillC.formatText(sel.start, sel.end - sel.start, attr);
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
        const _MoreAction(
            icon: Icons.format_list_numbered,
            label: '有序列表',
            toggleAttr: Attribute.ol),
        const _MoreAction(
            icon: Icons.format_list_bulleted,
            label: '无序列表',
            toggleAttr: Attribute.ul),
        const _MoreAction(
            icon: Icons.checklist,
            label: '任务列表',
            toggleAttr: Attribute.checked),
        const _MoreAction(
            icon: Icons.format_quote,
            label: '引用',
            toggleAttr: Attribute.blockQuote),
        const _MoreAction(
            icon: Icons.code, label: '代码块', toggleAttr: Attribute.codeBlock),
        const _MoreAction(
            icon: Icons.format_align_left, label: '对齐'),
        const _MoreAction(
            icon: Icons.format_indent_increase, label: '缩进'),
        const _MoreAction(icon: Icons.link, label: '链接'),
        const _MoreAction(icon: Icons.subscript, label: '下标'),
        const _MoreAction(icon: Icons.superscript, label: '上标'),
        const _MoreAction(icon: Icons.format_clear, label: '清除格式'),
      ];

  void _showMoreOptions() {
    setState(() {
      _showMoreToolbar = !_showMoreToolbar;
    });
  }

  void _showHeaderPicker() {
    final currentStyle = _quillC.getSelectionStyle();
    final currentHeader = currentStyle.attributes['header'];
    final currentValue = currentHeader?.value;

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('选择样式', style: AppTypography.h2Light()),
              const SizedBox(height: AppSpacing.lg),
              for (final entry in [
                ('文本', null),
                ('一级标题', 1),
                ('二级标题', 2),
                ('三级标题', 3),
              ])
                AppListTile(
                  leading: SizedBox(
                    width: 28,
                    height: 28,
                    child: Center(
                      child: Text(
                        entry.$2 == null ? 'T' : 'H${entry.$2}',
                        style: AppTypography.bodyMediumLight(
                          color: Theme.of(context).colorScheme.primary,
                        ).copyWith(
                          fontSize: entry.$2 == null ? 14 : (14 + (entry.$2! * 2)).toDouble(),
                        ),
                      ),
                    ),
                  ),
                  title: entry.$1,
                  trailing: currentValue == entry.$2
                      ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    final sel = _quillC.selection;
                    if (entry.$2 == null) {
                      _quillC.formatText(sel.baseOffset, sel.extentOffset - sel.baseOffset, Attribute.header);
                    } else if (entry.$2 == 1) {
                      _quillC.formatText(sel.baseOffset, sel.extentOffset - sel.baseOffset, Attribute.h1);
                    } else if (entry.$2 == 2) {
                      _quillC.formatText(sel.baseOffset, sel.extentOffset - sel.baseOffset, Attribute.h2);
                    } else if (entry.$2 == 3) {
                      _quillC.formatText(sel.baseOffset, sel.extentOffset - sel.baseOffset, Attribute.h3);
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSimpleColorPicker() {
    final currentStyle = _quillC.getSelectionStyle();
    final currentColor = currentStyle.attributes['color']?.value;
    final colors = [
      (AppColors.primaryText, '黑色'),
      (AppColors.error, '红色'),
      (AppColors.warning, '橙色'),
      (Colors.yellow.shade700, '黄色'),
      (AppColors.success, '绿色'),
      (AppColors.brand, '蓝色'),
      (const Color(0xFF8B5CF6), '紫色'),
      (AppColors.secondaryText, '灰色'),
    ];

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('选择颜色', style: AppTypography.h2Light()),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  for (final c in colors)
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        final sel = _quillC.selection;
                        _quillC.formatText(
                          sel.baseOffset,
                          sel.extentOffset - sel.baseOffset,
                          ColorAttribute('#${c.$1.toARGB32().toRadixString(16).substring(2)}'),
                        );
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: c.$1,
                          shape: BoxShape.circle,
                          border: currentColor != null &&
                                  c.$1.toARGB32().toString() == currentColor.toString()
                              ? Border.all(color: Theme.of(context).colorScheme.surface, width: 3)
                              : Border.all(color: AppColors.border, width: 1),
                          boxShadow: currentColor != null &&
                                  c.$1.toARGB32().toString() == currentColor.toString()
                              ? AppShadows.light
                              : null,
                        ),
                        child: currentColor != null &&
                                c.$1.toARGB32().toString() == currentColor.toString()
                            ? const Icon(Icons.check, color: Colors.white, size: 20)
                            : null,
                      ),
                    ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      final sel = _quillC.selection;
                      _quillC.formatText(
                        sel.baseOffset,
                        sel.extentOffset - sel.baseOffset,
                        const ColorAttribute(null),
                      );
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.border, width: 1),
                      ),
                      child: const Icon(Icons.format_clear, color: AppColors.tertiaryText, size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editTitle() async {
    final textController = TextEditingController(text: _title);
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
                Text('修改标题', style: AppTypography.h2Light()),
                const SizedBox(height: AppSpacing.lg),
                AppInput(
                  controller: textController,
                  hintText: '标题',
                  autofocus: true,
                  onEditingComplete: () => Navigator.pop(ctx, textController.text.trim()),
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
                        onPressed: () => Navigator.pop(ctx, textController.text.trim()),
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
    if (!mounted) return;

    final expandedFolders = <String>{};
    final prevLocalFolderId = _selectedLocalFolderId;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          if (_selectedLocalFolderId == null && _selectedFolderId != null) {
            final match = folderService.folders
                .where((f) => f.id == _selectedFolderId)
                .firstOrNull;
            if (match != null) {
              _selectedLocalFolderId = match.localId;
            }
          }
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
              builder: (dCtx) => Dialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('在"${parent.name}"下新建', style: AppTypography.h2Light()),
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
                                onPressed: () => Navigator.pop(dCtx),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: AppButton(
                                label: '确定',
                                onPressed: () => Navigator.pop(dCtx, nameC.text.trim()),
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
            if (name != null && name.isNotEmpty) {
              await folderService.addFolder(Folder(
                name: name,
                parentId: parent.id,
                localParentId: parent.localId,
              ));
              setSheetState(() {});
            }
          }

          List<Widget> buildFolderTree(List<Folder> items, {int depth = 0}) {
            final leftPadding = AppSpacing.pageHorizontal + depth * 24.0;
            return items.map((folder) {
              if (folder.localId == _selectedLocalFolderId) {
                // nop
              }
              final children = childrenMap[folder.localId] ?? const <Folder>[];
              final hasChildren = children.isNotEmpty;
              final isExpanded = expandedFolders.contains(folder.localId);
              final isSelected = _selectedLocalFolderId == folder.localId;

              void selectFolder() {
                setState(() {
                  _selectedFolderId = folder.id;
                  _selectedLocalFolderId = folder.localId;
                });
                Navigator.pop(ctx);
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: selectFolder,
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
                              style: AppTypography.bodyLight(
                                color: isSelected ? Theme.of(context).colorScheme.primary : null,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isSelected)
                            Icon(Icons.check, size: 18, color: Theme.of(context).colorScheme.primary),
                          AppIconButton(
                            icon: Icons.add,
                            iconSize: 18,
                            tooltip: '新建子文件夹',
                            onPressed: () => addSubFolder(folder),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (hasChildren && isExpanded)
                    ...buildFolderTree(children, depth: depth + 1),
                ],
              );
            }).toList();
          }

          final newFolderC = TextEditingController();

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
                        AppListTile(
                          leading: const Icon(Icons.folder_off, size: 20),
                          title: '无文件夹',
                          onTap: () {
                            setState(() {
                              _selectedFolderId = null;
                              _selectedLocalFolderId = null;
                            });
                            Navigator.pop(ctx);
                          },
                          trailing: _selectedLocalFolderId == null
                              ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                              : null,
                        ),
                        if (rootFolders.isNotEmpty) ...[
                          const Divider(height: 1),
                          ...buildFolderTree(rootFolders),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppInput(
                  controller: newFolderC,
                  hintText: '新建文件夹名称',
                  prefixIcon: const Icon(Icons.create_new_folder_outlined, size: 20),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (value) async {
                    final v = value.trim();
                    if (v.isNotEmpty) {
                      await folderService.addFolder(Folder(name: v));
                      newFolderC.clear();
                      setSheetState(() {});
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: '确定',
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (_selectedLocalFolderId != prevLocalFolderId && mounted) {
      _autoSave();
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _title.isEmpty ? (_currentNote != null ? '未命名' : '新建笔记') : _title;
    final folders = context.watch<LocalFolderService>().folders.where((f) => f.syncStatus != 'deleted').toList();
    final selectedFolder = _selectedLocalFolderId != null
        ? folders.where((f) => f.localId == _selectedLocalFolderId).firstOrNull
        : null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _close();
      },
      child: Scaffold(
        appBar: AppAppBar(
          leading: AppIconButton(
            icon: Icons.close,
            onPressed: _close,
          ),
          titleWidget: InkWell(
            onTap: _editTitle,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(title, style: AppTypography.bodyMediumLight()),
            ),
          ),
          actions: [
            AppButton.secondary(
              label: selectedFolder != null ? selectedFolder.name : '文件夹',
              onPressed: _editCategory,
              width: null,
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
        ),
        resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          Expanded(
            child: QuillEditor.basic(
              controller: _quillC,
              focusNode: _focusNode,
              scrollController: ScrollController(),
              config: QuillEditorConfig(
                placeholder: '开始写点什么...',
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
                embedBuilders: [NoteImageEmbedBuilder()],
                autoFocus: true,
                expands: true,
                enableInteractiveSelection: true,
              ),
            ),
          ),
          // 展开/收起：更多按钮行（在富文本工具栏上方）
          if (_showMoreToolbar)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.surfaceSecondaryDark
                  : AppColors.surfaceSecondary,
              child: Wrap(
                spacing: 2,
                runSpacing: 2,
                alignment: WrapAlignment.center,
                children: _moreActions.map((a) {
                  final isActive = a.toggleAttr != null &&
                      _quillC.getSelectionStyle().containsKey(a.toggleAttr!.key);
                  return IconButton(
                    icon: Icon(a.icon, size: 20),
                    tooltip: a.label,
                    color: isActive ? Theme.of(context).colorScheme.primary : null,
                    onPressed: () {
                      if (a.toggleAttr != null) {
                        _toggleAttr(a.toggleAttr!);
                      }
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  );
                }).toList(),
              ),
            ),
          const Divider(height: 1),
          // 富文本工具栏在最下方（更多按钮在同一行，作为最后一个按钮）
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
              showQuote: false,
              showCodeBlock: false,
              showListNumbers: false,
              showListBullets: false,
              showListCheck: false,
              showAlignmentButtons: false,
              showIndent: false,
              showLink: false,
              showUndo: true,
              showRedo: true,
              showColorButton: false,
              showBackgroundColorButton: false,
              showClearFormat: false,
              showSubscript: false,
              showSuperscript: false,
              showDirection: false,
              showSearchButton: false,
              showLineHeightButton: false,
              showDividers: false,
              showHeaderStyle: false,
              toolbarSectionSpacing: 2,
              toolbarRunSpacing: 2,
              toolbarSize: 36,
              customButtons: [
                QuillToolbarCustomButtonOptions(
                  icon: const Icon(Icons.title, size: 20),
                  tooltip: '文本 / 标题',
                  onPressed: _showHeaderPicker,
                ),
                QuillToolbarCustomButtonOptions(
                  icon: const Icon(Icons.color_lens, size: 20),
                  tooltip: '文字颜色',
                  onPressed: _showSimpleColorPicker,
                ),
                QuillToolbarCustomButtonOptions(
                  icon: const Icon(Icons.add_photo_alternate_outlined, size: 20),
                  tooltip: '插入图片',
                  onPressed: _pickAndInsertImage,
                ),
                QuillToolbarCustomButtonOptions(
                  icon: Icon(_showMoreToolbar ? Icons.expand_less : Icons.more_horiz, size: 20),
                  tooltip: '更多',
                  onPressed: _showMoreOptions,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
}
