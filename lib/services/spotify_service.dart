import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer' as developer;
import '../services/auth_service.dart';

class SpotifyService {
  final AuthService _authService;

  SpotifyService(this._authService);

  Future<void> playTrack(String trackId) async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null) {
        throw Exception('No se pudo obtener el token de acceso');
      }

      final response = await http.put(
        Uri.parse('https://api.spotify.com/v1/me/player/play'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'uris': ['spotify:track:$trackId']
        }),
      );

      if (response.statusCode != 204) {
        throw Exception(
            'Error al reproducir la canción: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('Error en SpotifyService.playTrack: $e');
      rethrow;
    }
  }

  Future<void> pause() async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null) {
        throw Exception('No se pudo obtener el token de acceso');
      }

      final response = await http.put(
        Uri.parse('https://api.spotify.com/v1/me/player/pause'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 204) {
        throw Exception('Error al pausar la canción: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('Error en SpotifyService.pause: $e');
      rethrow;
    }
  }

  Future<List<Map<String, String>>> fetchOnePerGenre(List<String> genres, String token) async {
    final results = <Map<String, String>>[];
    print('Token be: $token');

    for (final genre in genres.take(3)) { // Limitamos a 3 géneros más relevantes
      final url = Uri.parse(
        'https://api.spotify.com/v1/recommendations?limit=1&seed_genres=$genre',
      );
      print('URL Spotify: $url');

      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );
      print('Authorization header: Bearer $token');

      if (response.statusCode != 200) {
        throw Exception('Error al obtener recomendaciones para $genre: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      final track = data['tracks'][0];

      final song = {
        'id': '${track['id']}',
        'name': '${track['name']}',
        'artist': '${track['artists'][0]['name']}',
        'image': '${track['album']['images'][0]['url']}',
      };

      results.add(song);
    }

    return results;
  }

}
