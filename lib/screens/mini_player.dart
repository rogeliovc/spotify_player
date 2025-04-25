import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../models/song_model.dart';

class MiniPlayer extends StatefulWidget {
  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  bool _isExpanded = false;

  void _expandSheet() {
    setState(() {
      _isExpanded = true;
    });
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.6,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => _ExpandedPlayer(scrollController: scrollController),
      ),
    ).whenComplete(() {
      setState(() {
        _isExpanded = false;
      });
    });
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
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF151C2C).withOpacity(0.95),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 2)),
                ],
              ),
              width: double.infinity,
              height: 68,
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(song.albumArtUrl, width: 48, height: 48, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(player.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 32),
                    onPressed: () async {
                      if (player.isPlaying) {
                        await player.pause();
                      } else {
                        // Si la canción es la misma y está pausada, reanuda
                        if (player.currentSong?.id == song.id && song.positionMs > 0) {
                          await player.resume(onError: (msg) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(msg)),
                            );
                          });
                        } else {
                          await player.playSong(song, onError: (msg) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(msg)),
                            );
                          });
                        }
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next, color: Colors.white, size: 28),
                    onPressed: () async {
                      await player.next(onError: (msg) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(msg)),
                        );
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ExpandedPlayer extends StatelessWidget {
  final ScrollController scrollController;
  const _ExpandedPlayer({required this.scrollController});

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
            final duration = song.durationMs;
            final position = song.positionMs;
            final volume = player.volume;
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
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 12)],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(song.albumArtUrl, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(song.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
                  const SizedBox(height: 8),
                  Text(song.artist, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.skip_previous, color: Colors.white, size: 36),
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
                          player.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                          color: Colors.white,
                          size: 56,
                        ),
                        onPressed: () async {
                          if (player.isPlaying) {
                            await player.pause();
                          } else {
                            await player.playSong(song, onError: (msg) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(msg)),
                              );
                            });
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_next, color: Colors.white, size: 36),
                        onPressed: () async {
                          await player.next();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Barra de progreso y seek
                  Slider(
                    value: position.toDouble(),
                    min: 0,
                    max: duration.toDouble(),
                    activeColor: const Color(0xFFe0c36a),
                    onChanged: (value) {
                      // Actualiza la posición local para feedback inmediato
                      if (player.currentSong != null) {
                        player.currentSong!.positionMs = value.toInt();
                        player.notifyListeners();
                      }
                    },
                    onChangeEnd: (value) async {
                      await player.seek(value.toInt());
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatDuration(Duration(milliseconds: position)), style: const TextStyle(color: Colors.white70)),
                      Text(_formatDuration(Duration(milliseconds: duration)), style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Indicador de volumen
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.volume_up, color: Colors.white.withOpacity(0.7)),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'El volumen se controla con los botones del dispositivo',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Botón para cerrar
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 32),
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
