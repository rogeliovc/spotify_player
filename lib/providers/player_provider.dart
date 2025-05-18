import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/spotify_device_utils.dart';
import '../models/song_model.dart';
import '../services/auth_service.dart';
import '../screens/home_screen_login.dart';
import 'dart:async';

class PlayerProvider extends ChangeNotifier {
  // Reproduce una canción por ID si está en el playlist actual
  static Future<void> playSongByIdStatic(PlayerProvider provider, String id) async {
    final idx = provider.playlist.indexWhere((s) => s.id == id);
    if (idx != -1) {
      await provider.playSongFromList(provider.playlist, idx);
    }
  }
  bool isProcessing = false;
  String _accessToken = '';
  final AuthService _authService;

  PlayerProvider(this._authService);

  BuildContext? _context;

  void setContext(BuildContext context) {
    _context = context;
  }

  void _handleInvalidToken() async {
    try {
      final token = await _authService.getAccessToken();
      if (token != null) {
        _accessToken = token;
        return;
      }

      await _authService.signOut();
      if (_context != null) {
        ScaffoldMessenger.of(_context!).showSnackBar(
          const SnackBar(
            content: Text(
                'Tu sesión ha expirado. Por favor, inicia sesión nuevamente.'),
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.of(_context!).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreenLogin()),
          (route) => false,
        );
      }
    } catch (e) {
      developer.log('[PlayerProvider] Error en _handleInvalidToken: $e');
    }
  }

  Future<bool> _verifyToken() async {
    try {
      if (_accessToken.isEmpty) {
        _accessToken = (await _authService.getAccessToken()) ?? '';
        if (_accessToken.isEmpty) {
          developer.log('[PlayerProvider] No se pudo obtener token inicial');
          return false;
        }
      }

      final isValid = await _authService.isTokenValid();
      if (!isValid) {
        final refreshed = await _authService.refreshAccessToken();
        if (refreshed) {
          _accessToken = (await _authService.getAccessToken()) ?? '';
          return true;
        } else {
          developer.log('[PlayerProvider] Falló el refresh del token');
          return false;
        }
      }
      return true;
    } catch (e) {
      developer.log('[PlayerProvider] Error en _verifyToken: $e');
      return false;
    }
  }

