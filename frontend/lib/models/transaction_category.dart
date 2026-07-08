import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class TransactionCategory {
  final int? id;
  final String localId;
  final String type; // expense / income
  final String name;
  final String? icon;
  final String? color;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String syncStatus;

  TransactionCategory({
    this.id,
    String? localId,
    required this.type,
    required this.name,
    this.icon,
    this.color,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.syncStatus = 'local',
  })  : localId = localId ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  TransactionCategory copyWith({
    int? id,
    String? localId,
    String? type,
    String? name,
    String? Function()? icon,
    String? Function()? color,
    DateTime? updatedAt,
    String? syncStatus,
  }) {
    return TransactionCategory(
      id: id ?? this.id,
      localId: localId ?? this.localId,
      type: type ?? this.type,
      name: name ?? this.name,
      icon: icon != null ? icon() : this.icon,
      color: color != null ? color() : this.color,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  factory TransactionCategory.fromJson(Map<String, dynamic> json) {
    return TransactionCategory(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      localId: json['local_id'] ?? const Uuid().v4(),
      type: json['type'] ?? 'expense',
      name: json['name'] ?? '',
      icon: json['icon'],
      color: json['color'],
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
      'name': name,
      'icon': icon,
      'color': color,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'sync_status': syncStatus,
    };
  }

  Map<String, dynamic> toRemoteJson() {
    return {
      if (id != null) 'id': id,
      'type': type,
      'name': name,
      'icon': icon,
      'color': color,
    };
  }
}
