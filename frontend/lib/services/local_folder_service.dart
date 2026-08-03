import 'package:flutter/foundation.dart';
import 'package:leevinote/models/folder.dart';
import 'package:leevinote/services/database_helper.dart';

class LocalFolderService extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();
  List<Folder> _folders = [];
  bool _loaded = false;

  List<Folder> get folders => _folders;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await _load();
    _loaded = true;
  }

  Future<void> _load() async {
    try {
      final rows = await _db.getAllFolders();
      _folders = rows.map((r) => _rowToFolder(r)).toList();
    } catch (_) {
      _folders = [];
    }
  }

  Folder _rowToFolder(Map<String, dynamic> row) {
    return Folder(
      id: row['id'] as int?,
      localId: row['local_id'] as String,
      name: row['name'] as String,
      parentId: row['parent_id'] as int?,
      localParentId: row['local_parent_id'] as String?,
      syncStatus: row['sync_status'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
    );
  }

  Future<void> addFolder(Folder folder) async {
    await ensureLoaded();
    await _db.insertFolder(folder);
    _folders.add(folder);
    notifyListeners();
  }

  Future<void> updateFolder(Folder folder) async {
    await ensureLoaded();
    await _db.updateFolder(folder);
    final index = _folders.indexWhere((f) => f.localId == folder.localId);
    if (index != -1) {
      _folders[index] = folder;
      notifyListeners();
    }
  }

  Future<void> deleteFolder(String localId, {bool force = false}) async {
    await ensureLoaded();
    final i = _folders.indexWhere((f) => f.localId == localId);
    if (i == -1) return;
    final folder = _folders[i];
    if (!force && folder.id != null && folder.syncStatus != 'local') {
      final updated = folder.copyWith(syncStatus: 'deleted');
      await _db.updateFolder(updated);
      _folders[i] = updated;
    } else {
      await _db.forceDeleteFolder(localId);
      _folders.removeAt(i);
    }
    notifyListeners();
  }

  Future<void> replaceAll(List<Folder> folders) async {
    await _db.clearFolders();
    for (final folder in folders) {
      await _db.insertFolder(folder);
    }
    _folders = List.from(folders);
    notifyListeners();
  }

  Future<void> addOrUpdateFromRemote(Folder remote) async {
    await ensureLoaded();

    // Resolve remote parent_id to a local folder id
    String? resolvedLocalParentId;
    if (remote.parentId != null) {
      for (final f in _folders) {
        if (f.id == remote.parentId) {
          resolvedLocalParentId = f.localId;
          break;
        }
      }
    }

    final i = _folders.indexWhere((f) => f.id != null && f.id == remote.id);
    if (i != -1) {
      final existing = _folders[i];
      final updated = remote.copyWith(
        localId: existing.localId,
        localParentId: () => resolvedLocalParentId ?? existing.localParentId,
        syncStatus: 'synced',
      );
      await _db.updateFolder(updated);
      _folders[i] = updated;
    } else {
      final inserted = remote.copyWith(
        localParentId: () => resolvedLocalParentId,
        syncStatus: 'synced',
      );
      await _db.insertFolder(inserted);
      _folders.add(inserted);
    }
    notifyListeners();
  }

  Future<void> clearAll() async {
    await ensureLoaded();
    await _db.clearFolders();
    _folders = [];
    notifyListeners();
  }
}
