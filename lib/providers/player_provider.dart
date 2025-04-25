import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/spotify_device_utils.dart';
import '../models/song_model.dart';

import 'dart:async';

class PlayerProvider extends ChangeNotifier {
  final String accessToken;
  Song? currentSong;
  Timer? _positionTimer;
  List<Song> playlist = [];
  bool isPlaying = false;
  double _volume = 0.5;
  double get volume => _volume;

  PlayerProvider({required this.accessToken});

  Future<void> playSong(Song song, {void Function(String)? onError}) async {
    await pause();
    _stopPositionTimer();
    final deviceId = await getActiveDeviceId(accessToken);
    if (deviceId == null) {
      if (onError != null) {
        onError('No hay ningún dispositivo de reproducción activo. Abre la app de música en tu dispositivo y reproduce una canción manualmente antes de usar Sincronía.');
      }
      return;
    }
    // Transfiere el playback al dispositivo antes de reproducir
    await transferPlaybackToDevice(accessToken, deviceId);
    final url = Uri.parse('https://api.spotify.com/v1/me/player/play?device_id=$deviceId');
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
      // Espera un poco y sincroniza la posición real desde Spotify
      await Future.delayed(const Duration(milliseconds: 300));
      try {
        final urlGet = Uri.parse('https://api.spotify.com/v1/me/player/currently-playing');
        final responseGet = await http.get(
          urlGet,
          headers: {
            'Authorization': 'Bearer $accessToken',
          },
        );
        if (responseGet.statusCode == 200) {
          final data = jsonDecode(responseGet.body);
          final position = data['progress_ms'] ?? 0;
          if (currentSong != null) {
            currentSong!.positionMs = position;
          }
        }
      } catch (_) {}
      notifyListeners();
      _startPositionTimer();
    } else if (response.statusCode == 404 || response.statusCode == 403) {
      if (onError != null) {
        onError('No hay ningún dispositivo de reproducción activo.');
      }
    } else {
      throw Exception('Error al reproducir la canción: ${response.body}');
    }
  }

  Future<void> pause() async {
    _stopPositionTimer();
    // Obtener la posición real desde Spotify antes de pausar
    try {
      final urlGet = Uri.parse('https://api.spotify.com/v1/me/player/currently-playing');
      final responseGet = await http.get(
        urlGet,
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );
      if (responseGet.statusCode == 200) {
        final data = jsonDecode(responseGet.body);
        final position = data['progress_ms'] ?? 0;
        if (currentSong != null) {
          currentSong!.positionMs = position;
        }
      }
    } catch (_) {}

    final url = Uri.parse('https://api.spotify.com/v1/me/player/pause');
    final response = await http.put(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );
    // Siempre actualiza el estado y notifica
    isPlaying = false;
    notifyListeners();
    // Ignorar cualquier otro error para no bloquear la reproducción
  }

  /// Reproduce la siguiente canción en la cola de Spotify.
  Future<void> next({void Function(String)? onError}) async {
    final url = Uri.parse('https://api.spotify.com/v1/me/player/next');
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );
    if (response.statusCode == 204) {
      // El estado se actualizará al obtener la canción actual
      notifyListeners();
    } else if (response.statusCode == 404 || response.statusCode == 403) {
      if (onError != null) {
        onError('No hay ningún dispositivo de reproducción activo. Abre la app de música en tu dispositivo y reproduce una canción manualmente antes de usar Sincronía.');
      }
    } else {
      if (onError != null) {
        onError('No se pudo avanzar a la siguiente canción. Intenta de nuevo o selecciona otra pista.');
      }
      // No lanzar excepción para evitar bloquear la UI
    }
  }

  /// Retrocede a la canción anterior en la cola de Spotify.
  Future<void> previous({void Function(String)? onError}) async {
    final url = Uri.parse('https://api.spotify.com/v1/me/player/previous');
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );
    if (response.statusCode == 204) {
      notifyListeners();
    } else if (response.statusCode == 404 || response.statusCode == 403) {
      if (onError != null) {
        onError('No hay ningún dispositivo de reproducción activo. Abre la app de música en tu dispositivo y reproduce una canción manualmente antes de usar Sincronía.');
      }
    } else {
      throw Exception('Error al retroceder a la canción anterior: ${response.body}');
    }
  }

  /// Cambia el volumen de reproducción (0.0 a 1.0).
  Future<void> setVolume(double volume) async {
    _volume = volume;
    final percent = (volume * 100).toInt();
    final url = Uri.parse('https://api.spotify.com/v1/me/player/volume?volume_percent=$percent');
    final response = await http.put(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );
    if (response.statusCode == 204) {
      // Sincroniza la posición real después del seek
      try {
        final urlGet = Uri.parse('https://api.spotify.com/v1/me/player/currently-playing');
        final responseGet = await http.get(
          urlGet,
          headers: {
            'Authorization': 'Bearer $accessToken',
          },
        );
        if (responseGet.statusCode == 200) {
          final data = jsonDecode(responseGet.body);
          final position = data['progress_ms'] ?? 0;
          if (currentSong != null) {
            currentSong!.positionMs = position;
          }
        }
      } catch (_) {}
      notifyListeners();
      _startPositionTimer();
    } else {
      throw Exception('Error al cambiar el volumen: ${response.body}');
    }
  }

  /// Hace seek a una posición específica en la canción actual (en milisegundos).
  Future<void> seek(int positionMs, {void Function(String)? onError}) async {
    final url = Uri.parse('https://api.spotify.com/v1/me/player/seek?position_ms=$positionMs');
    final response = await http.put(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );
    if (response.statusCode == 204) {
      // Sincroniza la posición real después del seek
      try {
        final urlGet = Uri.parse('https://api.spotify.com/v1/me/player/currently-playing');
        final responseGet = await http.get(
          urlGet,
          headers: {
            'Authorization': 'Bearer $accessToken',
          },
        );
        if (responseGet.statusCode == 200) {
          final data = jsonDecode(responseGet.body);
          final position = data['progress_ms'] ?? 0;
          if (currentSong != null) {
            currentSong!.positionMs = position;
          }
        }
      } catch (_) {}
      notifyListeners();
      _startPositionTimer();
    } else {
      // Notifica error pero no lances excepción
      if (onError != null) {
        onError('Error al hacer seek: ${response.body}');
      }
      // No hagas nada más, ignora el error para no romper la app
    }
  }


  void setCurrentSong(Song song) {
    _stopPositionTimer();
    currentSong = song;
    notifyListeners();
  }

  /// Reanuda la reproducción desde la posición actual de la canción
  Future<void> resume({void Function(String)? onError}) async {
    if (currentSong == null) return;
    final deviceId = await getActiveDeviceId(accessToken);
    if (deviceId == null) {
      if (onError != null) {
        onError('No hay ningún dispositivo de reproducción activo.');
      }
      return;
    }
    // Reanudar playback sin cambiar la canción
    final url = Uri.parse('https://api.spotify.com/v1/me/player/play?device_id=$deviceId');
    final response = await http.put(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({}),
    );
    if (response.statusCode == 204) {
      // Espera un poco antes de hacer seek
      await Future.delayed(const Duration(milliseconds: 300));
      // Hacer seek a la posición guardada SOLO si es válida
      if (currentSong!.positionMs > 0 && currentSong!.positionMs < currentSong!.durationMs) {
        try {
          await seek(currentSong!.positionMs);
        } catch (_) {
          // Si el seek falla, solo ignóralo y sigue
        }
      }
      // Sincroniza la posición real después del seek
      try {
        final urlGet = Uri.parse('https://api.spotify.com/v1/me/player/currently-playing');
        final responseGet = await http.get(
          urlGet,
          headers: {
            'Authorization': 'Bearer $accessToken',
          },
        );
        if (responseGet.statusCode == 200) {
          final data = jsonDecode(responseGet.body);
          final position = data['progress_ms'] ?? 0;
          if (currentSong != null) {
            currentSong!.positionMs = position;
          }
        }
      } catch (_) {}
      isPlaying = true;
      notifyListeners();
      _startPositionTimer();
    } else {
      if (onError != null) {
        onError('No se pudo reanudar la reproducción.');
      }
    }
  }

  void _startPositionTimer() {
    _positionTimer?.cancel();
    if (currentSong == null) return;
    _positionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!isPlaying || currentSong == null) return;
      if (currentSong!.positionMs + 1000 >= currentSong!.durationMs) {
        currentSong!.positionMs = currentSong!.durationMs;
        _stopPositionTimer();
        notifyListeners();
        return;
      }
      currentSong!.positionMs += 1000;
      notifyListeners();
    });
  }

  void _stopPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = null;
  }
}