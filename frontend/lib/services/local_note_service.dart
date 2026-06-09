import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:leevinote/models/note.dart';

class LocalNoteService extends ChangeNotifier {
  List<Note> _notes = [];
  bool _loaded = false;

  List<Note> get notes => _notes;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await _load();
    _loaded = true;
  }

  String get _key => 'local_notes';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_key) ?? '[]';
      final list = jsonDecode(json) as List;
      _notes = list.map((e) => Note.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      _notes = [];
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(_notes.map((n) => n.toJson()).toList());
      await prefs.setString(_key, json);
    } catch (_) {}
  }

  Future<void> addNote(Note note) async {
    await ensureLoaded();
    _notes.insert(0, note);
    await _persist();
    notifyListeners();
  }

  Future<void> updateNote(Note note) async {
    await ensureLoaded();
    final index = _notes.indexWhere((n) => n.localId == note.localId);
    if (index != -1) {
      _notes[index] = note;
      await _persist();
      notifyListeners();
    }
  }

  Future<void> deleteNote(String localId) async {
    await ensureLoaded();
    _notes.removeWhere((n) => n.localId == localId);
    await _persist();
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
    _notes = List.from(notes);
    await _persist();
    notifyListeners();
  }

  Future<void> addOrUpdateFromRemote(Note remote) async {
    await ensureLoaded();
    final i = _notes.indexWhere((n) => n.id != null && n.id == remote.id);
    if (i != -1) {
      final existing = _notes[i];
      _notes[i] = remote.copyWith(
        localId: existing.localId,
        localFolderId: existing.localFolderId != null ? () => existing.localFolderId : null,
      );
    } else {
      _notes.insert(0, remote);
    }
    await _persist();
    notifyListeners();
  }
}
