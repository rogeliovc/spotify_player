import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_model.dart';
import 'task_details.dart';

import '../services/task_storage.dart';

class TaskProvider with ChangeNotifier {
  final TaskStorage _storage = TaskStorage();
  final List<Task> _tasks = [];
  bool _loading = true;

  List<Task> get tasks => List.unmodifiable(_tasks);
  bool get loading => _loading;

  TaskProvider() {
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    _loading = true;
    notifyListeners();
    await Future.delayed(
        const Duration(milliseconds: 400)); // Animación de carga inicial
    final tasks = await _storage.loadTasks();
    _tasks.clear();
    _tasks.addAll(tasks);
    _loading = false;
    notifyListeners();
  }

  Future<void> addTask(Task task) async {
    _tasks.add(Task(
      title: task.title,
      description: task.description,
      dueDate: task.dueDate,
      taskType: task.taskType,
      classical: task.classical ?? 0.0,
      lofi: task.lofi ?? 0.0,
      electronic: task.electronic ?? 0.0,
      jazz: task.jazz ?? 0.0,
      rock: task.rock ?? 0.0,
      energyLevel: task.energyLevel ?? 0.5,
      valence: task.valence ?? 0.5,
      tempo: task.tempo ?? 120,
      completed: task.completed,
    ));
    await _storage.saveTasks(_tasks);
    notifyListeners();
  }

  Future<void> toggleTaskCompleted(int index) async {
    final t = _tasks[index];
    _tasks[index] = Task(
      title: t.title,
      description: t.description,
      dueDate: t.dueDate,
      taskType: t.taskType,
      classical: t.classical,
      lofi: t.lofi,
      electronic: t.electronic,
      jazz: t.jazz,
      rock: t.rock,
      energyLevel: t.energyLevel,
      valence: t.valence,
      tempo: t.tempo,
      completed: !t.completed,
    );
    notifyListeners();
  }

  Future<void> removeCompletedTasks() async {
    _tasks.removeWhere((t) => t.completed);
    await _storage.saveTasks(_tasks);
    notifyListeners();
  }
}

class TaskManagerScreen extends StatelessWidget {
  const TaskManagerScreen({Key? key}) : super(key: key);

