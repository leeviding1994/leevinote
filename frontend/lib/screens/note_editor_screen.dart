import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart';
import 'package:leevinote/design/app_theme.dart';
import 'package:leevinote/models/note.dart';
import 'package:leevinote/models/folder.dart';
import 'package:leevinote/providers/note_editor_provider.dart';
import 'package:leevinote/services/local_folder_service.dart';
import 'package:leevinote/screens/image_embed_builder.dart';
import 'package:leevinote/widgets/widgets.dart';

class _ToolbarAction {
  final IconData? icon;
  final String? shortLabel;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool isEnabled;
  final bool isHeaderStyle;
  final double width;

  const _ToolbarAction({
    this.icon,
    this.shortLabel,
    required this.label,
    required this.onTap,
    this.isActive = false,
    this.isEnabled = true,
    this.isHeaderStyle = false,
    this.width = 32,
  });
}

class _OutlineItem {
  final String title;
  final int level;
  final int offset;

  const _OutlineItem({
    required this.title,
    required this.level,
    required this.offset,
  });
}

class NoteEditorScreen extends ConsumerStatefulWidget {
  final Note? note;
  final String? defaultLocalFolderId;

  const NoteEditorScreen({super.key, this.note, this.defaultLocalFolderId});

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  static const _editorFontSize = 16.0;
  static const _editorLineHeight = 1.7;

  late final NoteEditorArgs _args;
  late final QuillController _quillController;
  final _editorKey = GlobalKey<EditorState>();
  final _focusNode = FocusNode();
  final _editorScrollController = ScrollController();
  bool _showOutline = false;
  int _outlineJumpSerial = 0;

  @override
  void initState() {
    super.initState();
    _args = NoteEditorArgs(
      note: widget.note,
      defaultLocalFolderId: widget.defaultLocalFolderId,
    );
    final state = ref.read(noteEditorProvider(_args));
    _quillController = state.quillController;
    _quillController.addListener(_onQuillSelectionChanged);
  }

  @override
  void dispose() {
    _quillController.removeListener(_onQuillSelectionChanged);
    _focusNode.dispose();
    _editorScrollController.dispose();
    super.dispose();
  }

  void _onQuillSelectionChanged() {
    if (mounted) setState(() {});
  }

  TextRange? _currentCodeBlockRange(QuillController controller) {
    final document = controller.document;
    final offset = controller.selection.baseOffset;
    if (offset < 0 || document.length <= 0) return null;

    var safeOffset = offset.clamp(0, document.length - 1);
    var line = document.queryChild(safeOffset).node;
    if (line == null) return null;
    if (line.style.attributes[Attribute.codeBlock.key] == null &&
        safeOffset > 0) {
      line = document.queryChild(safeOffset - 1).node;
    }
    if (line == null) return null;
    if (line.style.attributes[Attribute.codeBlock.key] == null) return null;

    var start = line.documentOffset;
    var current = line.previous;
    while (current != null &&
        current.style.attributes[Attribute.codeBlock.key] != null) {
      start = current.documentOffset;
      current = current.previous;
    }

    var end = line.documentOffset + line.length;
    current = line.next;
    while (current != null &&
        current.style.attributes[Attribute.codeBlock.key] != null) {
      end = current.documentOffset + current.length;
      current = current.next;
    }

    return TextRange(start: start, end: end);
  }

  KeyEventResult _handleEditorKeyPressed(
    KeyEvent event,
    QuillController controller,
  ) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final isSelectAll = event.logicalKey == LogicalKeyboardKey.keyA &&
        (HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isMetaPressed);
    if (!isSelectAll) return KeyEventResult.ignored;

    final range = _currentCodeBlockRange(controller);
    if (range == null) return KeyEventResult.ignored;

