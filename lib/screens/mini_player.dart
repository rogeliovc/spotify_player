import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:palette_generator/palette_generator.dart';
import '../providers/player_provider.dart';
import '../models/song_model.dart';
import '../utils/spotify_search.dart';
import '../services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MiniPlayer extends StatefulWidget {
  final VoidCallback? onRequestPlaylistRefresh; // NUEVO
  const MiniPlayer({super.key, this.onRequestPlaylistRefresh});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  Color? _dominantColor;
  PlayerProvider? _playerProvider;
  VoidCallback? _listener;
  String? _lastSongId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = Provider.of<PlayerProvider>(context);
    if (_playerProvider != provider) {
      _playerProvider?.removeListener(_listener ?? () {});
      _playerProvider = provider;
      _listener = () async {
        if (!mounted) return;
        final song = _playerProvider?.currentSong;
        if (song?.id != _lastSongId) {
          setState(() {}); // Fuerza reconstrucción inmediata
          _lastSongId = song?.id;
          await _updateDominantColor();
        }
      };
      _playerProvider!.addListener(_listener!);
      // Actualiza el color al entrar
      final song = provider.currentSong;
      _lastSongId = song?.id;
      _updateDominantColor();
    }
  }

  @override
  void dispose() {
    _playerProvider?.removeListener(_listener ?? () {});
    super.dispose();
  }

  Future<void> _updateDominantColor() async {
    final player = Provider.of<PlayerProvider>(context, listen: false);
    final song = player.currentSong;
    if (song == null || song.albumArtUrl.isEmpty) return;
    try {
      final PaletteGenerator palette = await PaletteGenerator.fromImageProvider(
        NetworkImage(song.albumArtUrl),
        size: const Size(200, 200),
      );
      setState(() {
        _dominantColor =
            palette.dominantColor?.color ?? const Color(0xFF151C2C);
      });
    } catch (_) {
      setState(() {
        _dominantColor = const Color(0xFF151C2C);
      });
    }
  }

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

  // Todas las las funciones privadas deben estar aquí dentro
  Future<void> _deletePlaylist(BuildContext context, String playlistId) async {
    final auth = AuthService();
    final token = await auth.getAccessToken();
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay sesión activa de Spotify.')),
      );
      return;
    }
    final url =
        Uri.parse('https://api.spotify.com/v1/playlists/$playlistId/followers');
    final response = await http.delete(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode == 200 || response.statusCode == 204) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Playlist eliminada exitosamente.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar playlist: ${response.body}')),
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

  void _onManagePlaylistsPressed(BuildContext context) async {
    final onRefresh = widget.onRequestPlaylistRefresh;
    try {
      await showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setState) {
            return FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchUserPlaylists(context),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const AlertDialog(
                    title: Text('Tus playlists'),
                    content: SizedBox(
                      height: 100,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return AlertDialog(
                    title: const Text('Tus playlists'),
                    content: Text('Error: \n${snapshot.error}'),
                  );
                }
                final playlists = snapshot.data ?? [];
                if (playlists.isEmpty) {
                  return const AlertDialog(
                    title: Text('Tus playlists'),
                    content: Text('No tienes playlists disponibles'),
                  );
                }
                return AlertDialog(
                  title: const Text('Tus playlists'),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: playlists.length,
                      itemBuilder: (context, index) {
                        final pl = playlists[index];
                        return ListTile(
                          title: Text(pl['name'] ?? ''),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            tooltip: 'Eliminar playlist',
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx2) => AlertDialog(
                                  title: const Text('¿Eliminar playlist?'),
                                  content: Text(
                                      '¿Seguro que deseas eliminar "${pl['name']}"?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(ctx2).pop(false),
                                      child: const Text('Cancelar'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () =>
                                          Navigator.of(ctx2).pop(true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Eliminar'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await _deletePlaylist(context, pl['id']);
                                setState(
                                    () {}); // Recarga la lista tras eliminar
                                if (onRefresh != null) {
                                  onRefresh();
                                }
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            );
          },
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _expandSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.45,
        maxChildSize: 0.85,
        expand: false,
        builder: (context, scrollController) => _ExpandedPlayer(
          scrollController: scrollController,
          onAddToPlaylistPressed: (trackUri) {
            _onAddToPlaylistPressed(context, trackUri);
          },
          onManagePlaylistsPressed: (ctx) {
            _onManagePlaylistsPressed(ctx);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, player, _) {
        final song = player.currentSong;
        if (song == null) return const SizedBox.shrink();
        return Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: _expandSheet,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: _MiniPlayerWidget(
                key: ValueKey(song.id),
                dominantColor: _dominantColor,
                onAddToPlaylistPressed: () {
                  final trackUri = 'spotify:track:${song.id}';
                  _onAddToPlaylistPressed(context, trackUri);
                },
                onManagePlaylistsPressed: () {
                  _onManagePlaylistsPressed(context);
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MiniPlayerWidget extends StatelessWidget {
  final Color? dominantColor;
  final VoidCallback onAddToPlaylistPressed;
  final VoidCallback onManagePlaylistsPressed;

  const _MiniPlayerWidget({
    Key? key,
    this.dominantColor,
    required this.onAddToPlaylistPressed,
    required this.onManagePlaylistsPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, player, _) {
        final song = player.currentSong;
        if (song == null) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: (dominantColor ?? const Color(0xFF151C2C)).withOpacity(0.90),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 2)),
            ],
          ),
          width: double.infinity,
          height: 68,
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(song.albumArtUrl,
                    width: 48, height: 48, fit: BoxFit.cover),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                    Text(song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  player.isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                  color: Colors.white,
                  size: 36,
                ),
                onPressed: () async {
                  if (player.isPlaying) {
                    await player.pause();
                  } else {
                    if (player.currentSong != null &&
                        player.currentSong!.positionMs > 0) {
                      await player.resume(onError: (msg) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(msg)),
                        );
                      });
                    } else {
                      await player.playSongFromList(
                          player.playlist, player.currentIndex, onError: (msg) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(msg)),
                        );
                      });
                    }
                  }
                },
              ),
              IconButton(
                icon:
                    const Icon(Icons.skip_next, color: Colors.white, size: 28),
                onPressed: () async {
                  await player.next();
                },
              ),
              IconButton(
                icon: const Icon(Icons.playlist_add, color: Color(0xFFe0c36a)),
                tooltip: 'Agregar a playlist',
                onPressed: onAddToPlaylistPressed,
              ),
              IconButton(
                icon:
                    const Icon(Icons.playlist_remove, color: Color(0xFFe0c36a)),
                tooltip: 'Gestionar playlists',
                onPressed: onManagePlaylistsPressed,
              ),
            ],
          ),
        );
      },
    );
  }
}

