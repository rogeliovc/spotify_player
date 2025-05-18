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

  Future<List<Map<String, String>>> fetchSongsByGenre(List<String> genres, String token) async {
    final results = <Map<String, String>>[];
    final seenIds = <String>{}; // Para evitar canciones repetidas

    for (final genre in genres.take(3)) {
      int fetched = 0;
      int offset = 0;

      while (fetched < 2) {
        final url = Uri.parse(
          'https://api.spotify.com/v1/search?q=genre:$genre&type=track&limit=1&offset=$offset',
        );
        final response = await http.get(
          url,
          headers: {'Authorization': 'Bearer $token'},
        );

        if (response.statusCode != 200) {
          throw Exception('Error al buscar canciones para $genre: ${response.statusCode}');
        }

        final data = json.decode(response.body);
        final tracks = data['tracks']['items'];

        if (tracks.isEmpty) {
          break;
        }

        final track = tracks[0];
        final trackId = track['id'].toString();

        if (!seenIds.contains(trackId)) {
          final song = {
            'id': trackId,
            'name': track['name'].toString(),
            'artist': track['artists'].isNotEmpty ? track['artists'][0]['name'].toString() : 'Unknown',
            'image': (track['album']['images'] as List).isNotEmpty
                ? track['album']['images'][0]['url'].toString()
                : '',
          };

          results.add(song);
          seenIds.add(trackId);
          fetched++;
        }

        offset++; // Avanzamos al siguiente resultado
      }
    }

    return results;
  }
}
