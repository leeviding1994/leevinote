import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:leevinote/models/note.dart';
import 'package:leevinote/services/api_service.dart';
import 'package:leevinote/services/local_note_service.dart';
import 'package:leevinote/services/local_folder_service.dart';

/// 创建编辑状态所需的参数
@immutable
class NoteEditorArgs {
  final Note? note;
  final String? defaultLocalFolderId;

  const NoteEditorArgs({this.note, this.defaultLocalFolderId});
}

/// 笔记编辑状态
class NoteEditorState {
  final String title;
  final int? selectedFolderId;
  final String? selectedLocalFolderId;
  final Note? currentNote;
  final bool isSaving;
  final bool hasUnsavedChanges;
  final DateTime? lastSavedAt;
  final QuillController quillController;
  final TextEditingController titleController;

  const NoteEditorState({
    required this.title,
    required this.quillController,
    required this.titleController,
    this.selectedFolderId,
    this.selectedLocalFolderId,
    this.currentNote,
    this.isSaving = false,
    this.hasUnsavedChanges = false,
    this.lastSavedAt,
  });

  NoteEditorState copyWith({
    String? title,
    int? selectedFolderId,
    String? selectedLocalFolderId,
    Note? currentNote,
    bool? isSaving,
    bool? hasUnsavedChanges,
    DateTime? lastSavedAt,
    QuillController? quillController,
    TextEditingController? titleController,
  }) {
    return NoteEditorState(
      title: title ?? this.title,
      quillController: quillController ?? this.quillController,
      titleController: titleController ?? this.titleController,
      selectedFolderId: selectedFolderId ?? this.selectedFolderId,
      selectedLocalFolderId:
          selectedLocalFolderId ?? this.selectedLocalFolderId,
      currentNote: currentNote ?? this.currentNote,
      isSaving: isSaving ?? this.isSaving,
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
      lastSavedAt: lastSavedAt ?? this.lastSavedAt,
    );
  }
}

/// 编辑状态 Notifier
final noteEditorProvider = NotifierProvider.autoDispose
    .family<NoteEditorNotifier, NoteEditorState, NoteEditorArgs>(
  NoteEditorNotifier.new,
);

class NoteEditorNotifier extends Notifier<NoteEditorState> {
  final NoteEditorArgs _args;
  Timer? _saveTimer;
  StreamSubscription? _quillSubscription;

  NoteEditorNotifier(this._args);

  static QuillController _buildQuillController(Note? note) {
    if (note?.content != null && note!.content!.isNotEmpty) {
      final delta = Delta.fromJson(jsonDecode(note.content!) as List);
      return QuillController(
        document: Document.fromDelta(delta),
        selection: const TextSelection.collapsed(offset: 0),
      );
    }
    return QuillController.basic();
  }

  @override
  NoteEditorState build() {
    final titleController =
        TextEditingController(text: _args.note?.title ?? '');
    final quillController = _buildQuillController(_args.note);

    _quillSubscription =
        quillController.document.changes.listen((_) => _onChanged());
    titleController.addListener(() {
      final text = titleController.text;
      if (text != state.title) {
        state = state.copyWith(title: text);
        _onChanged();
      }
    });

    ref.onDispose(() {
      _saveTimer?.cancel();
      _quillSubscription?.cancel();
      quillController.dispose();
      titleController.dispose();
    });

    return NoteEditorState(
      title: _args.note?.title ?? '',
      selectedFolderId: _args.note?.folderId,
      selectedLocalFolderId:
          _args.note?.localFolderId ?? _args.defaultLocalFolderId,
      currentNote: _args.note,
      lastSavedAt: _args.note?.updatedAt,
      titleController: titleController,
      quillController: quillController,
    );
  }

  void _onChanged() {
    _saveTimer?.cancel();
    if (!state.hasUnsavedChanges) {
      state = state.copyWith(hasUnsavedChanges: true);
    }
    _saveTimer = Timer(const Duration(milliseconds: 500), _autoSave);
  }

  Future<void> _autoSave() async {
    final title = state.title.trim();
    if (title.isEmpty && state.quillController.document.isEmpty()) return;

    state = state.copyWith(isSaving: true);

    final localNoteService = ref.read(localNoteServiceProvider);
    final delta = state.quillController.document.toDelta().toJson();
    final content = jsonEncode(delta);
    final finalTitle = title.isEmpty ? '无标题' : title;

    final existing = state.currentNote;
    if (existing == null) {
      final note = Note(
        title: finalTitle,
        content: content,
        folderId: state.selectedFolderId,
        localFolderId: state.selectedLocalFolderId,
        syncStatus: 'local',
      );
      await localNoteService.addNote(note);
      state = state.copyWith(
        currentNote: note,
        isSaving: false,
        hasUnsavedChanges: false,
        lastSavedAt: note.updatedAt,
      );
    } else {
      final updated = existing.copyWith(
        title: finalTitle,
        content: content,
        folderId: () => state.selectedFolderId,
        localFolderId: () => state.selectedLocalFolderId,
        updatedAt: DateTime.now(),
        syncStatus:
            existing.syncStatus == 'synced' ? 'modified' : existing.syncStatus,
      );
      await localNoteService.updateNote(updated);
      state = state.copyWith(
        currentNote: updated,
        isSaving: false,
        hasUnsavedChanges: false,
        lastSavedAt: DateTime.now(),
      );
    }
  }

  void setTitle(String title) {
    if (title != state.title) {
      state = state.copyWith(title: title);
      _onChanged();
    }
  }

  void setFolder(int? folderId, String? localFolderId) {
    state = state.copyWith(
      selectedFolderId: folderId,
      selectedLocalFolderId: localFolderId,
    );
    _autoSave();
  }

  Future<void> saveNow() async {
    _saveTimer?.cancel();
    await _autoSave();
  }

  Future<void> insertImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    String imagePath;
    if (kIsWeb) {
      final api = ref.read(apiServiceProvider);
      if (file.bytes == null) return;
      final resp =
          await api.uploadBytes('/files/upload', file.bytes!, file.name);
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

    final index = state.quillController.selection.baseOffset;
    final length = state.quillController.selection.extentOffset - index;

    state.quillController.replaceText(
      index,
      length,
      BlockEmbed.image(imagePath),
      TextSelection.collapsed(offset: index + 1),
    );
  }
}

/// 现有服务桥接为 Riverpod provider（方便统一管理）
final localNoteServiceProvider = Provider<LocalNoteService>((ref) {
  throw UnimplementedError('请在 main 里用 ProviderScope.overrides 注入');
});

final apiServiceProvider = Provider<ApiService>((ref) {
  throw UnimplementedError('请在 main 里用 ProviderScope.overrides 注入');
});

final localFolderServiceProvider = Provider<LocalFolderService>((ref) {
  throw UnimplementedError('请在 main 里用 ProviderScope.overrides 注入');
});
