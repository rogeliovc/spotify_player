import 'package:spotify_player/models/task_model.dart';

class MusicRecommender {
  // Rangos de energía para cada tipo de música
  static const Map<String, double> energyRanges = {
    'classical': 0.2,
    'lofi': 0.4,
    'electronic': 0.7,
    'jazz': 0.5,
    'rock': 0.8,
  };

  // Rangos de valencia para cada tipo de música
  static const Map<String, double> valenceRanges = {
    'classical': 0.3,
    'lofi': 0.6,
    'electronic': 0.8,
    'jazz': 0.7,
    'rock': 0.9,
  };

  // Rangos de tempo para cada tipo de música
  static const Map<String, int> tempoRanges = {
    'classical': 70,
    'lofi': 90,
    'electronic': 120,
    'jazz': 100,
    'rock': 130,
  };

  // Tipos de tareas y sus preferencias musicales
  static const Map<String, List<String>> taskPreferences = {
    'Investigación': ['classical', 'lofi'],
    'Estudio': ['classical', 'lofi', 'jazz'],
    'Ejercicio': ['electronic', 'rock'],
    'Viaje': ['electronic', 'jazz'],
    'Trabajo': ['lofi', 'jazz'],
  };

  List<String> recommendMusic(Task task) {
    // 1. Obtener las preferencias basadas en el tipo de tarea
    final taskPreferences = MusicRecommender.taskPreferences[task.taskType] ?? [];
    
    // 2. Filtrar por géneros seleccionados
    final selectedGenres = [];
    if (task.classical > 0) selectedGenres.add('classical');
    if (task.lofi > 0) selectedGenres.add('lofi');
    if (task.electronic > 0) selectedGenres.add('electronic');
    if (task.jazz > 0) selectedGenres.add('jazz');
    if (task.rock > 0) selectedGenres.add('rock');

    // 3. Calcular puntuación para cada género
    final scores = <String, double>{};
    
    for (final genre in taskPreferences) {
      if (!selectedGenres.contains(genre)) continue;
      
      // Calcular puntuación basada en energía
      final energyScore = (1 - (task.energyLevel - energyRanges[genre]!).abs()) * 0.4;
      
      // Calcular puntuación basada en valencia
      final valenceScore = (1 - (task.valence - valenceRanges[genre]!).abs()) * 0.3;
      
      // Calcular puntuación basada en tempo
      final tempoScore = (1 - ((task.tempo - tempoRanges[genre]!).abs() / 100)) * 0.3;
      
      scores[genre] = energyScore + valenceScore + tempoScore;
    }

    // 4. Ordenar géneros por puntuación
    final sortedGenres = scores.entries
        .toList()
        .where((entry) => entry.value > 0)
        .map((entry) => entry.key)
        .toList();

    return sortedGenres;
  }
}
