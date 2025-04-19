import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/song_model.dart';

class PlayerProvider extends ChangeNotifier {
  final String accessToken;
  Song? currentSong;
  List<Song> playlist = [];
  bool isPlaying = false;

  PlayerProvider({required this.accessToken});

  Future<void> playSong(Song song) async {
    final url = Uri.parse('https://api.spotify.com/v1/me/player/play');
    final response = await http.put(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "uris": ["spotify:track:${song.id}"]
      }),
    );
    if (response.statusCode == 204) {
      currentSong = song;
      isPlaying = true;
      notifyListeners();
    } else {
      throw Exception('Error al reproducir la canción: ${response.body}');
    }
  }

  Future<void> pause() async {
    final url = Uri.parse('https://api.spotify.com/v1/me/player/pause');
    final response = await http.put(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );
    if (response.statusCode == 204) {
      isPlaying = false;
      notifyListeners();
    }
  }

  // Puedes agregar métodos similares para next, previous, setVolume, etc.

  void setCurrentSong(Song song) {
    currentSong = song;
    notifyListeners();
  }
}