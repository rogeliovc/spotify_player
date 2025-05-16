import 'dart:math';
import 'package:spotify_player/models/task_model.dart';

class MusicRecommender {
  static const Map<String, List<String>> taskPreferences = {
    'Investigación': ['classical', 'lofi'],
    'Estudio': ['classical', 'lofi', 'jazz'],
    'Ejercicio': ['electronic', 'rock', 'pop'],
    'Trabajo': ['lofi', 'jazz', 'pop'],
    'Salud': ['classical', 'lofi', 'pop'],
    'Creatividad': ['jazz', 'electronic', 'pop'],
    'Eventos': ['pop', 'rock', 'electronic'],
    'Organización': ['lofi', 'classical', 'pop'],
  };


  final Random _random = Random();

  Map<String, double> _calculateScores(Task task) {
    final basePrefs = taskPreferences[task.taskType] ?? [];
    final userPrefs = <String>[];
    if (task.classical > 0) userPrefs.add('classical');
    if (task.lofi > 0) userPrefs.add('lofi');
    if (task.electronic > 0) userPrefs.add('electronic');
    if (task.jazz > 0) userPrefs.add('jazz');
    if (task.rock > 0) userPrefs.add('rock');
    if (task.pop > 0) userPrefs.add('pop'); // agregado

    final allGenres = {
      'classical', 'electronic', 'jazz', 'rock', 'pop'
    };

    final scores = <String, double>{};

    for (final genre in allGenres) {
      double score = 1.0;
      if (basePrefs.contains(genre)) score *= 2.3; // preferencia por tarea
      if (userPrefs.contains(genre)) score *= 2.5; // boost por preferencia
      scores[genre] = score;
    }

    return scores;
  }
  List<String> _weightedRandomSelection(Map<String, double> scores, int count) {
    final results = <String>[];
    final genres = scores.keys.toList();
    final weights = scores.values.toList();
    final totalWeight = weights.fold(0.0, (sum, w) => sum + w);

    for (int i = 0; i < count; i++) {
      double r = _random.nextDouble() * totalWeight;
      double accum = 0;
      for (int j = 0; j < genres.length; j++) {
        accum += weights[j];
        if (r <= accum) {
          results.add(genres[j]);
          break;
        }
      }
    }

    return results;
  }

  List<String> recommendMusic(Task task, {int recommendationsCount = 3}) {
    final scores = _calculateScores(task);
    if (scores.isEmpty) return [];

    return _weightedRandomSelection(scores, recommendationsCount);
  }
}
