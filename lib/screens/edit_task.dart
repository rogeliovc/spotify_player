import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spotify_player/screens/task_manager.dart';
import '../models/task_model.dart';
import '../services/notification_service.dart';

class EditTaskScreen extends StatefulWidget {
  final Task task;

  const EditTaskScreen({Key? key, required this.task}) : super(key: key);

  @override
  State<EditTaskScreen> createState() => _EditTaskScreenState();
}

class _EditTaskScreenState extends State<EditTaskScreen> {
  final _formKey = GlobalKey<FormState>();

  late String _title;
  late String _description;
  late String _taskType;
  late TextEditingController _customTaskTypeController;
  String? _customTaskType;
  DateTime? _dueDate;

  // Géneros musicales
  late bool _classical;
  late bool _lofi;
  late bool _electronic;
  late bool _jazz;
  late bool _rock;
  late bool _pop;

  bool _isFormValid = true;

  @override
  void initState() {
    super.initState();
    final task = widget.task;

    // Inicializa con valores de la tarea
    _title = task.title;
    _description = task.description;
    _dueDate = task.dueDate;

    // Verifica si el tipo está en la lista
    if (_taskTypes.contains(task.taskType)) {
      _taskType = task.taskType;
    } else {
      _taskType = 'Otra';
      _customTaskType = task.taskType; // Aquí se guarda el tipo original
    }

    _customTaskTypeController = TextEditingController(text: _customTaskType);

    _classical = task.classical > 0;
    _lofi = task.lofi > 0;
    _electronic = task.electronic > 0;
    _jazz = task.jazz > 0;
    _rock = task.rock > 0;
    _pop = task.pop > 0;
  }

  void _validateForm() {
    final isValid = _title.isNotEmpty;
    setState(() {
      _isFormValid = isValid;
    });
  }

  void _updateTask() {
    if (_formKey.currentState!.validate()) {
      String finalTaskType = _taskType == 'Otra' ? (_customTaskType ?? 'Otra') : _taskType;

      final updatedTask = widget.task.copyWith(
        title: _title,
        description: _description,
        taskType: finalTaskType,
        dueDate: _dueDate,
        classical: _classical ? 1 : 0,
        lofi: _lofi ? 1 : 0,
        electronic: _electronic ? 1 : 0,
        jazz: _jazz ? 1 : 0,
        rock: _rock ? 1 : 0,
        pop: _pop ? 1 : 0,
      );

      // Luego navegas atrás o actualizas el estado global
      Navigator.pop(context, updatedTask);
    }
  }

  void _eliminarTareasCompletadas(BuildContext context) {
    Provider.of<TaskProvider>(context, listen: false).removeCompletedTasks();
  }

  void _createTask() {
    if (_dueDate == null) return;
    String finalTaskType = _taskType == 'Otra' ? (_customTaskType ?? 'Otra') : _taskType;

    final newTask = Task(
      title: _title,
      description: _description,
      dueDate: _dueDate!,
      taskType: finalTaskType,
      classical: _classical ? 1.0 : 0.0,
      lofi: _lofi ? 1.0 : 0.0,
      electronic: _electronic ? 1.0 : 0.0,
      jazz: _jazz ? 1.0 : 0.0,
      rock: _rock ? 1.0 : 0.0,
      pop: _pop ? 1.0 : 0.0,
    );
    context.read<TaskProvider>().addTask(newTask);
    // Notificaciones al crear tarea
    final notificationService = NotificationService();
    final id = DateTime.now().millisecondsSinceEpoch.remainder(100000);
    notificationService.showTaskCreatedNotification(
      id: id,
      title: newTask.title,
      description: newTask.description,
      dueDate: newTask.dueDate,
    );
    notificationService.scheduleDailyReminder(
      id: id,
      title: newTask.title,
      description: newTask.description,
      dueDate: newTask.dueDate,
    );
    notificationService.schedule12HoursBefore(
      id: id,
      title: newTask.title,
      description: newTask.description,
      dueDate: newTask.dueDate,
    );
    Navigator.of(context).pop();
  }


  final List<String> _taskTypes = [ //uwu
    'Investigación',
    'Estudio',
    'Ejercicio',
    'Trabajo',
    'Salud',
    'Creatividad',
    'Eventos',
    'Organización',
    'Otra'
  ];

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

  String _dueDateText(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    Consumer<TaskProvider>(
      builder: (context, taskProvider, child) {
        return ListView.builder(
          itemCount: taskProvider.tasks.length,
          itemBuilder: (context, index) {
            final task = taskProvider.tasks[index];
            return ListTile(
              title: Text(task.title),
              subtitle: Text(task.description),
              trailing: Checkbox(
                value: task.completed,
                onChanged: (bool? value) {
                  taskProvider.toggleTaskCompleted(index);
                },
              ),
            );
          },
        );
      },
    );
    return Scaffold(
      backgroundColor: const Color(0xFF0E1928),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Editar tarea',
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
                initialValue: _title,
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
                initialValue: _description,
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
                    setState(() {
                      _taskType = value!;
                      if (_taskType != 'Otra') _customTaskType = null;
                    });
                    _validateForm();
                  },
                ),
              ),
              if (_taskType == 'Otra') ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _customTaskTypeController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Especifica tu tipo de tarea',
                    hintStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white12,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() => _customTaskType = value);
                  },
                ),
              ]
,
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  final dueDate = await showDatePicker(
                    context: context,
                    initialDate: _dueDate ?? DateTime.now(),
                    firstDate: _dueDate != null && _dueDate!.isBefore(DateTime.now())
                        ? _dueDate!
                        : DateTime.now(),
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
                  'Fecha límite: ${_dueDateText(_dueDate!)}',
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
                    _buildGenreChip(
                        'Pop',
                        _pop,
                            (value) => setState(() {
                          _pop = value;
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
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isFormValid ? _updateTask : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isFormValid ? Colors.blue : Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Guardar Cambios',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}