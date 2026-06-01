import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class Folder {
  final int? id;
  final String localId;
  final String name;
  final int? parentId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String syncStatus;

  Folder({
    this.id,
    String? localId,
    required this.name,
    this.parentId,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.syncStatus = 'local',
  })  : localId = localId ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Folder copyWith({
    int? id,
    String? localId,
    String? name,
    int? Function()? parentId,
    DateTime? updatedAt,
    String? syncStatus,
  }) {
    return Folder(
      id: id ?? this.id,
      localId: localId ?? this.localId,
      name: name ?? this.name,
      parentId: parentId != null ? parentId() : this.parentId,
      updatedAt: updatedAt ?? DateTime.now(),
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  factory Folder.fromJson(Map<String, dynamic> json) {
    return Folder(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      localId: json['local_id'] ?? const Uuid().v4(),
      name: json['name'] ?? '',
      parentId: json['parent_id'] is int
          ? json['parent_id']
          : int.tryParse(json['parent_id']?.toString() ?? ''),
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
      'name': name,
      'parent_id': parentId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'sync_status': syncStatus,
    };
  }

  Map<String, dynamic> toRemoteJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'parent_id': parentId,
    };
  }
}