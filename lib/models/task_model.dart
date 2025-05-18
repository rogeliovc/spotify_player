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
  final double pop;
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
    required this.pop,
    this.completed = false,
  });

  Task copyWith({
    String? title,
    String? description,
    DateTime? dueDate,
    String? taskType,
    double? classical,
    double? lofi,
    double? electronic,
    double? jazz,
    double? rock,
    double? pop,
    bool? completed,
  }) {
    return Task(
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      taskType: taskType ?? this.taskType,
      classical: classical ?? this.classical,
      lofi: lofi ?? this.lofi,
      electronic: electronic ?? this.electronic,
      jazz: jazz ?? this.jazz,
      rock: rock ?? this.rock,
      pop: pop ?? this.pop,
      completed: completed ?? this.completed,
    );
  }

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
      'pop': pop,
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
      pop: json['pop'],
      completed: json['completed'],
    );
  }
}
