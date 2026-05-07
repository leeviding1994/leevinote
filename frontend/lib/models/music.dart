class Music {
  final int? id;
  final String title;
  final String? artist;
  final String? album;
  final String fileUrl;
  final int? duration;

  Music({
    this.id,
    required this.title,
    this.artist,
    this.album,
    required this.fileUrl,
    this.duration,
  });

  factory Music.fromJson(Map<String, dynamic> json) {
    return Music(
      id: json['id'],
      title: json['title'],
      artist: json['artist'],
      album: json['album'],
      fileUrl: json['file_url'],
      duration: json['duration'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'file_url': fileUrl,
      'duration': duration,
    };
  }
}
