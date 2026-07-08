import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:leevinote/models/transaction_category.dart';
import 'package:leevinote/services/database_helper.dart';

class LocalTransactionCategoryService extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();
  List<TransactionCategory> _categories = [];
  final Set<String> _deletedCategoryIds = {};
  bool _loaded = false;

  List<TransactionCategory> get categories => _categories;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await _load();
    _loaded = true;
  }

  String get _deletedKey => 'deleted_transaction_category_ids';

  Future<void> _load() async {
    try {
      final rows = await _db.getAllTransactionCategories();
      _categories = rows.map((r) => _rowToCategory(r)).toList();

      final prefs = await SharedPreferences.getInstance();
      final deleted = prefs.getStringList(_deletedKey);
      if (deleted != null) {
        _deletedCategoryIds.addAll(deleted);
      }
    } catch (_) {
      _categories = [];
    }
  }

  TransactionCategory _rowToCategory(Map<String, dynamic> row) {
    return TransactionCategory(
      id: row['id'] as int?,
      localId: row['local_id'] as String,
      type: row['type'] as String,
      name: row['name'] as String,
      icon: row['icon'] as String?,
      color: row['color'] as String?,
      syncStatus: row['sync_status'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
    );
  }

  Future<void> _persistDeletedIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_deletedKey, _deletedCategoryIds.toList());
    } catch (_) {}
  }

  Future<void> addCategory(TransactionCategory category) async {
    await ensureLoaded();
    await _db.insertTransactionCategory(_categoryToRow(category));
    _categories.add(category);
    _sortCategories();
    notifyListeners();
  }

  Future<void> updateCategory(TransactionCategory category) async {
    await ensureLoaded();
    await _db.updateTransactionCategory(category.localId, _categoryToRow(category));
    final index = _categories.indexWhere((c) => c.localId == category.localId);
    if (index != -1) {
      _categories[index] = category;
      _sortCategories();
      notifyListeners();
    }
  }

  Future<void> deleteCategory(String localId) async {
    await ensureLoaded();
    final index = _categories.indexWhere((c) => c.localId == localId);
    if (index != -1) {
      final category = _categories[index];
      if (category.id != null) {
        _deletedCategoryIds.add(category.id.toString());
      }
      _deletedCategoryIds.add(category.localId);
      await _persistDeletedIds();
    }
    await _db.deleteTransactionCategory(localId);
    _categories.removeWhere((c) => c.localId == localId);
    notifyListeners();
  }

  Future<void> forceDeleteCategory(String localId) async {
    await ensureLoaded();
    await _db.forceDeleteTransactionCategory(localId);
    _categories.removeWhere((c) => c.localId == localId);
    notifyListeners();
  }

  Future<TransactionCategory?> getCategory(String localId) async {
    await ensureLoaded();
    try {
      return _categories.firstWhere((c) => c.localId == localId);
    } catch (_) {
      return null;
    }
  }

  Future<TransactionCategory?> getCategoryByRemoteId(int id) async {
    await ensureLoaded();
    try {
      return _categories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> replaceAll(List<TransactionCategory> categories) async {
    for (final category in categories) {
      await _db.insertTransactionCategory(_categoryToRow(category));
    }
    _categories = List.from(categories);
    _sortCategories();
    notifyListeners();
  }

  Future<void> addOrUpdateFromRemote(TransactionCategory remote) async {
    await ensureLoaded();
    if (remote.id != null && _deletedCategoryIds.contains(remote.id.toString())) {
      return;
    }
    if (_deletedCategoryIds.contains(remote.localId)) {
      return;
    }

    final i = _categories.indexWhere((c) => c.id != null && c.id == remote.id);
    if (i != -1) {
      final existing = _categories[i];
      final updated = remote.copyWith(localId: existing.localId);
      await _db.updateTransactionCategory(updated.localId, _categoryToRow(updated));
      _categories[i] = updated;
    } else {
      await _db.insertTransactionCategory(_categoryToRow(remote));
      _categories.add(remote);
    }
    _sortCategories();
    notifyListeners();
  }

  Future<void> clearAll() async {
    await ensureLoaded();
    _categories = [];
    _deletedCategoryIds.clear();
    await _persistDeletedIds();
    notifyListeners();
  }

  void _sortCategories() {
    _categories.sort((a, b) {
      final typeCmp = a.type.compareTo(b.type);
      if (typeCmp != 0) return typeCmp;
      return a.createdAt.compareTo(b.createdAt);
    });
  }

  Map<String, dynamic> _categoryToRow(TransactionCategory category) {
    final data = {
      'local_id': category.localId,
      'type': category.type,
      'name': category.name,
      'icon': category.icon,
      'color': category.color,
      'sync_status': category.syncStatus,
      'created_at': category.createdAt.millisecondsSinceEpoch,
      'updated_at': category.updatedAt.millisecondsSinceEpoch,
      'is_deleted': 0,
    };
    if (category.id != null) {
      data['id'] = category.id;
    }
    return data;
  }
}
