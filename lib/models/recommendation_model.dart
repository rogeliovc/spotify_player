class Recommendation {
  final String taskType;
  final Map<String, double> genreProbabilities;
  final List<String> recommendedGenres;
  final double confidenceScore;

  Recommendation({
    required this.taskType,
    required this.genreProbabilities,
    required this.recommendedGenres,
    required this.confidenceScore,
  });

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    return Recommendation(
      taskType: json['task_type'],
      genreProbabilities: Map<String, double>.from(json['genre_probabilities']),
      recommendedGenres: List<String>.from(json['recommended_genres']),
      confidenceScore: json['confidence_score'].toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'task_type': taskType,
      'genre_probabilities': genreProbabilities,
      'recommended_genres': recommendedGenres,
      'confidence_score': confidenceScore,
    };
  }
}