// Helper class to persist state in the playlist modal
class _PlaylistSearchState extends InheritedWidget {
  final TextEditingController controller = TextEditingController();
  List<Song> searchResults = [];
  bool isSearching = false;
  String lastQuery = '';

  _PlaylistSearchState({required Widget child}) : super(child: child);

  void set({List<Song>? searchResults, bool? isSearching, String? lastQuery}) {
    if (searchResults != null) this.searchResults = searchResults;
    if (isSearching != null) this.isSearching = isSearching;
    if (lastQuery != null) this.lastQuery = lastQuery;
  }

  static _PlaylistSearchState of(BuildContext context) {
    final _PlaylistSearchState? result =
        context.dependOnInheritedWidgetOfExactType<_PlaylistSearchState>();
    assert(result != null, 'No _PlaylistSearchState found in context');
    return result!;
  }

  @override
  bool updateShouldNotify(_PlaylistSearchState oldWidget) => true;
}

class _ExpandedPlayer extends StatelessWidget {
  final ScrollController scrollController;
  final void Function(String trackUri) onAddToPlaylistPressed;
  final void Function(BuildContext context) onManagePlaylistsPressed;

  const _ExpandedPlayer({
    required this.scrollController,
    required this.onAddToPlaylistPressed,
    required this.onManagePlaylistsPressed,
  });

