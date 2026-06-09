import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class Alarm {
  final int? id;
  final String localId;
  final String title;
  final String? description;
  final DateTime alarmTime;
  final bool enabled;
  final String? repeatPattern;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String syncStatus;

  Alarm({
    this.id,
    String? localId,
    required this.title,
    this.description,
    required this.alarmTime,
    this.enabled = true,
    this.repeatPattern,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.syncStatus = 'local',
  })  : localId = localId ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Alarm copyWith({
    int? id,
    String? localId,
    String? title,
    String? description,
    DateTime? alarmTime,
    bool? enabled,
    String? repeatPattern,
    DateTime? updatedAt,
    String? syncStatus,
  }) {
    return Alarm(
      id: id ?? this.id,
      localId: localId ?? this.localId,
      title: title ?? this.title,
      description: description ?? this.description,
      alarmTime: alarmTime ?? this.alarmTime,
      enabled: enabled ?? this.enabled,
      repeatPattern: repeatPattern ?? this.repeatPattern,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  factory Alarm.fromJson(Map<String, dynamic> json) {
    return Alarm(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      localId: json['local_id'] ?? _uuid.v4(),
      title: json['title'] ?? '',
      description: json['description'],
      alarmTime: DateTime.parse(json['alarm_time']),
      enabled: json['enabled'] ?? true,
      repeatPattern: json['repeat_pattern'],
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
      'alarm_time': alarmTime.toIso8601String(),
      'enabled': enabled,
      'repeat_pattern': repeatPattern,
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
      'alarm_time': alarmTime.toIso8601String(),
      'enabled': enabled,
      'repeat_pattern': repeatPattern,
    };
  }
}
