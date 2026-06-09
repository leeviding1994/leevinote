import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:leevinote/models/folder.dart';

class LocalFolderService extends ChangeNotifier {
  List<Folder> _folders = [];
  bool _loaded = false;

  List<Folder> get folders => _folders;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await _load();
    _loaded = true;
  }

  String get _key => 'local_folders';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_key) ?? '[]';
      final list = jsonDecode(json) as List;
      _folders = list.map((e) => Folder.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      _folders = [];
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(_folders.map((f) => f.toJson()).toList());
      await prefs.setString(_key, json);
    } catch (_) {}
  }

  Future<void> addFolder(Folder folder) async {
    await ensureLoaded();
    _folders.add(folder);
    await _persist();
    notifyListeners();
  }

  Future<void> updateFolder(Folder folder) async {
    await ensureLoaded();
    final index = _folders.indexWhere((f) => f.localId == folder.localId);
    if (index != -1) {
      _folders[index] = folder;
      await _persist();
      notifyListeners();
    }
  }

  Future<void> deleteFolder(String localId, {bool force = false}) async {
    await ensureLoaded();
    final i = _folders.indexWhere((f) => f.localId == localId);
    if (i == -1) return;
    final folder = _folders[i];
    if (!force && folder.id != null && folder.syncStatus != 'local') {
      _folders[i] = folder.copyWith(syncStatus: 'deleted');
    } else {
      _folders.removeAt(i);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> replaceAll(List<Folder> folders) async {
    _folders = List.from(folders);
    await _persist();
    notifyListeners();
  }

  Future<void> addOrUpdateFromRemote(Folder remote) async {
    await ensureLoaded();
    final i = _folders.indexWhere((f) => f.id != null && f.id == remote.id);
    if (i != -1) {
      final existing = _folders[i];
      _folders[i] = remote.copyWith(
        localId: existing.localId,
        localParentId: existing.localParentId != null ? () => existing.localParentId : null,
      );
    } else {
      _folders.add(remote);
    }
    await _persist();
    notifyListeners();
  }
}