class Alarm {
  final int? id;
  final String title;
  final String? description;
  final DateTime alarmTime;
  final bool enabled;
  final String? repeatPattern;

  Alarm({
    this.id,
    required this.title,
    this.description,
    required this.alarmTime,
    this.enabled = true,
    this.repeatPattern,
  });

  factory Alarm.fromJson(Map<String, dynamic> json) {
    return Alarm(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      alarmTime: DateTime.parse(json['alarm_time']),
      enabled: json['enabled'] ?? true,
      repeatPattern: json['repeat_pattern'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'alarm_time': alarmTime.toIso8601String(),
      'enabled': enabled,
      'repeat_pattern': repeatPattern,
    };
  }
}
