import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({Key? key}) : super(key: key);

  Future<List<Map<String, dynamic>>> _fetchUserPlaylists(
      BuildContext context) async {
    final auth = AuthService();
    final token = await auth.getAccessToken();
    if (token == null) throw 'No se encontró el token de sesión de Spotify.';
    final url = Uri.parse('https://api.spotify.com/v1/me/playlists?limit=50');
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode != 200) {
      throw 'Error al obtener playlists: ${response.body}';
    }
    final data = json.decode(response.body);
    final items = data['items'] as List<dynamic>;
    return items
        .map((item) => {
              'id': item['id'],
              'name': item['name'],
            })
        .toList();
  }

  Future<void> _addTrackToPlaylist(
      BuildContext context, String playlistId, String trackUri) async {
    final auth = AuthService();
    final token = await auth.getAccessToken();
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay sesión activa de Spotify.')),
      );
      return;
    }
    final url =
        Uri.parse('https://api.spotify.com/v1/playlists/$playlistId/tracks');
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'uris': [trackUri]
      }),
    );
    if (response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Canción agregada a la playlist')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al agregar canción: ${response.body}')),
      );
    }
  }

  void _onAddToPlaylistPressed(BuildContext context, String trackUri) async {
    try {
      final playlists = await _fetchUserPlaylists(context);
      if (playlists.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No tienes playlists disponibles')),
        );
        return;
      }
      String? selectedId;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Agregar a playlist'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: playlists.length,
              itemBuilder: (context, index) {
                final pl = playlists[index];
                return ListTile(
                  title: Text(pl['name']),
                  onTap: () {
                    selectedId = pl['id'];
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
          ),
        ),
      );
      if (selectedId != null) {
        await _addTrackToPlaylist(context, selectedId!, trackUri);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerProvider = Provider.of<PlayerProvider>(context);
    final currentSong = playerProvider.currentSong;

    return Container(
      // ...puedes agregar estilos aquí...
      child: Row(
        children: [
          // ...otros controles del mini reproductor (play, pause, etc.)...
          if (currentSong != null && currentSong.id.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.playlist_add, color: Color(0xFFe0c36a)),
              tooltip: 'Agregar a playlist',
              onPressed: () {
                final trackUri = 'spotify:track:${currentSong.id}';
                _onAddToPlaylistPressed(context, trackUri);
              },
            ),
          // ...otros controles...
        ],
      ),
    );
  }
}
