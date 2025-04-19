class Song {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String imageUrl;
  final int duration;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.imageUrl,
    required this.duration,
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'],
      title: json['name'],
      artist: json['artists'][0]['name'],
      album: json['album']['name'],
      imageUrl: json['album']['images'][0]['url'],
      duration: json['duration_ms'] ~/ 1000,
    );
  }
}
