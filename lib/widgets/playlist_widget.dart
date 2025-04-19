import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/song_model.dart';
import '../providers/player_provider.dart';

class PlaylistWidget extends StatelessWidget {
  final List<Song> songs;
  final String title;

  const PlaylistWidget({
    super.key,
    required this.songs,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: ListView.builder(
        itemCount: songs.length,
        itemBuilder: (context, index) {
          final song = songs[index];
          final provider = Provider.of<PlayerProvider>(context);
          final isCurrent = provider.currentSong?.id == song.id;

          return ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: song.imageUrl,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                placeholder: (context, url) => const CircularProgressIndicator(),
                errorWidget: (context, url, error) => const Icon(Icons.music_note),
              ),
            ),
            title: Text(song.title),
            subtitle: Text(song.artist),
            trailing: isCurrent
                ? const Icon(Icons.play_circle, color: Colors.green)
                : null,
            onTap: () {
              provider.setCurrentSong(song);
            },
          );
        },
      ),
    );
  }
}
