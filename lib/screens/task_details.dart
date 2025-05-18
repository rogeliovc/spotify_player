import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_model.dart';
import '../services/auth_service.dart';
import '../services/music_recommender.dart';
import '../services/spotify_service.dart';
import 'main_player_screen.dart';
import 'edit_task.dart';
import '../screens/task_manager.dart'; // Importar TaskProvider

class TaskDetailsScreen extends StatefulWidget{
  final Task task;

  const TaskDetailsScreen({Key? key, required this.task}) : super(key: key);

  @override
  _TaskDetailsScreenState createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  late Task task;

  @override
  void initState() {
    super.initState();
    task = widget.task;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true, // Permite que la pantalla se cierre
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (!didPop) {
          Navigator.pop(context, task); // Devuelve la tarea actualizada solo si no se hizo pop automático
        }
      },
    child: Scaffold(
      backgroundColor: const Color(0xFF0E1928),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final updatedTask = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditTaskScreen(task: task),
                ),
              );

              if (updatedTask != null && updatedTask is Task) {
                setState(() {
                  task = updatedTask; // Actualiza la tarea local
                });
                
                // Actualiza el TaskProvider
                final taskProvider = Provider.of<TaskProvider>(context, listen: false);
                final index = taskProvider.tasks.indexWhere((t) => t.title == task.title);
                if (index != -1) {
                  taskProvider.updateTask(index, updatedTask);
                }
              }
            },
          ),
        ],
        title: const Text('Detalles de Tarea',
            style: TextStyle(fontFamily: 'Serif', color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
      children: [
        Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task.title,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text(
              task.description,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildTaskTypeChip(task.taskType),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Fecha límite: ${_dueDateText(task.dueDate)}',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            const Text(
              'Preferencias musicales:',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (task.classical > 0) _buildGenreChip('Clásica', true),
                if (task.lofi > 0) _buildGenreChip('Lo-fi', true),
                if (task.electronic > 0) _buildGenreChip('Electrónica', true),
                if (task.jazz > 0) _buildGenreChip('Jazz', true),
                if (task.rock > 0) _buildGenreChip('Rock', true),
                if (task.pop > 0) _buildGenreChip('Pop', true),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
                onPressed: () async {
                  try {
                    final authService = AuthService();
                    final token = await authService.getAccessToken();
                    final recommender = SpotifyService(authService);

                    // Obtener géneros recomendados directamente
                    final selectedGenres = MusicRecommender().recommendMusic(task);

                    final songs = await recommender.fetchSongsByGenre(selectedGenres, token!);

                    // Mostrar en BottomSheet
                    if (context.mounted) {
                      showModalBottomSheet(
                        context: context,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        builder: (context) {
                          return ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              const Text(
                                'Recomendaciones de Spotify',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 12),
                              ...songs.map((song) => ListTile(
                                leading: Image.network(song['image']!, width: 50, height: 50, fit: BoxFit.cover),
                                title: Text(song['name']!),
                                subtitle: Text(song['artist']!),
                                trailing: const Icon(Icons.play_arrow),
                                onTap: () {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(
      builder: (_) => MainPlayerScreen(
        initialTab: 0,
        songData: {
          'id': song['id'],
          'title': song['name'],
          'artist': song['artist'],
          'album': song['album'] ?? '',
          'albumArtUrl': song['image'] ?? '',
          'durationMs': song['duration_ms'] ?? 180000,
        },
      ),
    ),
    (route) => false,
  );
},
                              )),
                            ],
                          );
                        },
                      );
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error al obtener recomendaciones: $e'),
                        backgroundColor: Colors.deepOrangeAccent,
                      ),
                    );
                  }
                },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Ver Recomendaciones',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    ],
      ),
    ),
    );
  }

  String _dueDateText(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildTaskTypeChip(String taskType) {
    Color color;
    switch (taskType) {
      case 'Investigación':
        color = Colors.blue;
        break;
      case 'Estudio':
        color = Colors.green;
        break;
      case 'Ejercicio':
        color = Colors.orange;
        break;
      case 'Trabajo':
        color = Colors.teal;
        break;
      case 'Salud':
        color = Colors.pink;
        break;
      case 'Creatividad':
        color = Colors.purple;
        break;
      case 'Eventos':
        color = Colors.redAccent;
        break;
      case 'Organización':
        color = Colors.indigo;
        break;
      default:
        color = Color(0xFF90A4AE);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        border: Border.all(color: color, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        taskType,
        style:
            TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }

  Widget _buildGenreChip(String genre, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.15),
        border: Border.all(color: Colors.blue, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        genre,
        style: const TextStyle(
            color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }
}
