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

class MainPlayerScreen extends StatefulWidget {
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
      body: SafeArea(
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
    );
  }

  Widget _buildHomeContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Aquí va el contenido principal de inicio (puedes dejar el calendario, playlists, etc)
        const Text('Pantalla de inicio', style: TextStyle(color: Colors.white, fontSize: 20)),
        const SizedBox(height: 24),
      ],
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


  Widget _buildPlayerContent() {
    // Lista de canciones top
    return FutureBuilder<List<SpotifyTrack>>(
      future: getSpotifyTracks(context),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: \\${snapshot.error}', style: const TextStyle(color: Colors.white)));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No hay canciones para mostrar', style: TextStyle(color: Colors.white)));
        }
        final tracks = snapshot.data!;
        return SizedBox.expand(
          child: Stack(
            children: [
              ListView.separated(
                padding: const EdgeInsets.only(bottom: 120),
                itemCount: tracks.length,
                separatorBuilder: (_, __) => const Divider(color: Colors.white24, height: 1),
                itemBuilder: (context, index) {
                  final track = tracks[index];
                  return ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(track.albumArtUrl, width: 48, height: 48, fit: BoxFit.cover),
                    ),
                    title: Text(track.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text(track.artist, style: const TextStyle(color: Colors.white70)),
                    trailing: Text(track.duration, style: const TextStyle(color: Color(0xFFe0c36a))),
                    onTap: () async {
                      final player = Provider.of<PlayerProvider>(context, listen: false);
                      // Reproducir la canción directamente
                      await player.playSong(Song(
                        id: track.uri.split(':').last,
                        title: track.title,
                        artist: track.artist,
                        album: '',
                        albumArtUrl: track.albumArtUrl,
                        durationMs: _parseDuration(track.duration),
                      ));
                    },
                  );
                },
              ),
              // Mini Player Expandible
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: MiniPlayer(),
              ),
            ],
          ),
        );
      },
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

  Future<List<SpotifyTrack>> getSpotifyTracks(BuildContext context) async {
    // Importa AuthService y http arriba si no están importados
    // import 'package:http/http.dart' as http;
    // import '../services/auth_service.dart';
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
    if (response.statusCode != 200) {
      throw 'Error al obtener canciones: ${response.statusCode}\n${response.body}';
    }
    final data = json.decode(response.body);
    final items = data['items'] as List<dynamic>;
    return items.map((item) {
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
    }).toList();
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }






}
