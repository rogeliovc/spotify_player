import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../services/music_recommender.dart';

class TaskDetailsScreen extends StatelessWidget {
  final Task task;

  const TaskDetailsScreen({Key? key, required this.task}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1928),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Detalles de Tarea',
            style: TextStyle(fontFamily: 'Serif', color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
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
                const SizedBox(width: 8),
                _buildEnergyLevelChip(task.energyLevel),
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
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Estado de ánimo: ${(task.valence * 100).round()}%',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final recommendations = MusicRecommender().recommendMusic(task);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text('Recomendaciones: ${recommendations.join(', ')}'),
                    backgroundColor: Colors.blue,
                  ),
                );
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
      case 'Viaje':
        color = Colors.purple;
        break;
      case 'Trabajo':
        color = Colors.teal;
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
      child: Text(
        taskType,
        style:
            TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }

  Widget _buildEnergyLevelChip(double energyLevel) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.15),
        border: Border.all(color: Colors.green, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Energía: ${(energyLevel * 100).round()}%',
        style: const TextStyle(
            color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13),
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