  void _showPlaylist(BuildContext context, PlayerProvider player) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.93),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return _PlaylistSearchState(
          child: SafeArea(
            child: StatefulBuilder(
              builder: (context, setState) {
                // Persist state across rebuilds using closures
                final state = _PlaylistSearchState.of(context);
                final searchController = state.controller;
                final searchResults = state.searchResults;
                final isSearching = state.isSearching;
                final lastQuery = state.lastQuery;

                Future<void> doSearch(String query) async {
                  if (query.isEmpty) {
                    state.set(
                        isSearching: false, searchResults: [], lastQuery: '');
                    setState(() {});
                    return;
                  }
                  state.set(isSearching: true);
                  setState(() {});
                  try {
                    final results =
                        await SpotifySearchService.searchTracks(query);
                    state.set(
                        searchResults: results,
                        isSearching: false,
                        lastQuery: query);
                    setState(() {});
                  } catch (_) {
                    state.set(
                        searchResults: [],
                        isSearching: false,
                        lastQuery: query);
                    setState(() {});
                  }
                }

                return Padding(
                  padding: MediaQuery.of(context).viewInsets,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(
                            top: 16, left: 16, right: 16, bottom: 0),
                        child: Row(
                          children: [
                            Text('Lista de reproducción',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      if (player.playlist.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('No hay canciones en la lista.',
                              style: TextStyle(color: Colors.white70)),
                        )
                      else
                        Flexible(
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: player.playlist.length,
                            itemBuilder: (ctx, idx) {
                              final song = player
                                  .playlist[idx]; // Manejo de canción nula

                              return ListTile(
                                leading: song.albumArtUrl.isNotEmpty
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: Image.network(
                                          song.albumArtUrl,
                                          width: 40,
                                          height: 40,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  Container(
                                            width: 40,
                                            height: 40,
                                            color: Colors.grey[900],
                                            child: const Icon(Icons.music_note,
                                                color: Colors.white70),
                                          ),
                                        ),
                                      )
                                    : const Icon(Icons.music_note,
                                        color: Colors.white70),
                                title: Text(
                                  song.title.isNotEmpty
                                      ? song.title
                                      : 'Título desconocido',
                                  style: TextStyle(
                                    color: idx == player.currentIndex
                                        ? const Color(0xFFe0c36a)
                                        : Colors.white,
                                    fontWeight: idx == player.currentIndex
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                                subtitle: Text(
                                  song.artist.isNotEmpty
                                      ? song.artist
                                      : 'Artista desconocido',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                trailing: idx == player.currentIndex
                                    ? const Icon(Icons.play_circle_filled,
                                        color: Color(0xFFe0c36a))
                                    : null,
                                selected: idx == player.currentIndex,
                                onTap: () async {
                                  try {
                                    Navigator.of(context).pop();
                                    await player.playSongFromList(
                                        player.playlist, idx);
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              'Error al reproducir la canción: $e')),
                                    );
                                  }
                                },
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 24),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF18213A),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Consumer<PlayerProvider>(
          builder: (context, player, _) {
            final song = player.currentSong;
            if (song == null) return const SizedBox.shrink();
            return SingleChildScrollView(
              controller: scrollController,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(song.albumArtUrl, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(song.title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 22)),
                  Text(song.artist,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 17)),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.repeat,
                          color: player.repeatSong
                              ? const Color(0xFFe0c36a)
                              : Colors.white,
                          size: 28,
                        ),
                        tooltip:
                            player.repeatSong ? 'Repetir (activo)' : 'Repetir',
                        onPressed: () {
                          player.repeatSong = !player.repeatSong;
                          player.notifyListeners();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(player.repeatSong
                                    ? 'Repetir activado'
                                    : 'Repetir desactivado')),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_previous,
                            color: Colors.white, size: 36),
                        onPressed: () async {
                          await player.previous(onError: (msg) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(msg)),
                            );
                          });
                        },
                      ),
                      IconButton(
                        icon: Icon(
                          player.isPlaying
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_filled,
                          color: Colors.white,
                          size: 56,
                        ),
                        onPressed: () async {
                          if (player.isPlaying) {
                            await player.pause();
                          } else {
                            if (player.currentSong != null &&
                                player.currentSong!.positionMs > 0) {
                              await player.resume(onError: (msg) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(msg)),
                                );
                              });
                            } else {
                              await player.playSongFromList(
                                  player.playlist, player.currentIndex,
                                  onError: (msg) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(msg)),
                                );
                              });
                            }
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_next,
                            color: Colors.white, size: 36),
                        onPressed: () async {
                          await player.next();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.queue_music,
                            color: Colors.white, size: 28),
                        tooltip: 'Ver lista de reproducción',
                        onPressed: () {
                          _showPlaylist(context, player);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.playlist_add,
                            color: Color(0xFFe0c36a), size: 28),
                        tooltip: 'Agregar a playlist',
                        onPressed: () {
                          final player = Provider.of<PlayerProvider>(context,
                              listen: false);
                          final song = player.currentSong;
                          if (song != null) {
                            final trackUri = 'spotify:track:${song.id}';
                            onAddToPlaylistPressed(trackUri);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Slider(
                    value: song.positionMs.toDouble(),
                    min: 0,
                    max: song.durationMs.toDouble(),
                    activeColor: const Color(0xFFe0c36a),
                    onChanged: (value) {
                      if (player.currentSong != null) {
                        player.currentSong!.positionMs = value.toInt();
                        // No llamamos a notifyListeners aquí para evitar reconstrucciones excesivas
                      }
                    },
                    onChangeEnd: (value) async {
                      if (player.currentSong != null) {
                        player.currentSong!.positionMs = value.toInt();
                        player.notifyListeners();
                        await player.seek(value.toInt());
                      }
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                          _formatDuration(
                              Duration(milliseconds: song.positionMs)),
                          style: const TextStyle(color: Colors.white70)),
                      Text(
                          _formatDuration(
                              Duration(milliseconds: song.durationMs)),
                          style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down,
                        color: Colors.white, size: 32),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
