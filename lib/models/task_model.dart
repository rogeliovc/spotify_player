class Task {
  final String title;
  final String description;
  final DateTime dueDate;
  final String priority; // Ej: "Volumen al 100", "Coro pegajoso", "Beat suave"
  final String label;    // Ej: "Investigación", "Estudio", etc.
  final bool completed;

  Task({
    required this.title,
    required this.description,
    required this.dueDate,
    required this.priority,
    required this.label,
    this.completed = false,
  });
}
