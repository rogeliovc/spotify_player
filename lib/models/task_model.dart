class Task {
  final String title;
  final String description;
  final DateTime dueDate;
  final String taskType;  // Tipo de tarea (study, exercise, etc.)
  final double classical;
  final double lofi;
  final double electronic;
  final double jazz;
  final double rock;
  final double energyLevel;
  final double valence;
  final int tempo;
  final bool completed;

  Task({
    required this.title,
    required this.description,
    required this.dueDate,
    required this.taskType,
    required this.classical,
    required this.lofi,
    required this.electronic,
    required this.jazz,
    required this.rock,
    required this.energyLevel,
    required this.valence,
    required this.tempo,
    this.completed = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'dueDate': dueDate.toIso8601String(),
      'taskType': taskType,
      'classical': classical,
      'lofi': lofi,
      'electronic': electronic,
      'jazz': jazz,
      'rock': rock,
      'energyLevel': energyLevel,
      'valence': valence,
      'tempo': tempo,
      'completed': completed,
    };
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      title: json['title'],
      description: json['description'],
      dueDate: DateTime.parse(json['dueDate']),
      taskType: json['taskType'],
      classical: json['classical'],
      lofi: json['lofi'],
      electronic: json['electronic'],
      jazz: json['jazz'],
      rock: json['rock'],
      energyLevel: json['energyLevel'],
      valence: json['valence'],
      tempo: json['tempo'],
      completed: json['completed'],
    );
  }
}
