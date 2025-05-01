import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import 'task_manager.dart';
import '../models/spotify_track.dart';
import '../models/song_model.dart';
import '../models/spotify_device.dart';
import 'package:http/http.dart' as http;
import 'settings_screen.dart';
import 'dart:convert';
import '../services/auth_service.dart';
import 'mini_player.dart';
import '../utils/spotify_search.dart';
import '../widgets/spotify_search_field.dart';

class MainPlayerScreen extends StatefulWidget {
  const MainPlayerScreen({super.key});

  @override
  State<MainPlayerScreen> createState() => _MainPlayerScreenState();
}

class _MainPlayerScreenState extends State<MainPlayerScreen> {
  int _selectedTab = 1; // 0: Player, 1: Home, 2: Tasks

  Future<List<SpotifyDevice>> getSpotifyDevices(BuildContext context) async {
    final auth = AuthService();
    final token = await auth.getAccessToken();
    if (token == null) throw 'No se encontró el token de sesión de Spotify.';
    final url = Uri.parse('https://api.spotify.com/v1/me/player/devices');
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode != 200) {
      throw 'Error al obtener dispositivos: ${response.statusCode}';
    }
    final data = json.decode(response.body);
    final items = data['devices'] as List<dynamic>;
    return items.map((item) => SpotifyDevice.fromJson(item)).toList();
  }

  void showDevicesDialog(BuildContext context) async {
    try {
      final devices = await getSpotifyDevices(context);
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Dispositivos de Spotify'),
          content: devices.isEmpty
              ? const Text('No hay dispositivos disponibles.')
              : SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: devices.length,
                    itemBuilder: (context, index) {
                      final d = devices[index];
                      return ListTile(
                        leading: Icon(
                          d.isActive ? Icons.play_circle_fill : Icons.devices,
                          color: d.isActive ? Colors.green : Colors.grey,
                        ),
                        title: Text(d.name),
                        subtitle: Text(d.type),
                        trailing: d.isActive ? const Text('Activo', style: TextStyle(color: Colors.green)) : null,
                        onTap: () async {
                          Navigator.of(context).pop();
                          final auth = AuthService();
                          final token = await auth.getAccessToken();
                          if (token == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('No hay sesión activa de Spotify.')),
                            );
                            return;
                          }
                          final response = await http.put(
                            Uri.parse('https://api.spotify.com/v1/me/player/transfer'),
                            headers: {
                              'Authorization': 'Bearer $token',
                              'Content-Type': 'application/json',
                            },
                            body: json.encode({
                              'device_ids': [d.id],
                              'play': true, // Reproduce automáticamente
                            }),
                          );
                          if (response.statusCode == 204) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Transferido a: ${d.name}')),
                            );
                          } else {
                            String errorMsg = 'No se pudo transferir (${response.statusCode})';
                            try {
                              final Map<String, dynamic> errorBody = json.decode(response.body);
                              if (errorBody.containsKey('error')) {
                                errorMsg += ': ' + (errorBody['error']['message'] ?? '');
                              }
                            } catch (_) {}
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(errorMsg)),
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (e) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Error'),
          content: Text(e.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Provee el context global al PlayerProvider para navegación segura
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    playerProvider.setContext(context);
    return Scaffold(
      backgroundColor: const Color(0xFF0E1928),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Sincronía', style: TextStyle(fontFamily: 'Serif', fontSize: 28, color: Colors.white, letterSpacing: 1)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.settings, color: Colors.white70),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.devices, color: Colors.white70),
            tooltip: 'Mostrar dispositivos',
            onPressed: () => showDevicesDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white70),
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF182B45),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.music_note, color: _selectedTab == 0 ? Colors.white : Colors.white.withOpacity(0.6)),
                            onPressed: () => setState(() => _selectedTab = 0),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: _selectedTab == 1 ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                            child: IconButton(
                              icon: Icon(Icons.home, color: _selectedTab == 1 ? const Color(0xFF182B45) : Colors.white.withOpacity(0.6)),
                              onPressed: () => setState(() => _selectedTab = 1),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(Icons.calendar_today, color: _selectedTab == 2 ? Colors.white : Colors.white.withOpacity(0.6)),
                            onPressed: () => setState(() => _selectedTab = 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: _selectedTab == 1
                      ? _buildHomeContent()
                      : _selectedTab == 2
                        ? _buildTaskManager()
                        : _buildPlayerContent(),
                  ),
                ],
              ),
            ),
          ),
          // MiniPlayer siempre visible
          MiniPlayer(),
        ],
      ),
    );
  }

  Widget _buildHomeContent() {
    return Center(
      child: Text(
        '¡Bienvenido a Sincronía! Elige una sección para explorar tu música.',
        style: TextStyle(color: Colors.white, fontSize: 20),
        textAlign: TextAlign.center,
      ),
    );
  }

  SliverToBoxAdapter _buildSectionTitle(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          title,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildHorizontalTrackList(Future<List<SpotifyTrack>> futureTracks) {
    return SliverToBoxAdapter(
      child: FutureBuilder<List<SpotifyTrack>>(
        future: futureTracks,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return SizedBox(
              height: 180,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return SizedBox(
              height: 180,
              child: Center(
                child: Text('Error: \\n${snapshot.error}', style: TextStyle(color: Colors.red[200])),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return SizedBox(height: 180, child: Center(child: Text('Sin canciones', style: TextStyle(color: Colors.white70))));
          }
          final tracks = snapshot.data!;
          return SizedBox(
            height: 180,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: tracks.length,
              separatorBuilder: (_, __) => SizedBox(width: 16),
              itemBuilder: (context, index) {
                final track = tracks[index];
                return _buildTrackCard(track);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildTrackCard(SpotifyTrack track) {
    return GestureDetector(
      onTap: () async {
        final player = Provider.of<PlayerProvider>(context, listen: false);
        await player.playSongFromList([
          Song(
            id: track.uri.split(':').last,
            title: track.title,
            artist: track.artist,
            album: '',
            albumArtUrl: track.albumArtUrl,
            durationMs: _parseDuration(track.duration),
          )
        ], 0);
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                track.albumArtUrl,
                width: 140,
                height: 140,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 140,
                  height: 140,
                  color: Colors.grey[900],
                  child: Icon(Icons.music_note, color: Colors.white38, size: 48),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Text(
                      track.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        track.duration,
                        style: const TextStyle(color: Color(0xFFe0c36a), fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _parseDuration(String durationString) {
    // Convierte "mm:ss" a milisegundos
    final parts = durationString.split(':');
    if (parts.length != 2) return 0;
    final minutes = int.tryParse(parts[0]) ?? 0;
    final seconds = int.tryParse(parts[1]) ?? 0;
    return (minutes * 60 + seconds) * 1000;
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  // Favoritas: Top tracks
  Future<List<SpotifyTrack>> _getFavoriteTracksFuture() async => _fetchTopTracks();
  // Reproducidas recientemente
  Future<List<SpotifyTrack>> _getRecentlyPlayedFuture() async => _fetchRecentlyPlayed();
  // Nuevos lanzamientos
  Future<List<SpotifyTrack>> _getNewReleasesFuture() async => _fetchNewReleases();

  Future<List<SpotifyTrack>> _fetchTopTracks() async {
    final auth = AuthService();
    final token = await auth.getAccessToken();
    if (token == null) throw 'No se encontró el token de sesión de Spotify.';
    final url = Uri.parse('https://api.spotify.com/v1/me/top/tracks?limit=20');
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode != 200) throw 'Error al obtener top tracks: \\n${response.body}';
    final data = json.decode(response.body);
    final items = data['items'] as List<dynamic>;
    return items.map(_spotifyTrackFromItem).toList();
  }

  Future<List<SpotifyTrack>> _fetchRecentlyPlayed() async {
    final auth = AuthService();
    final token = await auth.getAccessToken();
    if (token == null) throw 'No se encontró el token de sesión de Spotify.';
    final url = Uri.parse('https://api.spotify.com/v1/me/player/recently-played?limit=20');
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode != 200) throw 'Error al obtener reproducidas recientemente: \\n${response.body}';
    final data = json.decode(response.body);
    final items = data['items'] as List<dynamic>;
    return items.map((item) => _spotifyTrackFromItem(item['track'])).toList();
  }

  Future<List<SpotifyTrack>> _fetchNewReleases() async {
    final auth = AuthService();
    final token = await auth.getAccessToken();
    if (token == null) throw 'No se encontró el token de sesión de Spotify.';
    final url = Uri.parse('https://api.spotify.com/v1/browse/new-releases?limit=20');
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode != 200) throw 'Error al obtener nuevos lanzamientos: \\n${response.body}';
    final data = json.decode(response.body);
    final items = (data['albums']['items'] as List<dynamic>);
    // Tomamos la primera canción de cada álbum
    List<SpotifyTrack> tracks = [];
    for (final album in items) {
      if (album['id'] == null) continue;
      final albumId = album['id'];
      final albumUrl = Uri.parse('https://api.spotify.com/v1/albums/$albumId');
      final albumResp = await http.get(albumUrl, headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      });
      if (albumResp.statusCode == 200) {
        final albumData = json.decode(albumResp.body);
        final tracksList = albumData['tracks']['items'] as List<dynamic>;
        if (tracksList.isNotEmpty) {
          final firstTrack = tracksList[0];
          tracks.add(_spotifyTrackFromItem({
            ...firstTrack,
            'album': album, // Usamos la portada del álbum
          }));
        }
      }
    }
    return tracks;
  }

  SpotifyTrack _spotifyTrackFromItem(dynamic item) {
    final durationMs = item['duration_ms'] as int? ?? 0;
    final duration = _formatDuration(Duration(milliseconds: durationMs));
    return SpotifyTrack(
      title: item['name'] ?? '',
      artist: (item['artists'] as List).isNotEmpty ? item['artists'][0]['name'] : '',
      duration: duration,
      albumArtUrl: item['album'] != null && (item['album']['images'] as List).isNotEmpty
          ? item['album']['images'][0]['url']
          : '',
      uri: item['uri'] ?? '',
    );
  }

  Widget _buildTaskManager() {
    // Usar solo el widget TaskManagerScreen centralizado
    return const TaskManagerScreen();
  }

  String _dueDateText(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'Hoy';
    } else if (date.isBefore(now)) {
      return 'Ayer';
    } else if (date.difference(now).inDays == 1) {
      return 'Mañana';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Widget _priorityChip(String priority) {
    Color color;
    switch (priority) {
      case 'Volumen al 100':
        color = Colors.red;
        break;
      case 'Coro pegajoso':
        color = Colors.yellow[800]!;
        break;
      case 'Beat suave':
        color = Colors.green[700]!;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        border: Border.all(color: color, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(priority, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }

  Widget _labelChip(String label) {
    Color color;
    switch (label) {
      case 'Investigación':
        color = Colors.black;
        break;
      case 'Estudio':
        color = Colors.white;
        break;
      case 'Ejercicio':
        color = Colors.white;
        break;
      case 'Viaje':
        color = Colors.white;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        border: Border.all(color: color, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(color: color == Colors.white ? Colors.black : color, fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }

  // Playlists del usuario
  Future<List<SpotifyTrack>> _getUserPlaylistsFuture() async => _fetchUserPlaylists();

  Future<List<SpotifyTrack>> _fetchUserPlaylists() async {
    final auth = AuthService();
    final token = await auth.getAccessToken();
    if (token == null) throw 'No se encontró el token de sesión de Spotify.';
    final url = Uri.parse('https://api.spotify.com/v1/me/playlists?limit=20');
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode != 200) throw 'Error al obtener playlists: \n${response.body}';
    final data = json.decode(response.body);
    final items = data['items'] as List<dynamic>;
    return items.map((item) {
      final images = item['images'] as List<dynamic>? ?? [];
      return SpotifyTrack(
        title: item['name'] ?? '',
        artist: item['owner']?['display_name'] ?? '',
        duration: '',
        albumArtUrl: images.isNotEmpty ? images[0]['url'] ?? '' : '',
        uri: item['uri'] ?? '',
      );
    }).toList();
  }

  Widget _buildPlaylistCard(SpotifyTrack playlist) {
    return GestureDetector(
      onTap: () async {
        final auth = AuthService();
        final token = await auth.getAccessToken();
        if (token == null) throw 'No se encontró el token de sesión de Spotify.';
        
        // Obtener las canciones de la playlist
        final playlistId = playlist.uri.split(':').last;
        final url = Uri.parse('https://api.spotify.com/v1/playlists/$playlistId/tracks');
        final response = await http.get(
          url,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );
        if (response.statusCode != 200) throw 'Error al obtener canciones de la playlist: \n${response.body}';
        
        final data = json.decode(response.body);
        final items = data['items'] as List<dynamic>;
        final songs = items.map((item) {
          final track = item['track'] as Map<String, dynamic>? ?? {};
          final artists = track['artists'] as List<dynamic>? ?? [];
          final album = track['album'] as Map<String, dynamic>? ?? {};
          final images = album['images'] as List<dynamic>? ?? [];
          
          return Song(
            id: track['id'] ?? '',
            title: track['name'] ?? '',
            artist: artists.isNotEmpty ? artists[0]['name'] ?? '' : '',
            album: album['name'] ?? '',
            albumArtUrl: images.isNotEmpty ? images[0]['url'] ?? '' : '',
            durationMs: track['duration_ms'] ?? 0,
          );
        }).toList();

        final player = Provider.of<PlayerProvider>(context, listen: false);
        await player.playSongFromList(songs, 0);
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                playlist.albumArtUrl,
                width: 140,
                height: 140,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 140,
                  height: 140,
                  color: Colors.grey[900],
                  child: Icon(Icons.playlist_play, color: Colors.white38, size: 48),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      playlist.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Text(
                      playlist.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFe0c36a).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.play_circle_filled, color: Color(0xFFe0c36a), size: 24),
                          onPressed: null, // El onTap del GestureDetector maneja la reproducción
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerContent() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: SpotifySearchField(
              controller: TextEditingController(),
              onChanged: (_) {},
              hintText: 'Buscar en Spotify...',
              showClear: false,
              onClear: () {},
            ),
          ),
        ),
        _buildSectionTitle('Tus playlists'),
        SliverToBoxAdapter(
          child: FutureBuilder<List<SpotifyTrack>>(
            future: _getUserPlaylistsFuture(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return SizedBox(
                  height: 180,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return SizedBox(
                  height: 180,
                  child: Center(
                    child: Text('Error: \n${snapshot.error}', style: TextStyle(color: Colors.red[200])),
                  ),
                );
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return SizedBox(
                  height: 180,
                  child: Center(child: Text('Sin playlists', style: TextStyle(color: Colors.white70))),
                );
              }
              final playlists = snapshot.data!;
              return SizedBox(
                height: 180,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: playlists.length,
                  separatorBuilder: (_, __) => SizedBox(width: 16),
                  itemBuilder: (context, index) {
                    final playlist = playlists[index];
                    return _buildPlaylistCard(playlist);
                  },
                ),
              );
            },
          ),
        ),
        _buildSectionTitle('Tus favoritas'),
        _buildHorizontalTrackList(_getFavoriteTracksFuture()),
        _buildSectionTitle('Reproducidas recientemente'),
        _buildHorizontalTrackList(_getRecentlyPlayedFuture()),
        _buildSectionTitle('Nuevos lanzamientos'),
        _buildHorizontalTrackList(_getNewReleasesFuture()),
        SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }
}

class _SpotifyGlobalSearchPlayerContent extends StatefulWidget {
  final SliverToBoxAdapter Function(String) buildSectionTitle;
  final SliverToBoxAdapter Function(Future<List<SpotifyTrack>>) buildHorizontalTrackList;
  final Widget Function(SpotifyTrack) buildTrackCard;
  final Future<List<SpotifyTrack>> Function() getFavoriteTracksFuture;
  final Future<List<SpotifyTrack>> Function() getRecentlyPlayedFuture;
  final Future<List<SpotifyTrack>> Function() getNewReleasesFuture;
  final Future<List<SpotifyTrack>> Function() getUserPlaylistsFuture;
  final Widget Function(SpotifyTrack) buildPlaylistCard;

  const _SpotifyGlobalSearchPlayerContent({
    required this.buildSectionTitle,
    required this.buildHorizontalTrackList,
    required this.buildTrackCard,
    required this.getFavoriteTracksFuture,
    required this.getRecentlyPlayedFuture,
    required this.getNewReleasesFuture,
    required this.getUserPlaylistsFuture,
    required this.buildPlaylistCard,
    Key? key,
  }) : super(key: key);

  @override
  State<_SpotifyGlobalSearchPlayerContent> createState() => _SpotifyGlobalSearchPlayerContentState();
}

class _SpotifyGlobalSearchPlayerContentState extends State<_SpotifyGlobalSearchPlayerContent> {
  final TextEditingController _searchController = TextEditingController();
  List<Song> _searchResults = [];
  bool _isSearching = false;
  String _lastQuery = '';

  void _onSearchChanged(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _lastQuery = '';
      });
      return;
    }
    setState(() { _isSearching = true; });
    try {
      final results = await SpotifySearchService.searchTracks(query);
      setState(() {
        _searchResults = results;
        _isSearching = false;
        _lastQuery = query;
      });
    } catch (_) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _lastQuery = query;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: SpotifySearchField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              hintText: 'Buscar en Spotify...',
              showClear: _searchController.text.isNotEmpty,
              onClear: () {
                _searchController.clear();
                _onSearchChanged('');
              },
            ),
          ),
        ),
        if (_searchController.text.isNotEmpty)
          _isSearching
              ? const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              : _searchResults.isEmpty && _lastQuery.isNotEmpty
                  ? const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: Text('No se encontraron canciones.', style: TextStyle(color: Colors.white70))),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, idx) {
                          final song = _searchResults[idx];
                          return ListTile(
                            leading: song.albumArtUrl.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.network(song.albumArtUrl, width: 40, height: 40, fit: BoxFit.cover),
                                  )
                                : const Icon(Icons.music_note, color: Colors.white70),
                            title: Text(song.title, style: const TextStyle(color: Colors.white)),
                            subtitle: Text(song.artist, style: const TextStyle(color: Colors.white70)),
                            onTap: () async {
                              final player = Provider.of<PlayerProvider>(context, listen: false);
                              await player.playSongFromList([song], 0);
                            },
                          );
                        },
                        childCount: _searchResults.length,
                      ),
                    )
        else ...[
          widget.buildSectionTitle('Tus favoritas'),
          widget.buildHorizontalTrackList(widget.getFavoriteTracksFuture()),
          widget.buildSectionTitle('Reproducidas recientemente'),
          widget.buildHorizontalTrackList(widget.getRecentlyPlayedFuture()),
          widget.buildSectionTitle('Nuevos lanzamientos'),
          widget.buildHorizontalTrackList(widget.getNewReleasesFuture()),
          widget.buildSectionTitle('Tus playlists'),
          SliverToBoxAdapter(
            child: FutureBuilder<List<SpotifyTrack>>(
              future: widget.getUserPlaylistsFuture(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return SizedBox(
                    height: 180,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return SizedBox(
                    height: 180,
                    child: Center(
                      child: Text('Error: \n${snapshot.error}', style: TextStyle(color: Colors.red[200])),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return SizedBox(
                    height: 180,
                    child: Center(child: Text('Sin playlists', style: TextStyle(color: Colors.white70))),
                  );
                }
                final playlists = snapshot.data!;
                return SizedBox(
                  height: 180,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: playlists.length,
                    separatorBuilder: (_, __) => SizedBox(width: 16),
                    itemBuilder: (context, index) {
                      final playlist = playlists[index];
                      return widget.buildPlaylistCard(playlist);
                    },
                  ),
                );
              },
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ],
    );
  }
}
