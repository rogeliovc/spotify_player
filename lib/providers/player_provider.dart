import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/spotify_device_utils.dart';
import '../models/song_model.dart';
import '../services/auth_service.dart';
import '../screens/home_screen_login.dart';
import 'dart:async';

class PlayerProvider extends ChangeNotifier {
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
      // Intenta obtener un nuevo token antes de cerrar sesión
      final token = await _authService.getAccessToken();
      if (token != null) {
        _accessToken = token;
        return;
      }

      // Si no se pudo obtener un nuevo token, procede a cerrar sesión
      await _authService.signOut();
      if (_context != null) {
        ScaffoldMessenger.of(_context!).showSnackBar(
          const SnackBar(
            content: Text('Tu sesión ha expirado. Por favor, inicia sesión nuevamente.'),
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.of(_context!).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreenLogin()),
          (route) => false,
        );
      }
    } catch (e) {
      print('[PlayerProvider] Error en _handleInvalidToken: $e');
    }
  }

  Future<bool> _verifyToken() async {
    try {
      // Si no tenemos token, intentamos obtener uno
      if (_accessToken.isEmpty) {
        _accessToken = (await _authService.getAccessToken()) ?? '';
        if (_accessToken.isEmpty) {
          print('[PlayerProvider] No se pudo obtener token inicial');
          return false;
        }
      }

      // Verifica si el token es válido
      final isValid = await _authService.isTokenValid();
      if (!isValid) {
        // Intenta refrescar el token
        final refreshed = await _authService.refreshAccessToken();
        if (refreshed) {
          // Si se refrescó exitosamente, actualiza el token
          _accessToken = (await _authService.getAccessToken()) ?? '';
          return true;
        } else {
          // Si falla el refresh, registra el error pero no cierra sesión inmediatamente
          print('[PlayerProvider] Falló el refresh del token');
          return false;
        }
      }
      return true;
    } catch (e) {
      print('[PlayerProvider] Error en _verifyToken: $e');
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
      print('[PlayerProvider] accessToken vacío. Redirigiendo a login.');
      _handleInvalidToken();
      return;
    }
    if (currentSong == null) return;
    try {
      final urlGet = Uri.parse('https://api.spotify.com/v1/me/player/currently-playing');
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
        // Si la canción cambió en Spotify, fuerza el cambio local
        if (songId != null && currentSong!.id != songId) {
          // Busca la nueva canción en la playlist
          final idx = playlist.indexWhere((s) => s.id == songId);
          if (idx != -1) {
            await playSongFromList(playlist, idx);
            return;
          }
        }
        // Si la canción terminó en Spotify pero el timer local no lo detectó
        if (position >= duration - 500 && !isPlayingSpotify) {
          if (repeatSong) {
            await seek(0);
            await resume();
          } else {
            await next();
          }
          return;
        }
        // Corrige desfase de posición
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
  bool repeatSong = false; // Nuevo flag para repetir la canción actual
  double _volume = 0.5;
  double get volume => _volume;

  Future<void> playSongFromList(List<Song> songs, int index, {void Function(String)? onError}) async {
    if (!await _verifyToken()) return;

    print('[playSongFromList] Llamado con index=$index, songs.length=${songs.length}');
    if (songs.isEmpty || index < 0 || index >= songs.length) {
      if (onError != null) onError('Índice o lista inválida.');
      return;
    }
    playlist = List<Song>.from(songs);
    currentIndex = index;
    print('[playSongFromList] playlist actualizada. currentIndex=$currentIndex, canción=${playlist[currentIndex].title}');
    final song = songs[index];
    await pause();
    _stopPositionTimer();
    final deviceId = await getActiveDeviceId(_accessToken);
    if (deviceId == null) {
      if (onError != null) {
        onError('No hay ningún dispositivo de reproducción activo. Abre la app de música en tu dispositivo y reproduce una canción manualmente antes de usar Sincronía.');
      }
      return;
    }
    // Transfiere el playback al dispositivo antes de reproducir
    await transferPlaybackToDevice(_accessToken, deviceId);
    final url = Uri.parse('https://api.spotify.com/v1/me/player/play?device_id=$deviceId');
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
      currentSong!.positionMs = 0; // Reinicia la barra de progreso
      isPlaying = true;
      await Future.delayed(const Duration(milliseconds: 300));
      try {
        final urlGet = Uri.parse('https://api.spotify.com/v1/me/player/currently-playing');
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
      if (response.body.contains('Only valid bearer authentication supported')) {
        print('[PlayerProvider] Token inválido detectado por Spotify. Redirigiendo a login.');
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

  // Compatibilidad con llamada antigua
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
    // Obtener la posición real desde Spotify ANTES de pausar
    try {
      final urlGet = Uri.parse('https://api.spotify.com/v1/me/player/currently-playing');
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
          print('[pause] Posición guardada al pausar (pre-pause): $position ms');
        }
      }
    } catch (_) {}

    if (isProcessing) {
      print('[pause] Ignorado: acción en curso.');
      return;
    }
    isProcessing = true;
    print('[pause] Intentando pausar.');
    _stopPositionTimer();

    final url = Uri.parse('https://api.spotify.com/v1/me/player/pause');
    final response = await http.put(
      url,
      headers: {
        'Authorization': 'Bearer $_accessToken',
      },
    );
    // Siempre actualiza el estado y notifica
    isPlaying = false;
    isProcessing = false;
    notifyListeners();
    // Ignorar cualquier otro error para no bloquear la reproducción
  }
// --- FIN DEL METODO PAUSE ---


  /// Reproduce la siguiente canción en la cola de Spotify.
  Future<void> next({void Function(String)? onError}) async {
  print('[next] playlist.length=${playlist.length}, currentIndex=$currentIndex');
    if (isProcessing) {
      print('[next] Ignorado: acción en curso.');
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
    print('[next] Avanzando a nextIndex=$nextIndex, canción=${playlist[nextIndex].title}');
  await playSongFromList(playlist, nextIndex, onError: onError);
  isProcessing = false;
  }

  /// Retrocede a la canción anterior en la cola de Spotify.
  Future<void> previous({void Function(String)? onError}) async {
  print('[previous] playlist.length=${playlist.length}, currentIndex=$currentIndex');
    if (isProcessing) {
      print('[previous] Ignorado: acción en curso.');
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
    print('[previous] Retrocediendo a prevIndex=$prevIndex, canción=${playlist[prevIndex].title}');
  await playSongFromList(playlist, prevIndex, onError: onError);
  isProcessing = false;
  }

  /// Cambia el volumen de reproducción (0.0 a 1.0).
  Future<void> setVolume(double volume) async {
    if (!await _verifyToken()) return;
    _volume = volume;
    final percent = (volume * 100).toInt();
    final url = Uri.parse('https://api.spotify.com/v1/me/player/volume?volume_percent=$percent');
    final response = await http.put(
      url,
      headers: {
        'Authorization': 'Bearer $_accessToken',
      },
    );
    if (response.statusCode == 200 || response.statusCode == 204) {
      // Sincroniza la posición real después del seek
      try {
        final urlGet = Uri.parse('https://api.spotify.com/v1/me/player/currently-playing');
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

  /// Hace seek a una posición específica en la canción actual (en milisegundos).
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
    // Actualiza localmente para feedback inmediato
    if (currentSong != null) {
      currentSong!.positionMs = positionMs;
      notifyListeners();
    }
    final url = Uri.parse('https://api.spotify.com/v1/me/player/seek?position_ms=$positionMs');
    final response = await http.put(
      url,
      headers: {
        'Authorization': 'Bearer $_accessToken',
      },
    );
    if (response.statusCode == 200 || response.statusCode == 204) {
      // Sincroniza la posición real después del seek
      try {
        final urlGet = Uri.parse('https://api.spotify.com/v1/me/player/currently-playing');
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
      // Notifica error pero no lances excepción
      if (onError != null) {
        onError('Error al hacer seek: ${response.body}');
      }
    }
    _seekInProgress = false;
    _freezeTimerWhileSeeking = false;
    // Si hay un seek pendiente, ejecútalo ahora
    if (_pendingSeekMs != null) {
      final nextSeek = _pendingSeekMs!;
      _pendingSeekMs = null;
      await seek(nextSeek, onError: onError);
      return;
    }
    // Si el seek fue cerca del final, fuerza sincronización tras 1s
    if (currentSong != null &&
        (currentSong!.durationMs - currentSong!.positionMs) < 2000) {
      Future.delayed(const Duration(seconds: 1), _syncWithSpotify);
    }
    _startPositionTimer();
    // No hagas nada más, ignora el error para no romper la app
    notifyListeners();
  }

  /// Reanuda la reproducción desde la posición actual de la canción
  Future<void> resume({void Function(String)? onError}) async {
    if (!await _verifyToken()) return;
  if (isProcessing) {
    print('[resume] Ignorado: acción en curso.');
    return;
  }
  isProcessing = true;
  print('[resume] Intentando reanudar. Posición guardada: \\${currentSong?.positionMs} ms');
    if (currentSong == null) return;
    final deviceId = await getActiveDeviceId(_accessToken);
    if (deviceId == null) {
      if (onError != null) {
        onError('No hay ningún dispositivo de reproducción activo.');
      }
      isProcessing = false;
      return;
    }
    // Reanudar playback sin cambiar la canción
    final url = Uri.parse('https://api.spotify.com/v1/me/player/play?device_id=$deviceId');
    final response = await http.put(
      url,
      headers: {
        'Authorization': 'Bearer $_accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({}),
    );
    if (response.statusCode == 200 || response.statusCode == 204) {
      // Espera un poco antes de hacer seek
      await Future.delayed(const Duration(milliseconds: 800));
      // Sincroniza la posición real antes de decidir si hacer seek
      int? positionReal;
      try {
        final urlGet = Uri.parse('https://api.spotify.com/v1/me/player/currently-playing');
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
      final diff = positionReal != null ? (positionGuardada - positionReal).abs() : 9999;
      print('[resume] Posición real: $positionReal ms, guardada: $positionGuardada ms, diff: $diff ms');
      // Solo haz seek si la real es MENOR que la guardada y la diferencia es significativa
      if (positionGuardada > 0 && positionGuardada < currentSong!.durationMs && positionReal != null && positionReal < positionGuardada && diff > 2500) {
        try {
          print('[resume] Haciendo seek a: $positionGuardada ms');
          await seek(positionGuardada);
        } catch (_) {
          // Si el seek falla, solo ignóralo y sigue
        }
      } else {
        print('[resume] No se hace seek porque diff <= 2500 ms o la real es mayor que la guardada');
      }
      // Sincroniza la posición real después del seek
      try {
        final urlGet = Uri.parse('https://api.spotify.com/v1/me/player/currently-playing');
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
          // Reinicia la canción desde el inicio
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