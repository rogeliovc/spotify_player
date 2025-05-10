import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/auth_service.dart';

class SpotifyService {
  final AuthService _authService;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

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
        throw Exception('Error al reproducir la canción: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en SpotifyService.playTrack: $e');
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
      print('Error en SpotifyService.pause: $e');
      rethrow;
    }
  }
}
