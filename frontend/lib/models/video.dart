class Video {
  final int? id;
  final String title;
  final String? description;
  final String fileUrl;
  final int? duration;

  Video({
    this.id,
    required this.title,
    this.description,
    required this.fileUrl,
    this.duration,
  });

  factory Video.fromJson(Map<String, dynamic> json) {
    return Video(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      fileUrl: json['file_url'],
      duration: json['duration'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'file_url': fileUrl,
      'duration': duration,
    };
  }
}
