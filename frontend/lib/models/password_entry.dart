import 'package:uuid/uuid.dart';

const _passwordUuid = Uuid();

class PasswordEntry {
  final String localId;
  final String title;
  final String username;
  final String password;
  final String? website;
  final String? notes;
  final List<String> tags;
  final bool favorite;
  final DateTime createdAt;
  final DateTime updatedAt;

  PasswordEntry({
    String? localId,
    required this.title,
    required this.username,
    required this.password,
    this.website,
    this.notes,
    this.tags = const [],
    this.favorite = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : localId = localId ?? _passwordUuid.v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  PasswordEntry copyWith({
    String? title,
    String? username,
    String? password,
    String? Function()? website,
    String? Function()? notes,
    List<String>? tags,
    bool? favorite,
  }) {
    return PasswordEntry(
      localId: localId,
      title: title ?? this.title,
      username: username ?? this.username,
      password: password ?? this.password,
      website: website != null ? website() : this.website,
      notes: notes != null ? notes() : this.notes,
      tags: tags ?? this.tags,
      favorite: favorite ?? this.favorite,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  factory PasswordEntry.fromJson(Map<String, dynamic> json) {
    return PasswordEntry(
      localId: json['local_id'] as String,
      title: json['title'] as String? ?? '',
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      website: json['website'] as String?,
      notes: json['notes'] as String?,
      tags: (json['tags'] as List<dynamic>? ?? const [])
          .map((tag) => tag.toString())
          .toList(),
      favorite: json['favorite'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'local_id': localId,
      'title': title,
      'username': username,
      'password': password,
      'website': website,
      'notes': notes,
      'tags': tags,
      'favorite': favorite,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

enum PasswordStrength { weak, fair, good, strong }

PasswordStrength evaluatePasswordStrength(String password) {
  var score = 0;
  if (password.length >= 12) score++;
  if (password.length >= 16) score++;
  if (RegExp(r'[a-z]').hasMatch(password) &&
      RegExp(r'[A-Z]').hasMatch(password)) {
    score++;
  }
  if (RegExp(r'\d').hasMatch(password)) score++;
  if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) score++;

  if (score <= 1) return PasswordStrength.weak;
  if (score == 2) return PasswordStrength.fair;
  if (score <= 4) return PasswordStrength.good;
  return PasswordStrength.strong;
}
