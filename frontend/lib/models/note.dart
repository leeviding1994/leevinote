import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class Note {
  final int? id;
  final String localId;
  final String title;
  final String? content;
  final String? category;
  final int? folderId;
  final String? localFolderId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String syncStatus; // local, synced, modified, deleted

  Note({
    this.id,
    String? localId,
    required this.title,
    this.content,
    this.category,
    this.folderId,
    this.localFolderId,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.syncStatus = 'local',
  })  : localId = localId ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Note copyWith({
    int? id,
    String? localId,
    String? title,
    String? content,
    String? category,
    int? Function()? folderId,
    String? Function()? localFolderId,
    DateTime? updatedAt,
    String? syncStatus,
  }) {
    return Note(
      id: id ?? this.id,
      localId: localId ?? this.localId,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      folderId: folderId != null ? folderId() : this.folderId,
      localFolderId: localFolderId != null ? localFolderId() : this.localFolderId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      localId: json['local_id'] ?? const Uuid().v4(),
      title: json['title'] ?? '',
      content: json['content'],
      category: json['category'],
      folderId: json['folder_id'] is int
          ? json['folder_id']
          : int.tryParse(json['folder_id']?.toString() ?? ''),
      localFolderId: json['local_folder_id'],
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
      'title': title,
      'content': content,
      'category': category,
      'folder_id': folderId,
      'local_folder_id': localFolderId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'sync_status': syncStatus,
    };
  }

  Map<String, dynamic> toRemoteJson() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'content': content,
      'category': category,
      'folder_id': folderId,
    };
  }
}
