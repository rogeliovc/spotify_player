class Song {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String albumArtUrl;
  final int durationMs;
  int positionMs;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.albumArtUrl,
    required this.durationMs,
    this.positionMs = 0,
  });

  String get imageUrl => albumArtUrl;
  int get duration => durationMs ~/ 1000;

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'],
      title: json['name'],
      artist: json['artists'][0]['name'],
      album: json['album']['name'],
      albumArtUrl: json['album']['images'][0]['url'],
      durationMs: json['duration_ms'],
      positionMs: 0,
    );
  }
}
