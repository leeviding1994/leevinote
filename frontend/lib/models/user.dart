class User {
  final String? id;
  final String username;
  final String? email;
  final String? avatarBase64;
  final String? nickname;
  final DateTime? createdAt;

  User({
    this.id,
    required this.username,
    this.email,
    this.avatarBase64,
    this.nickname,
    this.createdAt,
  });

  User copyWith({
    String? id,
    String? username,
    String? email,
    String? avatarBase64,
    String? nickname,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      avatarBase64: avatarBase64 ?? this.avatarBase64,
      nickname: nickname ?? this.nickname,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString(),
      username: json['username'] ?? '',
      email: json['email'],
      avatarBase64: json['avatar_base64'],
      nickname: json['nickname'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'username': username,
      'email': email,
      'avatar_base64': avatarBase64,
      'nickname': nickname,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  String? get displayName {
    if (nickname != null && nickname!.isNotEmpty) return nickname;
    return username;
  }
}