    controller.updateSelection(
      TextSelection(baseOffset: range.start, extentOffset: range.end),
      ChangeSource.local,
    );
    return KeyEventResult.handled;
  }

  Future<void> _copyCurrentCodeBlock(QuillController controller) async {
    final range = _currentCodeBlockRange(controller);
    if (range == null) return;
    final text = controller.document
        .toPlainText()
        .substring(range.start, range.end)
        .trimRight();
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) AppToast.success(context, '代码已复制');
  }

  Future<void> _close() async {
    final notifier = ref.read(noteEditorProvider(_args).notifier);
    await notifier.saveNow();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickAndInsertImage() async {
    try {
      await ref.read(noteEditorProvider(_args).notifier).insertImage();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('图片插入失败: $e')),
        );
      }
    }
  }

  Future<void> _editCategory() async {
    final folderService = context.read<LocalFolderService>();
    await folderService.ensureLoaded();
    if (!mounted) return;

    final expandedFolders = <String>{};
    final editorState = ref.read(noteEditorProvider(_args));
    final prevLocalFolderId = editorState.selectedLocalFolderId;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          var selectedLocalFolderId = editorState.selectedLocalFolderId;
          var selectedFolderId = editorState.selectedFolderId;

          if (selectedLocalFolderId == null && selectedFolderId != null) {
            final match = folderService.folders
                .where((f) => f.id == selectedFolderId)
                .firstOrNull;
            if (match != null) {
              selectedLocalFolderId = match.localId;
            }
          }

          final folders = folderService.folders
              .where((f) => f.syncStatus != 'deleted')
              .toList();
          final idToLocalId = <int, String>{
            for (final f in folders)
              if (f.id != null) f.id!: f.localId
          };
          final childrenMap = <String?, List<Folder>>{};
          for (final f in folders) {
            final parentKey = f.localParentId ??
                (f.parentId != null ? idToLocalId[f.parentId] : null);
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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg)),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('在"${parent.name}"下新建',
                            style: AppTypography.h2Light()),
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
                                onPressed: () =>
                                    Navigator.pop(dCtx, nameC.text.trim()),
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
              final children = childrenMap[folder.localId] ?? const <Folder>[];
              final hasChildren = children.isNotEmpty;
              final isExpanded = expandedFolders.contains(folder.localId);
              final isSelected = selectedLocalFolderId == folder.localId;

              void selectFolder() {
                ref.read(noteEditorProvider(_args).notifier).setFolder(
                      folder.id,
                      folder.localId,
                    );
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
                            ref
                                .read(noteEditorProvider(_args).notifier)
                                .setFolder(null, null);
                            Navigator.pop(ctx);
                          },
                          trailing: selectedLocalFolderId == null
                              ? Icon(Icons.check,
                                  color: Theme.of(context).colorScheme.primary)
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
                  prefixIcon:
                      const Icon(Icons.create_new_folder_outlined, size: 20),
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

    final afterState = ref.read(noteEditorProvider(_args));
    if (afterState.selectedLocalFolderId != prevLocalFolderId) {
      await ref.read(noteEditorProvider(_args).notifier).saveNow();
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _buildSaveStatus(bool isDark, NoteEditorState editorState) {
    final color = editorState.hasUnsavedChanges || editorState.isSaving
        ? (isDark ? AppColors.secondaryTextDark : AppColors.secondaryText)
        : AppColors.success;
    final label = editorState.isSaving
        ? '正在保存'
        : editorState.hasUnsavedChanges
            ? '等待保存'
            : editorState.lastSavedAt == null
                ? '自动保存'
                : '已保存 ${_formatTime(editorState.lastSavedAt!)}';

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: Row(
        key: ValueKey(label),
        mainAxisSize: MainAxisSize.min,
        children: [
          if (editorState.isSaving)
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: color),
            )
          else
            Icon(
              editorState.hasUnsavedChanges
                  ? Icons.cloud_queue_outlined
                  : Icons.cloud_done_outlined,
              size: 15,
              color: color,
            ),
          const SizedBox(width: 6),
          Text(label, style: AppTypography.smallMediumLight(color: color)),
        ],
      ),
    );
  }

  Widget _buildTopBar({
    required bool isCompact,
    required bool isDark,
    required Folder? selectedFolder,
    required NoteEditorState editorState,
  }) {
    final borderColor = isDark ? AppColors.borderDark : AppColors.border;
    final surface = isDark ? AppColors.surfaceDark : AppColors.surface;

    return Container(
      height: 64,
      padding: EdgeInsets.symmetric(
          horizontal: isCompact ? AppSpacing.sm : AppSpacing.xl),
      decoration: BoxDecoration(
        color: surface,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          AppIconButton(
            icon: Icons.arrow_back,
            tooltip: '返回笔记列表',
            onPressed: _close,
          ),
          if (!isCompact) ...[
            const SizedBox(width: AppSpacing.sm),
            Text('编辑笔记',
                style: AppTypography.bodyMediumLight(
                  color: isDark
                      ? AppColors.primaryTextDark
                      : AppColors.primaryText,
                )),
          ],
          const Spacer(),
          if (!isCompact) ...[
            _buildSaveStatus(isDark, editorState),
            const SizedBox(width: AppSpacing.lg),
          ],
          Material(
            color: isDark
                ? AppColors.surfaceSecondaryDark
                : AppColors.surfaceSecondary,
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: InkWell(
              onTap: _editCategory,
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.folder_outlined,
                      size: 17,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 7),
                    ConstrainedBox(
                      constraints:
                          BoxConstraints(maxWidth: isCompact ? 88 : 180),
                      child: Text(
                        selectedFolder?.name ?? '未分类',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.captionMediumLight(
                          color: isDark
                              ? AppColors.primaryTextDark
                              : AppColors.primaryText,
                        ),
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      Icons.keyboard_arrow_down,
                      size: 17,
                      color: isDark
                          ? AppColors.secondaryTextDark
                          : AppColors.secondaryText,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentHeader({
    required bool isCompact,
    required bool isDark,
    required NoteEditorState editorState,
  }) {
    final secondaryColor =
        isDark ? AppColors.secondaryTextDark : AppColors.secondaryText;
    final updatedAt = editorState.lastSavedAt ??
        editorState.currentNote?.updatedAt ??
        DateTime.now();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isCompact ? 56 : 40,
        isCompact ? AppSpacing.xl : 40,
        isCompact ? AppSpacing.lg : 40,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: editorState.titleController,
            maxLines: 2,
            minLines: 1,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _focusNode.requestFocus(),
            style: (isDark ? AppTypography.h1Dark() : AppTypography.h1Light())
                .copyWith(
              fontSize: isCompact ? 28 : 34,
              height: 1.2,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              isDense: true,
              filled: false,
              hintText: '无标题笔记',
              hintStyle:
                  (isDark ? AppTypography.h1Dark() : AppTypography.h1Light())
                      .copyWith(
                fontSize: isCompact ? 28 : 34,
                color: isDark
                    ? AppColors.tertiaryTextDark
                    : AppColors.disabledText,
              ),
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Icon(Icons.schedule_outlined, size: 15, color: secondaryColor),
              const SizedBox(width: 6),
              Text('今天 ${_formatTime(updatedAt)}',
                  style: AppTypography.smallLight(color: secondaryColor)),
              if (isCompact) ...[
                const Spacer(),
                _buildSaveStatus(isDark, editorState),
              ],
            ],
          ),
        ],
      ),
    );
  }

  int? _currentHeaderLevel(QuillController controller) {
    final style = controller.getSelectionStyle();
    final header = style.attributes['header'];
    final value = header?.value;
    if (value == null) return null;
    return value is int ? value : int.tryParse(value.toString());
  }

  void _applyHeader(int? level) {
    final controller = ref.read(noteEditorProvider(_args)).quillController;
    final sel = controller.selection;
    final length = sel.end - sel.start;
    if (level == null) {
      controller.formatText(sel.start, length, Attribute.header);
    } else if (level == 1) {
      controller.formatText(sel.start, length, Attribute.h1);
    } else if (level == 2) {
      controller.formatText(sel.start, length, Attribute.h2);
    } else if (level == 3) {
      controller.formatText(sel.start, length, Attribute.h3);
    }
  }

  String _currentHeaderLabel(QuillController controller) {
    final level = _currentHeaderLevel(controller);
    if (level == null) return 'T';
    return 'H$level';
  }

  List<_OutlineItem> _outlineItems(QuillController controller) {
    final items = <_OutlineItem>[];
    var offset = 0;
    final buffer = StringBuffer();
    int? currentHeader;

    void flush() {
      final text = buffer.toString().trim();
      if (currentHeader != null && text.isNotEmpty) {
        items.add(_OutlineItem(
          title: text,
          level: currentHeader!,
          offset: offset - buffer.length,
        ));
      }
      buffer.clear();
      currentHeader = null;
    }

    for (final op in controller.document.toDelta().toList()) {
      final data = op.data;
      final text = data is String ? data : '';
      final attrs = op.attributes;
      for (var i = 0; i < text.length; i++) {
        final char = text[i];
        if (char == '\n') {
          final header = attrs?[Attribute.header.key];
          currentHeader = header is int ? header : int.tryParse('$header');
          flush();
        } else {
          buffer.write(char);
        }
        offset++;
      }
      if (data is! String) offset++;
    }
    flush();
    return items.where((item) => item.level >= 1 && item.level <= 3).toList();
  }

  void _jumpToOutlineItem(_OutlineItem item, QuillController controller) {
    final jumpSerial = ++_outlineJumpSerial;
    controller.ignoreFocusOnTextChange = true;
    controller.updateSelection(
      TextSelection.collapsed(offset: item.offset),
      ChangeSource.local,
    );
    controller.ignoreFocusOnTextChange = false;
    _focusNode.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || jumpSerial != _outlineJumpSerial) return;
      _jumpToOutlineOffset(item.offset);
    });
  }

  void _jumpToOutlineOffset(int offset) {
    if (!_editorScrollController.hasClients) return;
    final editorState = _editorKey.currentState;
    final renderEditor = editorState?.renderEditor;
    if (renderEditor == null) return;

    final caretRect = renderEditor.getLocalRectForCaret(
      TextPosition(offset: offset),
    );
    final target = caretRect.top.clamp(
      _editorScrollController.position.minScrollExtent,
      _editorScrollController.position.maxScrollExtent,
    );
    _editorScrollController.jumpTo(target);
  }

  bool _isAttributeActive(QuillController controller, Attribute attribute) {
    final attrs = controller.getSelectionStyle().attributes;
    final current = attrs[attribute.key];
    if (current == null) return false;
    return attribute.value == true || current.value == attribute.value;
  }

  void _toggleAttribute(Attribute attribute) {
    final controller = ref.read(noteEditorProvider(_args)).quillController;
    final isActive = _isAttributeActive(controller, attribute);
    controller.formatSelection(
      isActive ? Attribute.clone(attribute, null) : attribute,
    );
  }

  void _clearSelectionFormat() {
    final controller = ref.read(noteEditorProvider(_args)).quillController;
    final attributes = <Attribute>{};
    for (final style in controller.getAllSelectionStyles()) {
      attributes.addAll(style.attributes.values);
    }
    for (final attribute in attributes) {
      controller.formatSelection(Attribute.clone(attribute, null));
    }
  }

  List<_ToolbarAction> _toolbarActions(NoteEditorState editorState) {
    final controller = editorState.quillController;
    final isCodeBlockActive = _currentCodeBlockRange(controller) != null;

    return [
      _ToolbarAction(
        icon: Icons.undo_outlined,
        label: '撤销',
        isEnabled: controller.hasUndo,
        onTap: controller.undo,
      ),
      _ToolbarAction(
        icon: Icons.redo_outlined,
        label: '重做',
        isEnabled: controller.hasRedo,
        onTap: controller.redo,
      ),
      _ToolbarAction(
        shortLabel: _currentHeaderLabel(controller),
        label: '段落样式',
        width: 42,
        isHeaderStyle: true,
        onTap: () {},
      ),
      _ToolbarAction(
        icon: Icons.format_bold,
        label: '加粗',
        isActive: _isAttributeActive(controller, Attribute.bold),
        onTap: () => _toggleAttribute(Attribute.bold),
      ),
      _ToolbarAction(
        icon: Icons.format_italic,
        label: '斜体',
        isActive: _isAttributeActive(controller, Attribute.italic),
        onTap: () => _toggleAttribute(Attribute.italic),
      ),
      _ToolbarAction(
        icon: Icons.format_underline,
        label: '下划线',
        isActive: _isAttributeActive(controller, Attribute.underline),
        onTap: () => _toggleAttribute(Attribute.underline),
      ),
      _ToolbarAction(
        icon: Icons.format_strikethrough,
        label: '删除线',
        isActive: _isAttributeActive(controller, Attribute.strikeThrough),
        onTap: () => _toggleAttribute(Attribute.strikeThrough),
      ),
      _ToolbarAction(
        icon: Icons.format_list_numbered,
        label: '有序列表',
        isActive: _isAttributeActive(controller, Attribute.ol),
        onTap: () => _toggleAttribute(Attribute.ol),
      ),
      _ToolbarAction(
        icon: Icons.format_list_bulleted,
        label: '无序列表',
        isActive: _isAttributeActive(controller, Attribute.ul),
        onTap: () => _toggleAttribute(Attribute.ul),
      ),
      _ToolbarAction(
        icon: Icons.checklist,
        label: '任务列表',
        isActive: _isAttributeActive(controller, Attribute.checked),
        onTap: () => _toggleAttribute(Attribute.checked),
      ),
      _ToolbarAction(
        icon: Icons.link,
        label: '链接',
        isActive: _isAttributeActive(controller, Attribute.link),
        onTap: () => _showLinkDialog(controller),
      ),
      _ToolbarAction(
        icon: Icons.code,
        label: '行内代码',
        isActive: _isAttributeActive(controller, Attribute.inlineCode),
        onTap: () => _toggleAttribute(Attribute.inlineCode),
      ),
      _ToolbarAction(
        icon: Icons.format_quote,
        label: '引用',
        isActive: _isAttributeActive(controller, Attribute.blockQuote),
        onTap: () => _toggleAttribute(Attribute.blockQuote),
      ),
      _ToolbarAction(
        icon: Icons.data_object,
        label: '代码块',
        isActive: _isAttributeActive(controller, Attribute.codeBlock),
        onTap: () => _toggleAttribute(Attribute.codeBlock),
      ),
      if (isCodeBlockActive)
        _ToolbarAction(
          icon: Icons.copy,
          label: '复制代码',
          onTap: () => _copyCurrentCodeBlock(controller),
        ),
      _ToolbarAction(
        icon: Icons.add_photo_alternate_outlined,
        label: '插入图片',
        onTap: _pickAndInsertImage,
      ),
      _ToolbarAction(
        icon: Icons.format_clear,
        label: '清除格式',
        onTap: _clearSelectionFormat,
      ),
    ];
  }

  Future<void> _showLinkDialog(QuillController controller) async {
    final currentLink =
        controller.getSelectionStyle().attributes['link']?.value;
    final textController = TextEditingController(
      text: currentLink?.toString() ?? '',
    );

    final link = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('插入链接', style: AppTypography.h2Light()),
                const SizedBox(height: AppSpacing.lg),
                AppInput(
                  controller: textController,
                  hintText: 'https://example.com',
                  prefixIcon: const Icon(Icons.link, size: 20),
                  autofocus: true,
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: AppButton.secondary(
                        label: '移除',
                        onPressed: () => Navigator.pop(dialogContext, ''),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: AppButton(
                        label: '确定',
                        onPressed: () => Navigator.pop(
                          dialogContext,
                          textController.text.trim(),
                        ),
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
    textController.dispose();

    if (link == null) return;
    controller.formatSelection(LinkAttribute(link.isEmpty ? null : link));
  }

  PopupMenuItem<void> _toolbarMenuItem(_ToolbarAction item) {
    return PopupMenuItem<void>(
      enabled: item.isEnabled,
      onTap: () => Future<void>.delayed(
        Duration.zero,
        item.isHeaderStyle
            ? () => _showHeaderStyleMenu(context, _quillController)
            : item.onTap,
      ),
      child: Row(
        children: [
          if (item.icon != null)
            Icon(
              item.icon,
              size: 19,
              color:
                  item.isActive ? Theme.of(context).colorScheme.primary : null,
            )
          else
            SizedBox(
              width: 19,
              child: Text(
                item.shortLabel ?? '',
                textAlign: TextAlign.center,
                style: AppTypography.captionMediumLight(
                  color: item.isActive
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
              ),
            ),
          const SizedBox(width: AppSpacing.md),
          Flexible(
            child: Text(
              item.label,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (item.isActive) ...[
            const Spacer(),
            Icon(
              Icons.check,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ],
      ),
    );
  }

  PopupMenuItem<void> _headerStyleMenuItem({
    required QuillController controller,
    required String label,
    required int? level,
  }) {
    final isActive = _currentHeaderLevel(controller) == level;
    return PopupMenuItem<void>(
      onTap: () =>
          Future<void>.delayed(Duration.zero, () => _applyHeader(level)),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              level == null ? 'T' : 'H$level',
              style: AppTypography.captionMediumLight(
                color: isActive ? Theme.of(context).colorScheme.primary : null,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(label)),
          if (isActive)
            Icon(
              Icons.check,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
        ],
      ),
    );
  }

  Future<void> _showHeaderStyleMenu(
    BuildContext buttonContext,
    QuillController controller,
  ) async {
    final buttonBox = buttonContext.findRenderObject() as RenderBox?;
    final overlayBox =
        Overlay.of(buttonContext).context.findRenderObject() as RenderBox?;
    if (buttonBox == null || overlayBox == null) return;

    final offset = buttonBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    await showMenu<void>(
      context: buttonContext,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(
          offset.dx,
          offset.dy + buttonBox.size.height,
          buttonBox.size.width,
          buttonBox.size.height,
        ),
        Offset.zero & overlayBox.size,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      items: [
        _headerStyleMenuItem(controller: controller, label: '正文', level: null),
        _headerStyleMenuItem(controller: controller, label: '一级标题', level: 1),
        _headerStyleMenuItem(controller: controller, label: '二级标题', level: 2),
        _headerStyleMenuItem(controller: controller, label: '三级标题', level: 3),
      ],
    );
  }

  Future<void> _showToolbarOverflowMenu(
    BuildContext buttonContext,
    List<_ToolbarAction> items,
  ) async {
    final buttonBox = buttonContext.findRenderObject() as RenderBox?;
    final overlayBox =
        Overlay.of(buttonContext).context.findRenderObject() as RenderBox?;
    if (buttonBox == null || overlayBox == null) return;

    final offset = buttonBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    await showMenu<void>(
      context: buttonContext,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(
          offset.dx,
          offset.dy + buttonBox.size.height,
          buttonBox.size.width,
          buttonBox.size.height,
        ),
        Offset.zero & overlayBox.size,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      items: items.map(_toolbarMenuItem).toList(),
    );
  }

  Widget _overflowToolbarButton({
    required Color iconColor,
    required List<_ToolbarAction> hidden,
  }) {
    return SizedBox(
      width: 32,
      height: 32,
      child: Builder(
        builder: (buttonContext) => Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: InkWell(
            onTap: () => _showToolbarOverflowMenu(buttonContext, hidden),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Center(
              child: Icon(Icons.more_horiz, size: 18, color: iconColor),
            ),
          ),
        ),
      ),
    );
  }

  Widget _toolbarButton({
    required _ToolbarAction item,
    required Color iconColor,
    required Color disabledColor,
    required Color selectedColor,
    required Color selectedBackground,
  }) {
    final color = item.isEnabled
        ? (item.isActive ? selectedColor : iconColor)
        : disabledColor;

    return Tooltip(
      message: item.label,
      child: Builder(
        builder: (buttonContext) => Material(
          color: item.isActive ? selectedBackground : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: InkWell(
            onTap: item.isEnabled
                ? item.isHeaderStyle
                    ? () =>
                        _showHeaderStyleMenu(buttonContext, _quillController)
                    : item.onTap
                : null,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: SizedBox(
              width: item.width,
              height: 32,
              child: Center(
                child: item.icon != null
                    ? Icon(item.icon, size: 18, color: color)
                    : Text(
                        item.shortLabel ?? '',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1,
                          color: color,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _responsiveToolbar({
    required BoxConstraints constraints,
    required bool isDark,
    required NoteEditorState editorState,
  }) {
    const gap = AppSpacing.xs;
    final availableWidth = constraints.maxWidth.isFinite
        ? constraints.maxWidth.clamp(0.0, double.infinity)
        : 0.0;
    final actions = _toolbarActions(editorState);
    if (availableWidth < 32.0) {
      return const SizedBox.shrink();
    }

    final selectedColor = Theme.of(context).colorScheme.primary;
    final selectedBackground =
        selectedColor.withValues(alpha: isDark ? 0.18 : 0.1);
    final iconColor =
        isDark ? AppColors.secondaryTextDark : AppColors.secondaryText;
    final disabledColor =
        isDark ? AppColors.disabledTextDark : AppColors.disabledText;
    var used = 32.0;
    final visible = <_ToolbarAction>[];
    final hidden = <_ToolbarAction>[];

    for (var i = 0; i < actions.length; i++) {
      final action = actions[i];
      final actionWidth = action.width + (visible.isEmpty ? 0 : gap);
      final candidateUsed = used + (visible.isEmpty ? gap : 0) + actionWidth;
      if (candidateUsed <= availableWidth) {
        visible.add(action);
        used = candidateUsed;
      } else {
        hidden.add(action);
      }
    }

    final children = <Widget>[
      for (final item in visible)
        _toolbarButton(
          item: item,
          iconColor: iconColor,
          disabledColor: disabledColor,
          selectedColor: selectedColor,
          selectedBackground: selectedBackground,
        ),
      if (hidden.isNotEmpty)
        _overflowToolbarButton(
          iconColor: iconColor,
          hidden: hidden,
        ),
    ];

    return ClipRect(
      child: SizedBox(
        width: availableWidth,
        height: 32,
        child: Wrap(
          spacing: gap,
          runSpacing: 0,
          children: children,
        ),
      ),
    );
  }

  Widget _buildToolbar({
    required bool isCompact,
    required bool isDark,
    required NoteEditorState editorState,
  }) {
    final borderColor = isDark ? AppColors.borderDark : AppColors.border;
    final shellColor =
        isDark ? AppColors.surfaceSecondaryDark : const Color(0xFFF8FAFC);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? AppSpacing.sm : AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: isCompact
            ? (isDark ? AppColors.surfaceDark : AppColors.surface)
            : Colors.transparent,
        border: Border(
          top: BorderSide(color: borderColor),
          bottom: isCompact ? BorderSide.none : BorderSide(color: borderColor),
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: shellColor,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: borderColor),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.xs,
          ),
          child: LayoutBuilder(builder: (context, constraints) {
            return _responsiveToolbar(
              constraints: constraints,
              isDark: isDark,
              editorState: editorState,
            );
          }),
        ),
      ),
    );
  }

  Widget _buildEditor({
    required bool isCompact,
    required NoteEditorState editorState,
  }) {
    final editorTextColor = Theme.of(context).colorScheme.onSurface;
    final listTextStyle = TextStyle(
      fontSize: _editorFontSize,
      height: _editorLineHeight,
      color: editorTextColor,
      decoration: TextDecoration.none,
    );
    return Expanded(
      child: QuillEditor.basic(
        controller: editorState.quillController,
        focusNode: _focusNode,
        scrollController: _editorScrollController,
        config: QuillEditorConfig(
          editorKey: _editorKey,
          placeholder: '从这里开始记录想法...',
          // ignore: experimental_member_use
          onKeyPressed: (event, node) =>
              _handleEditorKeyPressed(event, editorState.quillController),
          padding: EdgeInsets.fromLTRB(
            isCompact ? 56 : 40,
            AppSpacing.sm,
            isCompact ? AppSpacing.lg : 40,
            96,
          ),
          customStyles: DefaultStyles(
            paragraph: DefaultTextBlockStyle(
              listTextStyle,
              const HorizontalSpacing(0, 0),
              const VerticalSpacing(4, 8),
              VerticalSpacing.zero,
              null,
            ),
            lists: DefaultListBlockStyle(
              listTextStyle,
              const HorizontalSpacing(0, 0),
              const VerticalSpacing(4, 8),
              const VerticalSpacing(0, 6),
              null,
              null,
            ),
          ),
          // ignore: experimental_member_use
          customLeadingBlockBuilder: (node, config) {
            final attribute = config.attribute;
            const lineHeight = _editorFontSize * _editorLineHeight;
            final width = config.width ?? (_editorFontSize * 2);
            final padding = config.padding ?? (_editorFontSize / 2);

            if (attribute == Attribute.ol) {
              final index = config.getIndexNumberByIndent ??
                  config.index?.toString() ??
                  '1';
              return SizedBox(
                width: width,
                height: lineHeight,
                child: Padding(
                  padding: EdgeInsetsDirectional.only(end: padding),
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Text(
                      '$index.',
                      style: listTextStyle,
                    ),
                  ),
                ),
              );
            }

            if (attribute == Attribute.ul) {
              return SizedBox(
                width: width,
                height: lineHeight,
                child: Padding(
                  padding: EdgeInsetsDirectional.only(end: padding),
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Text(
                      '•',
                      style: listTextStyle.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            }

            if (attribute == Attribute.checked ||
                attribute == Attribute.unchecked) {
              final enabled = config.enabled ?? false;
              return SizedBox(
                width: width,
                height: lineHeight,
                child: Padding(
                  padding: EdgeInsetsDirectional.only(end: padding),
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: SizedBox(
                      width: _editorFontSize,
                      height: _editorFontSize,
                      child: Checkbox(
                        value: config.value,
                        onChanged: enabled
                            ? (value) => config.onCheckboxTap(value ?? false)
                            : null,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ),
              );
            }

            return null;
          },
          embedBuilders: [NoteImageEmbedBuilder()],
          autoFocus: widget.note != null,
          expands: true,
          enableInteractiveSelection: true,
        ),
      ),
    );
  }

  Widget _buildOutlineContent({
    required bool isDark,
    required NoteEditorState editorState,
  }) {
    final outlineItems = _outlineItems(editorState.quillController);
    final secondaryColor =
        isDark ? AppColors.secondaryTextDark : AppColors.secondaryText;
    final activeOffset = editorState.quillController.selection.baseOffset;

    int activeIndex = -1;
    for (var i = 0; i < outlineItems.length; i++) {
      if (outlineItems[i].offset <= activeOffset) activeIndex = i;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(Icons.toc, size: 18, color: secondaryColor),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '大纲',
                style: AppTypography.captionMediumLight(color: secondaryColor),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            itemCount: outlineItems.length,
            itemBuilder: (context, index) {
              final item = outlineItems[index];
              final isActive = index == activeIndex;
              final color = isActive
                  ? Theme.of(context).colorScheme.primary
                  : secondaryColor;
              return InkWell(
                onTap: () {
                  _jumpToOutlineItem(item, editorState.quillController);
                  setState(() => _showOutline = false);
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 2,
                  ),
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.sm + (item.level - 1) * AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.sm,
                    AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: isDark ? 0.18 : 0.08)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.smallMediumLight(color: color),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOutlinePane({
    required bool isDark,
    required NoteEditorState editorState,
  }) {
    final outlineItems = _outlineItems(editorState.quillController);
    if (outlineItems.isEmpty) return const SizedBox.shrink();

    final borderColor = isDark ? AppColors.borderDark : AppColors.border;
    final surface = isDark ? AppColors.surfaceDark : AppColors.surface;

    return Container(
      width: 240,
      margin: const EdgeInsets.fromLTRB(16, 20, 0, 24),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: _buildOutlineContent(
        isDark: isDark,
        editorState: editorState,
      ),
    );
  }

  Widget _buildCompactOutline({
    required bool isDark,
    required NoteEditorState editorState,
    required Widget child,
  }) {
    final outlineItems = _outlineItems(editorState.quillController);
    if (outlineItems.isEmpty) return child;

    final borderColor = isDark ? AppColors.borderDark : AppColors.border;
    final surface = isDark ? AppColors.surfaceDark : AppColors.surface;
    final secondaryColor =
        isDark ? AppColors.secondaryTextDark : AppColors.secondaryText;

    return Stack(
      children: [
        child,
        Positioned(
          left: AppSpacing.sm,
          top: AppSpacing.sm,
          bottom: 72,
          child: MouseRegion(
            onEnter: (_) => setState(() => _showOutline = true),
            onExit: (_) => setState(() => _showOutline = false),
            child: GestureDetector(
              onTapDown: (_) => setState(() => _showOutline = true),
              onLongPressStart: (_) => setState(() => _showOutline = true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: _showOutline ? 236 : 34,
                decoration: BoxDecoration(
                  color: _showOutline
                      ? surface
                      : surface.withValues(alpha: isDark ? 0.78 : 0.86),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: borderColor),
                  boxShadow: _showOutline
                      ? (isDark ? AppShadows.dark : AppShadows.medium)
                      : null,
                ),
                clipBehavior: Clip.antiAlias,
                child: _showOutline
                    ? _buildOutlineContent(
                        isDark: isDark,
                        editorState: editorState,
                      )
                    : Center(
                        child: Icon(Icons.toc, size: 18, color: secondaryColor),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(noteEditorProvider(_args));
    final folders = context
        .watch<LocalFolderService>()
        .folders
        .where((f) => f.syncStatus != 'deleted')
        .toList();
    final selectedFolder = editorState.selectedLocalFolderId != null
        ? folders
            .where((f) => f.localId == editorState.selectedLocalFolderId)
            .firstOrNull
        : null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _close();
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 760;
          final background =
              isDark ? AppColors.backgroundDark : const Color(0xFFF3F4F6);
          final surface = isDark ? AppColors.surfaceDark : AppColors.surface;
          final border = isDark ? AppColors.borderDark : AppColors.border;
          final document = Column(
            children: [
              _buildDocumentHeader(
                  isCompact: isCompact,
                  isDark: isDark,
                  editorState: editorState),
              if (!isCompact)
                _buildToolbar(
                    isCompact: false, isDark: isDark, editorState: editorState),
              _buildEditor(isCompact: isCompact, editorState: editorState),
            ],
          );

          return Scaffold(
            resizeToAvoidBottomInset: true,
            backgroundColor: background,
            body: SafeArea(
              child: Column(
                children: [
                  _buildTopBar(
                    isCompact: isCompact,
                    isDark: isDark,
                    selectedFolder: selectedFolder,
                    editorState: editorState,
                  ),
                  Expanded(
                    child: isCompact
                        ? _buildCompactOutline(
                            isDark: isDark,
                            editorState: editorState,
                            child: ColoredBox(color: surface, child: document),
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildOutlinePane(
                                isDark: isDark,
                                editorState: editorState,
                              ),
                              Expanded(
                                child: Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 20, 16, 24),
                                  child: Align(
                                    alignment: Alignment.topCenter,
                                    child: Container(
                                      width: double.infinity,
                                      constraints:
                                          const BoxConstraints(maxWidth: 1080),
                                      decoration: BoxDecoration(
                                        color: surface,
                                        borderRadius:
                                            BorderRadius.circular(AppRadius.lg),
                                        border: Border.all(color: border),
                                        boxShadow: isDark
                                            ? AppShadows.dark
                                            : AppShadows.medium,
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: document,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                  if (isCompact)
                    _buildToolbar(
                        isCompact: true,
                        isDark: isDark,
                        editorState: editorState),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
