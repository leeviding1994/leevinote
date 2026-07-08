import 'package:flutter/foundation.dart';
import 'package:leevinote/models/transaction.dart';
import 'package:leevinote/services/api_service.dart';
import 'package:leevinote/services/local_transaction_service.dart';
import 'package:leevinote/services/local_transaction_category_service.dart';
import 'package:leevinote/utils/constants.dart';

class TransactionService extends ChangeNotifier {
  final ApiService _api;
  final LocalTransactionService _local;
  final LocalTransactionCategoryService? _categoryLocal;

  TransactionService(this._api, this._local, {LocalTransactionCategoryService? categoryLocal})
      : _categoryLocal = categoryLocal;

  Future<List<Transaction>> fetchTransactions() async {
    try {
      final data = await _api.getList(ApiConstants.transactions);
      final remoteTransactions = data
          .map((e) => Transaction.fromJson(e as Map<String, dynamic>).copyWith(syncStatus: 'synced'))
          .toList();
      for (final rt in remoteTransactions) {
        await _local.addOrUpdateFromRemote(rt);
      }
      return _local.transactions;
    } catch (e) {
      debugPrint('Failed to fetch transactions: $e');
      await _local.ensureLoaded();
      return _local.transactions;
    }
  }

  Future<Map<String, dynamic>> fetchStatistics(
    DateTime startDate,
    DateTime endDate, {
    String groupBy = 'day',
  }) async {
    try {
      final query = 'startDate=${Uri.encodeComponent(_formatDate(startDate))}'
          '&endDate=${Uri.encodeComponent(_formatDate(endDate))}'
          '&groupBy=${Uri.encodeComponent(groupBy)}';
      final response = await _api.get('${ApiConstants.transactions}/statistics?$query');
      return response;
    } catch (e) {
      debugPrint('Failed to fetch transaction statistics: $e');
      return _computeLocalStatistics(startDate, endDate, groupBy);
    }
  }

  Map<String, dynamic> _computeLocalStatistics(
    DateTime startDate,
    DateTime endDate,
    String groupBy,
  ) {
    final transactions = _local.transactions.where((t) {
      final date = DateTime(
        t.transactionDate.year,
        t.transactionDate.month,
        t.transactionDate.day,
      );
      final start = DateTime(startDate.year, startDate.month, startDate.day);
      final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
      return !date.isBefore(start) && !date.isAfter(end);
    }).toList();

    double totalIncome = 0;
    double totalExpense = 0;
    final periodMap = <String, Map<String, double>>{};

    String periodKey(Transaction t) {
      final d = t.transactionDate;
      if (groupBy == 'year') {
        return '${d.year}';
      } else if (groupBy == 'month') {
        return '${d.year}-${d.month.toString().padLeft(2, '0')}';
      }
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }

    for (final t in transactions) {
      if (t.syncStatus == 'deleted') continue;
      final key = periodKey(t);
      final period = periodMap.putIfAbsent(key, () => {'income': 0, 'expense': 0});
      if (t.type == 'income') {
        totalIncome += t.amount;
        period['income'] = (period['income'] ?? 0) + t.amount;
      } else {
        totalExpense += t.amount;
        period['expense'] = (period['expense'] ?? 0) + t.amount;
      }
    }

    final periods = periodMap.entries.map((e) {
      final income = e.value['income'] ?? 0;
      final expense = e.value['expense'] ?? 0;
      return {
        'period': e.key,
        'income': income,
        'expense': expense,
        'balance': income - expense,
      };
    }).toList();
    periods.sort((a, b) => (b['period'] as String).compareTo(a['period'] as String));

    return {
      'totalIncome': totalIncome,
      'totalExpense': totalExpense,
      'balance': totalIncome - totalExpense,
      'periods': periods,
    };
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<Transaction?> createTransaction(Transaction transaction) async {
    final localTransaction = transaction.copyWith(syncStatus: 'local');
    await _local.addTransaction(localTransaction);
    notifyListeners();
    return localTransaction;
  }

  Future<void> updateTransaction(Transaction transaction) async {
    final updated = transaction.copyWith(
      syncStatus: transaction.id != null ? 'modified' : 'local',
    );
    await _local.updateTransaction(updated);
    if (updated.id != null) {
      try {
        await _api.put(
          '${ApiConstants.transactions}/${updated.id}',
          updated.toRemoteJson(),
        );
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> deleteTransaction(String localId) async {
    final transaction = _local.transactions.firstWhere(
      (t) => t.localId == localId,
      orElse: () => Transaction(type: 'expense', amount: 0, transactionDate: DateTime.now()),
    );
    if (transaction.id != null) {
      final updated = transaction.copyWith(syncStatus: 'deleted');
      await _local.updateTransaction(updated);
    } else {
      await _local.deleteTransaction(localId);
    }
    notifyListeners();
  }

  Future<bool> syncTransactions() async {
    try {
      await _local.ensureLoaded();

      for (final transaction in List.from(_local.transactions)) {
        if (transaction.syncStatus == 'deleted' && transaction.id != null) {
          try {
            await _api.delete('${ApiConstants.transactions}/${transaction.id}');
            await _local.forceDeleteTransaction(transaction.localId);
          } catch (_) {}
        } else if (transaction.syncStatus == 'local' || transaction.syncStatus == 'modified') {
          try {
            int? resolvedCategoryId = transaction.categoryId;
            if (transaction.localCategoryId != null && _categoryLocal != null) {
              final category = await _categoryLocal.getCategory(transaction.localCategoryId!);
              resolvedCategoryId = category?.id;
            }
            final result = await _api.post(
              ApiConstants.transactions,
              transaction.copyWith(categoryId: () => resolvedCategoryId).toRemoteJson(),
            );
            final remoteId = result['id'];
            final newId = remoteId is int
                ? remoteId
                : int.tryParse(remoteId?.toString() ?? '');
            await _local.updateTransaction(transaction.copyWith(
              id: newId,
              categoryId: () => resolvedCategoryId,
              syncStatus: 'synced',
            ));
          } catch (_) {}
        }
      }

      final remoteData = await _api.getList(ApiConstants.transactions);
      final remoteIds = remoteData.map((e) => (e as Map)['id'] as int?).whereType<int>().toSet();
      for (final transaction in List.from(_local.transactions)) {
        if (transaction.id != null && transaction.syncStatus == 'synced' && !remoteIds.contains(transaction.id)) {
          await _local.forceDeleteTransaction(transaction.localId);
        }
      }
      for (final e in remoteData) {
        final remote = Transaction.fromJson(e as Map<String, dynamic>).copyWith(syncStatus: 'synced');
        await _local.addOrUpdateFromRemote(remote);
      }

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Transaction sync failed: $e');
      notifyListeners();
      return false;
    }
  }
}
