import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class Transaction {
  final int? id;
  final String localId;
  final String type; // expense / income
  final double amount;
  final DateTime transactionDate;
  final int? categoryId;
  final String? localCategoryId;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String syncStatus;

  Transaction({
    this.id,
    String? localId,
    required this.type,
    required this.amount,
    required this.transactionDate,
    this.categoryId,
    this.localCategoryId,
    this.note,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.syncStatus = 'local',
  })  : localId = localId ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Transaction copyWith({
    int? id,
    String? localId,
    String? type,
    double? amount,
    DateTime? transactionDate,
    int? Function()? categoryId,
    String? Function()? localCategoryId,
    String? Function()? note,
    DateTime? updatedAt,
    String? syncStatus,
  }) {
    return Transaction(
      id: id ?? this.id,
      localId: localId ?? this.localId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      transactionDate: transactionDate ?? this.transactionDate,
      categoryId: categoryId != null ? categoryId() : this.categoryId,
      localCategoryId: localCategoryId != null ? localCategoryId() : this.localCategoryId,
      note: note != null ? note() : this.note,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    double parseAmount(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is String) {
        final date = DateTime.tryParse(value);
        return date ?? DateTime.now();
      }
      return DateTime.now();
    }

    return Transaction(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      localId: json['local_id'] ?? const Uuid().v4(),
      type: json['type'] ?? 'expense',
      amount: parseAmount(json['amount']),
      transactionDate: parseDate(json['transaction_date'] ?? json['transactionDate']),
      categoryId: json['category_id'] is int
          ? json['category_id']
          : int.tryParse(json['category_id']?.toString() ?? ''),
      localCategoryId: json['local_category_id'],
      note: json['note'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
      syncStatus: json['sync_status'] ?? 'local',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'local_id': localId,
      'type': type,
      'amount': amount,
      'transaction_date': transactionDate.toIso8601String(),
      'category_id': categoryId,
      'local_category_id': localCategoryId,
      'note': note,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'sync_status': syncStatus,
    };
  }

  Map<String, dynamic> toRemoteJson() {
    return {
      if (id != null) 'id': id,
      'type': type,
      'amount': amount,
      'transaction_date': transactionDate.toIso8601String(),
      'category_id': categoryId,
      'note': note,
    };
  }
}
