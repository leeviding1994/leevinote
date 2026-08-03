import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:leevinote/models/note.dart';
import 'package:leevinote/services/database_helper.dart';

class LocalNoteService extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();
  List<Note> _notes = [];
  final Set<String> _deletedNoteIds = {};
  bool _loaded = false;

  List<Note> get notes => _notes;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await _load();
    _loaded = true;
  }

  String get _deletedKey => 'deleted_note_ids';

  Future<void> _load() async {
    try {
      final rows = await _db.getAllNotes(includeDeleted: true);
      _notes = rows.map((r) => _rowToNote(r)).toList();

      final prefs = await SharedPreferences.getInstance();
      final deleted = prefs.getStringList(_deletedKey);
      if (deleted != null) {
        _deletedNoteIds.addAll(deleted);
      }
    } catch (_) {
      _notes = [];
    }
  }

  Note _rowToNote(Map<String, dynamic> row) {
    return Note(
      id: row['id'] as int?,
      localId: row['local_id'] as String,
      title: row['title'] as String,
      content: row['content'] as String?,
      category: row['category'] as String?,
      folderId: row['folder_id'] as int?,
      localFolderId: row['local_folder_id'] as String?,
      syncStatus: row['sync_status'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
    );
  }

  Future<void> _persistDeletedIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_deletedKey, _deletedNoteIds.toList());
    } catch (_) {}
  }

  Future<void> addNote(Note note) async {
    await ensureLoaded();
    await _db.insertNote(note);
    _notes.insert(0, note);
    notifyListeners();
  }

  Future<void> updateNote(Note note) async {
    await ensureLoaded();
    await _db.updateNote(note);
    final index = _notes.indexWhere((n) => n.localId == note.localId);
    if (index != -1) {
      _notes[index] = note;
      notifyListeners();
    }
  }

  Future<void> deleteNote(String localId) async {
    await ensureLoaded();
    final index = _notes.indexWhere((n) => n.localId == localId);
    if (index == -1) return;

    final note = _notes[index];
    _deletedNoteIds.add(note.localId);
    if (note.id != null) {
      _deletedNoteIds.add(note.id.toString());
      final deleted = note.copyWith(syncStatus: 'deleted');
      await _db.updateNote(deleted);
      await _db.deleteNote(localId);
      _notes[index] = deleted;
    } else {
      await _db.forceDeleteNote(localId);
      _notes.removeAt(index);
    }
    await _persistDeletedIds();
    notifyListeners();
  }

  Future<void> forceDeleteNote(String localId) async {
    await ensureLoaded();
    await _db.forceDeleteNote(localId);
    _notes.removeWhere((n) => n.localId == localId);
    notifyListeners();
  }

  Future<Note?> getNote(String localId) async {
    await ensureLoaded();
    try {
      return _notes.firstWhere((n) => n.localId == localId);
    } catch (_) {
      return null;
    }
  }

  Future<void> replaceAll(List<Note> notes) async {
    await _db.clearNotes();
    for (final note in notes) {
      await _db.insertNote(note);
    }
    _notes = List.from(notes);
    notifyListeners();
  }

  Future<void> addOrUpdateFromRemote(Note remote) async {
    await ensureLoaded();
    if (remote.id != null && _deletedNoteIds.contains(remote.id.toString())) {
      return;
    }
    if (_deletedNoteIds.contains(remote.localId)) {
      return;
    }

    final i = _notes.indexWhere((n) => n.id != null && n.id == remote.id);
    if (i != -1) {
      final existing = _notes[i];
      if (existing.syncStatus == 'deleted') {
        return;
      }
      final updated = remote.copyWith(
        localId: existing.localId,
        // Prefer the resolved local folder id passed by the caller
        localFolderId: () => remote.localFolderId ?? existing.localFolderId,
        folderId: () => remote.folderId ?? existing.folderId,
        // Keep the synced status provided by the caller
      );
      await _db.updateNote(updated);
      _notes[i] = updated;
    } else {
      await _db.insertNote(remote);
      _notes.insert(0, remote);
    }
    notifyListeners();
  }

  Future<void> clearAll() async {
    await ensureLoaded();
    await _db.clearNotes();
    _notes = [];
    _deletedNoteIds.clear();
    await _persistDeletedIds();
    notifyListeners();
  }

  // Search notes directly from database
  Future<List<Note>> searchNotes(String query) async {
    await ensureLoaded();
    if (query.isEmpty) {
      return _notes;
    }
    final rows = await _db.searchNotes(query);
    return rows.map((r) => _rowToNote(r)).toList();
  }

  // Get notes by folder directly from database
  Future<List<Note>> getNotesByFolder(String? localFolderId) async {
    await ensureLoaded();
    final rows = await _db.getNotesByFolder(localFolderId);
    return rows.map((r) => _rowToNote(r)).toList();
  }
}
