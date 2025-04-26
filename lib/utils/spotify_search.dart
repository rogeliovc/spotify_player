import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../models/song_model.dart';

class SpotifySearchService {
  /// Busca canciones en Spotify por nombre usando el API oficial.
  static Future<List<Song>> searchTracks(String query, {int limit = 15}) async {
    final auth = AuthService();
    final token = await auth.getAccessToken();
    if (token == null) throw Exception('No se encontró el token de sesión de Spotify.');

    final url = Uri.parse('https://api.spotify.com/v1/search?q=${Uri.encodeComponent(query)}&type=track&limit=$limit');
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Error al buscar canciones: ${response.body}');
    }
    final data = json.decode(response.body);
    final items = data['tracks']['items'] as List<dynamic>;
    return items.map((item) {
      return Song(
        id: item['id'],
        title: item['name'],
        artist: (item['artists'] as List).isNotEmpty ? item['artists'][0]['name'] : '',
        album: item['album']?['name'] ?? '',
        albumArtUrl: (item['album']?['images'] as List).isNotEmpty ? item['album']['images'][0]['url'] : '',
        durationMs: item['duration_ms'] ?? 0,
      );
    }).toList();
  }
}
