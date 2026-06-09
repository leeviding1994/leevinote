import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class Video {
  final int? id;
  final String localId;
  final String title;
  final String? description;
  final String fileUrl;
  final int? duration;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String syncStatus;

  Video({
    this.id,
    String? localId,
    required this.title,
    this.description,
    required this.fileUrl,
    this.duration,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.syncStatus = 'local',
  })  : localId = localId ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Video copyWith({
    int? id,
    String? localId,
    String? title,
    String? description,
    String? fileUrl,
    int? duration,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? syncStatus,
  }) {
    return Video(
      id: id ?? this.id,
      localId: localId ?? this.localId,
      title: title ?? this.title,
      description: description ?? this.description,
      fileUrl: fileUrl ?? this.fileUrl,
      duration: duration ?? this.duration,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  factory Video.fromJson(Map<String, dynamic> json) {
    return Video(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      localId: json['local_id'] ?? _uuid.v4(),
      title: json['title'] ?? '',
      description: json['description'],
      fileUrl: json['file_url'] ?? '',
      duration: json['duration'] is int ? json['duration'] : int.tryParse(json['duration']?.toString() ?? ''),
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
      'description': description,
      'file_url': fileUrl,
      'duration': duration,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'sync_status': syncStatus,
    };
  }

  Map<String, dynamic> toRemoteJson() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'description': description,
      'file_url': fileUrl,
      'duration': duration,
    };
  }

  String get durationFormatted {
    if (duration == null) return '--:--';
    final secs = duration! ~/ 1000;
    final minutes = secs ~/ 60;
    final seconds = secs % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