  Song? currentSong;
  Timer? _positionTimer;
  bool _freezeTimerWhileSeeking = false;
  Timer? _syncTimer;

  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _syncWithSpotify();
    });
  }

  Future<void> _syncWithSpotify() async {
    if (_accessToken.isEmpty) {
      developer
          .log('[PlayerProvider] accessToken vacío. Redirigiendo a login.');
      _handleInvalidToken();
      return;
    }
    if (currentSong == null) return;
    try {
      final urlGet =
          Uri.parse('https://api.spotify.com/v1/me/player/currently-playing');
      final responseGet = await http.get(
        urlGet,
        headers: {
          'Authorization': 'Bearer $_accessToken',
        },
      );
      if (responseGet.statusCode == 200) {
        final data = jsonDecode(responseGet.body);
        final position = data['progress_ms'] ?? 0;
        final isPlayingSpotify = data['is_playing'] ?? false;
        final songId = data['item']?['id'];
        final duration = data['item']?['duration_ms'] ?? 0;
        if (songId != null && currentSong!.id != songId) {
          final idx = playlist.indexWhere((s) => s.id == songId);
          if (idx != -1) {
            await playSongFromList(playlist, idx);
            return;
          }
        }
        if (position >= duration - 500 && !isPlayingSpotify) {
          if (repeatSong) {
            await seek(0);
            await resume();
          } else {
            await next();
          }
          return;
        }
        if ((currentSong!.positionMs - position).abs() > 1500) {
          currentSong!.positionMs = position;
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  List<Song> playlist = [];
  int currentIndex = 0;
  bool isPlaying = false;
  bool repeatSong = false;
  double _volume = 0.5;
  double get volume => _volume;

  Future<void> playSongFromList(List<Song> songs, int index,
      {void Function(String)? onError}) async {
    if (!await _verifyToken()) return;

    developer.log(
        '[playSongFromList] Llamado con index=$index, songs.length=${songs.length}');
    if (songs.isEmpty || index < 0 || index >= songs.length) {
      if (onError != null) onError('Índice o lista inválida.');
      return;
    }
    playlist = List<Song>.from(songs);
    currentIndex = index;
    developer.log(
        '[playSongFromList] playlist actualizada. currentIndex=$currentIndex, canción=${playlist[currentIndex].title}');
    final song = songs[index];
    await pause();
    _stopPositionTimer();
    final deviceId = await getActiveDeviceId(_accessToken);
    if (deviceId == null) {
      if (onError != null) {
        onError(
            'No hay ningún dispositivo de reproducción activo. Abre la app de música en tu dispositivo y reproduce una canción manualmente antes de usar Sincronía.');
      }
      return;
    }
    await transferPlaybackToDevice(_accessToken, deviceId);
    final url = Uri.parse(
        'https://api.spotify.com/v1/me/player/play?device_id=$deviceId');
    final uris = songs.map((s) => 'spotify:track:${s.id}').toList();
    final response = await http.put(
      url,
      headers: {
        'Authorization': 'Bearer $_accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "uris": uris,
        "offset": {"position": index}
      }),
    );
    if (response.statusCode == 200 || response.statusCode == 204) {
      currentSong = song;
      currentSong!.positionMs = 0;
      isPlaying = true;
      await Future.delayed(const Duration(milliseconds: 300));
      try {
        final urlGet =
            Uri.parse('https://api.spotify.com/v1/me/player/currently-playing');
        final responseGet = await http.get(
          urlGet,
          headers: {
            'Authorization': 'Bearer $_accessToken',
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
    } else if (response.statusCode == 400 || response.statusCode == 401) {
      if (response.body
          .contains('Only valid bearer authentication supported')) {
        developer.log(
            '[PlayerProvider] Token inválido detectado por Spotify. Redirigiendo a login.');
        _handleInvalidToken();
        return;
      }
    } else if (response.statusCode == 404 || response.statusCode == 403) {
      if (onError != null) {
        onError('No hay ningún dispositivo de reproducción activo.');
      }
    } else {
      throw Exception('Error al reproducir la canción: {response.body}');
    }
  }

  Future<void> playSong(Song song, {void Function(String)? onError}) async {
    final idx = playlist.indexWhere((s) => s.id == song.id);
    if (idx != -1) {
      await playSongFromList(playlist, idx, onError: onError);
    } else {
      await playSongFromList([song], 0, onError: onError);
    }
  }

  Future<void> pause() async {
    if (!await _verifyToken()) return;
    try {
      final urlGet =
          Uri.parse('https://api.spotify.com/v1/me/player/currently-playing');
      final responseGet = await http.get(
        urlGet,
        headers: {
          'Authorization': 'Bearer $_accessToken',
        },
      );
      if (responseGet.statusCode == 200) {
        final data = jsonDecode(responseGet.body);
        final position = data['progress_ms'] ?? 0;
        if (currentSong != null) {
          currentSong!.positionMs = position;
          developer.log(
              '[pause] Posición guardada al pausar (pre-pause): $position ms');
        }
      }
    } catch (_) {}

    if (isProcessing) {
      developer.log('[pause] Ignorado: acción en curso.');
      return;
    }
    isProcessing = true;
    developer.log('[pause] Intentando pausar.');
    _stopPositionTimer();

    final url = Uri.parse('https://api.spotify.com/v1/me/player/pause');
    await http.put(
      url,
      headers: {
        'Authorization': 'Bearer $_accessToken',
      },
    );
    isPlaying = false;
    isProcessing = false;
    notifyListeners();
  }

  Future<void> next({void Function(String)? onError}) async {
    developer.log(
        '[next] playlist.length=${playlist.length}, currentIndex=$currentIndex');
    if (isProcessing) {
      developer.log('[next] Ignorado: acción en curso.');
      return;
    }
    isProcessing = true;
    if (playlist.isEmpty) {
      if (onError != null) onError('No hay playlist cargada.');
      isProcessing = false;
      return;
    }
    int nextIndex = currentIndex + 1;
    if (nextIndex >= playlist.length) {
      if (onError != null) onError('No hay siguiente canción en la playlist.');
      isProcessing = false;
      return;
    }
    developer.log(
        '[next] Avanzando a nextIndex=$nextIndex, canción=${playlist[nextIndex].title}');
    await playSongFromList(playlist, nextIndex, onError: onError);
    isProcessing = false;
  }

  Future<void> previous({void Function(String)? onError}) async {
    developer.log(
        '[previous] playlist.length=${playlist.length}, currentIndex=$currentIndex');
    if (isProcessing) {
      developer.log('[previous] Ignorado: acción en curso.');
      return;
    }
    isProcessing = true;
    if (playlist.isEmpty) {
      if (onError != null) onError('No hay playlist cargada.');
      isProcessing = false;
      return;
    }
    int prevIndex = currentIndex - 1;
    if (prevIndex < 0) {
      if (onError != null) onError('No hay canción anterior en la playlist.');
      isProcessing = false;
      return;
    }
    developer.log(
        '[previous] Retrocediendo a prevIndex=$prevIndex, canción=${playlist[prevIndex].title}');
    await playSongFromList(playlist, prevIndex, onError: onError);
    isProcessing = false;
  }

  Future<void> setVolume(double volume) async {
    if (!await _verifyToken()) return;
    _volume = volume;
    final percent = (volume * 100).toInt();
    final url = Uri.parse(
        'https://api.spotify.com/v1/me/player/volume?volume_percent=$percent');
    final response = await http.put(
      url,
      headers: {
        'Authorization': 'Bearer $_accessToken',
      },
    );
    if (response.statusCode == 200 || response.statusCode == 204) {
      try {
        final urlGet =
            Uri.parse('https://api.spotify.com/v1/me/player/currently-playing');
        final responseGet = await http.get(
          urlGet,
          headers: {
            'Authorization': 'Bearer $_accessToken',
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

  bool _seekInProgress = false;
  int? _pendingSeekMs;
  Future<void> seek(int positionMs, {void Function(String)? onError}) async {
    if (!await _verifyToken()) return;
    if (_seekInProgress) {
      _pendingSeekMs = positionMs;
      return;
    }
    _seekInProgress = true;
    _freezeTimerWhileSeeking = true;
    _stopPositionTimer();
    if (currentSong != null) {
      currentSong!.positionMs = positionMs;
      notifyListeners();
    }
    final url = Uri.parse(
        'https://api.spotify.com/v1/me/player/seek?position_ms=$positionMs');
    final response = await http.put(
      url,
      headers: {
        'Authorization': 'Bearer $_accessToken',
      },
    );
    if (response.statusCode == 200 || response.statusCode == 204) {
      try {
        final urlGet =
            Uri.parse('https://api.spotify.com/v1/me/player/currently-playing');
        final responseGet = await http.get(
          urlGet,
          headers: {
            'Authorization': 'Bearer $_accessToken',
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
      if (onError != null) {
        onError('Error al hacer seek: ${response.body}');
      }
    }
    _seekInProgress = false;
    _freezeTimerWhileSeeking = false;
    if (_pendingSeekMs != null) {
      final nextSeek = _pendingSeekMs!;
      _pendingSeekMs = null;
      await seek(nextSeek, onError: onError);
      return;
    }
    if (currentSong != null &&
        (currentSong!.durationMs - currentSong!.positionMs) < 2000) {
      Future.delayed(const Duration(seconds: 1), _syncWithSpotify);
    }
    _startPositionTimer();
    notifyListeners();
  }

  Future<void> resume({void Function(String)? onError}) async {
    if (!await _verifyToken()) return;
    if (isProcessing) {
      developer.log('[resume] Ignorado: acción en curso.');
      return;
    }
    isProcessing = true;
    developer.log(
        '[resume] Intentando reanudar. Posición guardada: \\${currentSong?.positionMs} ms');
    if (currentSong == null) return;
    final deviceId = await getActiveDeviceId(_accessToken);
    if (deviceId == null) {
      if (onError != null) {
        onError('No hay ningún dispositivo de reproducción activo.');
      }
      isProcessing = false;
      return;
    }
    final url = Uri.parse(
        'https://api.spotify.com/v1/me/player/play?device_id=$deviceId');
    final response = await http.put(
      url,
      headers: {
        'Authorization': 'Bearer $_accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({}),
    );
    if (response.statusCode == 200 || response.statusCode == 204) {
      await Future.delayed(const Duration(milliseconds: 800));
      int? positionReal;
      try {
        final urlGet =
            Uri.parse('https://api.spotify.com/v1/me/player/currently-playing');
        final responseGet = await http.get(
          urlGet,
          headers: {
            'Authorization': 'Bearer $_accessToken',
          },
        );
        if (responseGet.statusCode == 200) {
          final data = jsonDecode(responseGet.body);
          positionReal = data['progress_ms'] ?? 0;
        }
      } catch (_) {}
      final positionGuardada = currentSong!.positionMs;
      final diff =
          positionReal != null ? (positionGuardada - positionReal).abs() : 9999;
      developer.log(
          '[resume] Posición real: $positionReal ms, guardada: $positionGuardada ms, diff: $diff ms');
      if (positionGuardada > 0 &&
          positionGuardada < currentSong!.durationMs &&
          positionReal != null &&
          positionReal < positionGuardada &&
          diff > 2500) {
        try {
          developer.log('[resume] Haciendo seek a: $positionGuardada ms');
          await seek(positionGuardada);
        } catch (_) {}
      } else {
        developer.log(
            '[resume] No se hace seek porque diff <= 2500 ms o la real es mayor que la guardada');
      }
      try {
        final urlGet =
            Uri.parse('https://api.spotify.com/v1/me/player/currently-playing');
        final responseGet = await http.get(
          urlGet,
          headers: {
            'Authorization': 'Bearer $_accessToken',
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
      isProcessing = false;
      notifyListeners();
      _startPositionTimer();
    } else {
      if (onError != null) {
        onError('No se pudo reanudar la reproducción.');
      }
      isProcessing = false;
    }
  }

  void _startPositionTimer() {
    _startSyncTimer();
    _positionTimer?.cancel();
    if (currentSong == null) return;
    _positionTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!isPlaying || currentSong == null || _freezeTimerWhileSeeking) return;
      if (currentSong!.positionMs + 1000 >= currentSong!.durationMs) {
        currentSong!.positionMs = currentSong!.durationMs;
        notifyListeners();
        if (repeatSong) {
          await seek(0);
          await resume();
        } else {
          await next();
        }
        return;
      }
      currentSong!.positionMs += 1000;
      notifyListeners();
    });
  }

  void _stopPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = null;
    _syncTimer?.cancel();
    _syncTimer = null;
  }
}
