import 'package:flutter/foundation.dart';
import 'package:leevinote/models/transaction_category.dart';
import 'package:leevinote/services/api_service.dart';
import 'package:leevinote/services/local_transaction_category_service.dart';
import 'package:leevinote/utils/constants.dart';

class TransactionCategoryService extends ChangeNotifier {
  final ApiService _api;
  final LocalTransactionCategoryService _local;

  TransactionCategoryService(this._api, this._local);

  Future<List<TransactionCategory>> fetchCategories() async {
    try {
      final data = await _api.getList(ApiConstants.transactionCategories);
      final remoteCategories = data
          .map((e) => TransactionCategory.fromJson(e as Map<String, dynamic>).copyWith(syncStatus: 'synced'))
          .toList();
      for (final rc in remoteCategories) {
        await _local.addOrUpdateFromRemote(rc);
      }
      return _local.categories;
    } catch (e) {
      debugPrint('Failed to fetch transaction categories: $e');
      await _local.ensureLoaded();
      return _local.categories;
    }
  }

  Future<TransactionCategory?> createCategory(TransactionCategory category) async {
    final localCategory = category.copyWith(syncStatus: 'local');
    await _local.addCategory(localCategory);
    notifyListeners();
    return localCategory;
  }

  Future<void> updateCategory(TransactionCategory category) async {
    final updated = category.copyWith(
      syncStatus: category.id != null ? 'modified' : 'local',
    );
    await _local.updateCategory(updated);
    if (updated.id != null) {
      try {
        await _api.put(
          '${ApiConstants.transactionCategories}/${updated.id}',
          updated.toRemoteJson(),
        );
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> deleteCategory(String localId) async {
    final category = _local.categories.firstWhere(
      (c) => c.localId == localId,
      orElse: () => TransactionCategory(type: 'expense', name: ''),
    );
    if (category.id != null) {
      final updated = category.copyWith(syncStatus: 'deleted');
      await _local.updateCategory(updated);
    } else {
      await _local.deleteCategory(localId);
    }
    notifyListeners();
  }

  Future<bool> syncCategories() async {
    try {
      await _local.ensureLoaded();

      for (final category in List.from(_local.categories)) {
        if (category.syncStatus == 'deleted' && category.id != null) {
          try {
            await _api.delete('${ApiConstants.transactionCategories}/${category.id}');
            await _local.forceDeleteCategory(category.localId);
          } catch (e) {
            debugPrint('Delete transaction category failed: $e');
            return false;
          }
        } else if (category.syncStatus == 'local' || category.syncStatus == 'modified') {
          try {
            final Map<String, dynamic> result;
            if (category.id != null) {
              result = await _api.put(
                '${ApiConstants.transactionCategories}/${category.id}',
                category.toRemoteJson(),
              );
            } else {
              result = await _api.post(
                ApiConstants.transactionCategories,
                category.toRemoteJson(),
              );
            }
            final remoteId = result['id'];
            final newId = remoteId is int
                ? remoteId
                : int.tryParse(remoteId?.toString() ?? '');
            await _local.updateCategory(category.copyWith(
              id: newId ?? category.id,
              syncStatus: 'synced',
            ));
          } catch (e) {
            debugPrint('Upsert transaction category failed: $e');
            return false;
          }
        }
      }

      final remoteData = await _api.getList(ApiConstants.transactionCategories);
      debugPrint('Fetched transaction categories: ${remoteData.length}');
      final remoteIds = remoteData.map((e) => (e as Map)['id'] as int?).whereType<int>().toSet();
      for (final category in List.from(_local.categories)) {
        if (category.id != null && category.syncStatus == 'synced' && !remoteIds.contains(category.id)) {
          await _local.forceDeleteCategory(category.localId);
        }
      }
      for (final e in remoteData) {
        final remote = TransactionCategory.fromJson(e as Map<String, dynamic>).copyWith(syncStatus: 'synced');
        await _local.addOrUpdateFromRemote(remote, force: true);
      }

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Transaction category sync failed: $e');
      notifyListeners();
      return false;
    }
  }
}