  Future<void> _confirmCompleteTask(BuildContext context, int i,
      TaskProvider taskProvider, bool completed) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            color: const Color(0xFF182B45),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                completed ? Icons.undo : Icons.check_circle,
                color: completed ? Colors.orange : Colors.green,
                size: 48,
              ),
              const SizedBox(height: 18),
              Text(
                completed
                    ? '¿Quieres marcar esta tarea como pendiente?'
                    : '¿Seguro que quieres marcar esta tarea como completada?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancelar'),
                  ),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            completed ? Colors.orange : Colors.green,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: Text(
                        completed ? 'Marcar como pendiente' : 'Completar',
                        style: TextStyle(
                          color: completed ? Colors.black : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
    if (result == true) {
      await taskProvider.toggleTaskCompleted(i);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, _) {
        return Stack(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: taskProvider.loading
                  ? const Center(
                      key: ValueKey('loading'),
                      child: SizedBox(
                        width: 60,
                        height: 60,
                        child: CircularProgressIndicator(
                          strokeWidth: 6,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      key: const ValueKey('content'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Tareas',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          if (taskProvider.tasks.isEmpty)
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 24),
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(220),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Center(
                                child: Text(
                                  'No hay tareas pendientes',
                                  style: TextStyle(
                                      color: Colors.black54, fontSize: 16),
                                ),
                              ),
                            ),
                          ...taskProvider.tasks.asMap().entries.map((entry) {
                            final i = entry.key;
                            final t = entry.value;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 18),
                              decoration: BoxDecoration(
                                color: const Color(0xFF052B44),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                title: Text(
                                  t.title,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 17),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Hasta: ${_dueDateText(t.dueDate)}',
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 13),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      t.description,
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 14),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 7),
                                    Row(
                                      children: [
                                        _taskTypeChip(t.taskType),
                                        const SizedBox(width: 6),
                                        _energyLevelChip(t.energyLevel),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        t.completed
                                            ? Icons.check_circle
                                            : Icons.radio_button_unchecked,
                                        color: t.completed
                                            ? Colors.green
                                            : Colors.white38,
                                      ),
                                      onPressed: () => _confirmCompleteTask(
                                          context,
                                          i,
                                          taskProvider,
                                          t.completed),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.info_outline,
                                          color: Colors.white70),
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                TaskDetailsScreen(task: t),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                          const SizedBox(height: 70),
                        ],
                      ),
                    ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: FloatingActionButton(
                backgroundColor: const Color(0xFF4CB3F4),
                child: const Icon(Icons.add, color: Colors.white),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TaskAdder()),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  String _dueDateText(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _taskTypeChip(String taskType) {
    Color color;
    switch (taskType) {
      case 'study':
        color = Colors.blue;
        break;
      case 'exercise':
        color = Colors.green;
        break;
      case 'relax':
        color = Colors.purple;
        break;
      case 'creative':
        color = Colors.orange;
        break;
      case 'work':
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
      child: Text(taskType,
          style: TextStyle(
              color: color, fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }

  Widget _energyLevelChip(double energyLevel) {
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
}

class TaskAdder extends StatefulWidget {
  const TaskAdder({super.key});

  @override
  State<TaskAdder> createState() => _TaskAdderState();
}

class _TaskAdderState extends State<TaskAdder> {
  final _formKey = GlobalKey<FormState>();
  String _title = '';
  String _description = '';
  DateTime? _dueDate;
  String _taskType = 'Investigación';
  bool _classical = false;
  bool _lofi = false;
  bool _electronic = false;
  bool _jazz = false;
  bool _rock = false;
  bool _isFormValid = false;
  final double _energyLevel = 0.5;
  double _valence = 0.5;
  final int _tempo = 120;

  void _createTask() {
    if (_dueDate == null) return;

    context.read<TaskProvider>().addTask(
          Task(
            title: _title,
            description: _description,
            dueDate: _dueDate!,
            taskType: _taskType,
            classical: _classical ? 1.0 : 0.0,
            lofi: _lofi ? 1.0 : 0.0,
            electronic: _electronic ? 1.0 : 0.0,
            jazz: _jazz ? 1.0 : 0.0,
            rock: _rock ? 1.0 : 0.0,
            energyLevel: _energyLevel,
            valence: _valence,
            tempo: _tempo,
          ),
        );
    Navigator.pop(context);
  }

  void _validateForm() {
    setState(() {
      _isFormValid = _title.isNotEmpty && _dueDate != null;
    });
  }

  final List<String> _taskTypes = [
    'Investigación',
    'Estudio',
    'Ejercicio',
    'Viaje',
    'Trabajo'
  ];

  String _dueDateText(DateTime? date) {
    if (date == null) return 'Sin fecha';
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildGenreChip(
      String genre, bool isSelected, Function(bool) onChanged) {
    return ChoiceChip(
      label: Text(
        genre,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white70,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedColor: Colors.blue,
      backgroundColor: Colors.transparent,
      onSelected: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1928),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Nueva tarea',
            style: TextStyle(fontFamily: 'Serif', color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('¿Qué harás?...',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              TextFormField(
                decoration: const InputDecoration(
                  hintText: 'Agrega una descripción...',
                  hintStyle: TextStyle(color: Colors.white54),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white38)),
                  focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white)),
                ),
                style: const TextStyle(color: Colors.white),
                onChanged: (value) {
                  _title = value;
                  _validateForm();
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa un título';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  hintText: 'Agrega una descripción...',
                  hintStyle: TextStyle(color: Colors.white54),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white38)),
                  focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white)),
                ),
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                onChanged: (value) => _description = value,
              ),
              const SizedBox(height: 16),
              const Text('¿Qué tipo de tarea es?',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonFormField<String>(
                  value: _taskType,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                  ),
                  items: _taskTypes.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(
                        type,
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _taskType = value!);
                    _validateForm();
                  },
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  final dueDate = await showDatePicker(
                    context: context,
                    initialDate: _dueDate ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (dueDate != null) {
                    setState(() => _dueDate = dueDate);
                    _validateForm();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Fecha límite: ${_dueDateText(_dueDate)}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(height: 16),
              const Text('¿Qué tipo de música prefieres?',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Wrap(
                  spacing: 8,
                  children: [
                    _buildGenreChip(
                        'Clásica',
                        _classical,
                        (value) => setState(() {
                              _classical = value;
                              _validateForm();
                            })),
                    _buildGenreChip(
                        'Lo-fi',
                        _lofi,
                        (value) => setState(() {
                              _lofi = value;
                              _validateForm();
                            })),
                    _buildGenreChip(
                        'Electrónica',
                        _electronic,
                        (value) => setState(() {
                              _electronic = value;
                              _validateForm();
                            })),
                    _buildGenreChip(
                        'Jazz',
                        _jazz,
                        (value) => setState(() {
                              _jazz = value;
                              _validateForm();
                            })),
                    _buildGenreChip(
                        'Rock',
                        _rock,
                        (value) => setState(() {
                              _rock = value;
                              _validateForm();
                            })),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Selecciona los géneros musicales que prefieres para tu tarea',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              const Text('¿Qué estado de ánimo prefieres?',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Slider(
                      value: _valence,
                      min: 0,
                      max: 1,
                      divisions: 10,
                      label: '${(_valence * 100).round()}%',
                      activeColor: Colors.blue,
                      inactiveColor: Colors.white38,
                      onChanged: (value) {
                        setState(() => _valence = value);
                      },
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Triste',
                            style: TextStyle(color: Colors.white70)),
                        Text('${(_valence * 100).round()}%',
                            style: const TextStyle(color: Colors.white)),
                        const Text('Feliz',
                            style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isFormValid ? _createTask : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isFormValid ? Colors.blue : Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Agregar Tarea',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
