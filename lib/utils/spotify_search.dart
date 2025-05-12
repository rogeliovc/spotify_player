import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../models/song_model.dart';

class SpotifySearchService {
  /// Busca canciones en Spotify por nombre usando el API oficial.
  static Future<List<Song>> searchTracks(String query, {int limit = 15}) async {
    final auth = AuthService();
    final token = await auth.getAccessToken();
    print('[SpotifySearch] token: ${token != null ? token.substring(0, 10) + '...' : 'NULL'}');
    if (token == null) throw Exception('No se encontró el token de sesión de Spotify.');

    final url = Uri.parse('https://api.spotify.com/v1/search?q=${Uri.encodeComponent(query)}&type=track&limit=$limit');
    print('[SpotifySearch] Buscando: $query');
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    print('[SpotifySearch] Status code: ${response.statusCode}');
    if (response.statusCode != 200) {
      print('[SpotifySearch] Error body: ${response.body}');
      throw Exception('Error al buscar canciones: ${response.body}');
    }
    final data = json.decode(response.body);
    final items = data['tracks']['items'] as List<dynamic>;
    print('[SpotifySearch] Resultados encontrados: ${items.length}');
    return items.map<Song>((item) => Song.fromSpotifyApi(item)).toList();
  }
}
