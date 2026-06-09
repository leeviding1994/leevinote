import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class Music {
  final int? id;
  final String localId;
  final String title;
  final String? artist;
  final String? album;
  final String fileUrl;
  final int? duration;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String syncStatus;

  Music({
    this.id,
    String? localId,
    required this.title,
    this.artist,
    this.album,
    required this.fileUrl,
    this.duration,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.syncStatus = 'local',
  })  : localId = localId ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Music copyWith({
    int? id,
    String? localId,
    String? title,
    String? artist,
    String? album,
    String? fileUrl,
    int? duration,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? syncStatus,
  }) {
    return Music(
      id: id ?? this.id,
      localId: localId ?? this.localId,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      fileUrl: fileUrl ?? this.fileUrl,
      duration: duration ?? this.duration,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  factory Music.fromJson(Map<String, dynamic> json) {
    return Music(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      localId: json['local_id'] ?? _uuid.v4(),
      title: json['title'] ?? '',
      artist: json['artist'],
      album: json['album'],
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
      'artist': artist,
      'album': album,
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
      'artist': artist,
      'album': album,
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
