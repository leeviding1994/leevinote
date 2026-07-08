import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:leevinote/models/transaction.dart';
import 'package:leevinote/services/database_helper.dart';

class LocalTransactionService extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();
  List<Transaction> _transactions = [];
  final Set<String> _deletedTransactionIds = {};
  bool _loaded = false;

  List<Transaction> get transactions => _transactions;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await _load();
    _loaded = true;
  }

  String get _deletedKey => 'deleted_transaction_ids';

  Future<void> _load() async {
    try {
      final rows = await _db.getAllTransactions();
      _transactions = rows.map((r) => _rowToTransaction(r)).toList();

      final prefs = await SharedPreferences.getInstance();
      final deleted = prefs.getStringList(_deletedKey);
      if (deleted != null) {
        _deletedTransactionIds.addAll(deleted);
      }
    } catch (_) {
      _transactions = [];
    }
  }

  Transaction _rowToTransaction(Map<String, dynamic> row) {
    return Transaction(
      id: row['id'] as int?,
      localId: row['local_id'] as String,
      type: row['type'] as String,
      amount: (row['amount'] as num).toDouble(),
      transactionDate: DateTime.fromMillisecondsSinceEpoch(row['transaction_date'] as int),
      categoryId: row['category_id'] as int?,
      localCategoryId: row['local_category_id'] as String?,
      note: row['note'] as String?,
      syncStatus: row['sync_status'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
    );
  }

  Future<void> _persistDeletedIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_deletedKey, _deletedTransactionIds.toList());
    } catch (_) {}
  }

  Future<void> addTransaction(Transaction transaction) async {
    await ensureLoaded();
    await _db.insertTransaction(_transactionToRow(transaction));
    _transactions.insert(0, transaction);
    notifyListeners();
  }

  Future<void> updateTransaction(Transaction transaction) async {
    await ensureLoaded();
    await _db.updateTransaction(transaction.localId, _transactionToRow(transaction));
    final index = _transactions.indexWhere((t) => t.localId == transaction.localId);
    if (index != -1) {
      _transactions[index] = transaction;
      notifyListeners();
    }
  }

  Future<void> deleteTransaction(String localId) async {
    await ensureLoaded();
    final index = _transactions.indexWhere((t) => t.localId == localId);
    if (index != -1) {
      final transaction = _transactions[index];
      if (transaction.id != null) {
        _deletedTransactionIds.add(transaction.id.toString());
      }
      _deletedTransactionIds.add(transaction.localId);
      await _persistDeletedIds();
    }
    await _db.deleteTransaction(localId);
    _transactions.removeWhere((t) => t.localId == localId);
    notifyListeners();
  }

  Future<void> forceDeleteTransaction(String localId) async {
    await ensureLoaded();
    await _db.forceDeleteTransaction(localId);
    _transactions.removeWhere((t) => t.localId == localId);
    notifyListeners();
  }

  Future<Transaction?> getTransaction(String localId) async {
    await ensureLoaded();
    try {
      return _transactions.firstWhere((t) => t.localId == localId);
    } catch (_) {
      return null;
    }
  }

  Future<List<Transaction>> getTransactionsByDateRange(DateTime start, DateTime end) async {
    await ensureLoaded();
    final startMs = DateTime(start.year, start.month, start.day).millisecondsSinceEpoch;
    final endMs = DateTime(end.year, end.month, end.day, 23, 59, 59, 999).millisecondsSinceEpoch;
    final rows = await _db.getTransactionsByDateRange(startMs, endMs);
    return rows.map((r) => _rowToTransaction(r)).toList();
  }

  Future<void> replaceAll(List<Transaction> transactions) async {
    for (final transaction in transactions) {
      await _db.insertTransaction(_transactionToRow(transaction));
    }
    _transactions = List.from(transactions);
    notifyListeners();
  }

  Future<void> addOrUpdateFromRemote(Transaction remote) async {
    await ensureLoaded();
    if (remote.id != null && _deletedTransactionIds.contains(remote.id.toString())) {
      return;
    }
    if (_deletedTransactionIds.contains(remote.localId)) {
      return;
    }

    final i = _transactions.indexWhere((t) => t.id != null && t.id == remote.id);
    if (i != -1) {
      final existing = _transactions[i];
      final updated = remote.copyWith(
        localId: existing.localId,
        localCategoryId: () => remote.localCategoryId ?? existing.localCategoryId,
        categoryId: () => remote.categoryId ?? existing.categoryId,
      );
      await _db.updateTransaction(updated.localId, _transactionToRow(updated));
      _transactions[i] = updated;
    } else {
      await _db.insertTransaction(_transactionToRow(remote));
      _transactions.insert(0, remote);
    }
    notifyListeners();
  }

  Future<void> clearAll() async {
    await ensureLoaded();
    _transactions = [];
    _deletedTransactionIds.clear();
    await _persistDeletedIds();
    notifyListeners();
  }

  Map<String, dynamic> _transactionToRow(Transaction transaction) {
    final data = {
      'local_id': transaction.localId,
      'type': transaction.type,
      'amount': transaction.amount,
      'transaction_date': DateTime(
        transaction.transactionDate.year,
        transaction.transactionDate.month,
        transaction.transactionDate.day,
      ).millisecondsSinceEpoch,
      'category_id': transaction.categoryId,
      'local_category_id': transaction.localCategoryId,
      'note': transaction.note,
      'sync_status': transaction.syncStatus,
      'created_at': transaction.createdAt.millisecondsSinceEpoch,
      'updated_at': transaction.updatedAt.millisecondsSinceEpoch,
      'is_deleted': 0,
    };
    if (transaction.id != null) {
      data['id'] = transaction.id;
    }
    return data;
  }
}
