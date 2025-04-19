import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_model.dart';

class TaskProvider with ChangeNotifier {
  final List<Task> _tasks = [];

  List<Task> get tasks => List.unmodifiable(_tasks);

  void addTask(Task task) {
    _tasks.add(task);
    notifyListeners();
  }

  void toggleTaskCompleted(int index) {
    final t = _tasks[index];
    _tasks[index] = Task(
      title: t.title,
      description: t.description,
      dueDate: t.dueDate,
      priority: t.priority,
      label: t.label,
      completed: !t.completed,
    );
    notifyListeners();
  }
}

class TaskManagerScreen extends StatelessWidget {
  const TaskManagerScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, _) {
        return Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tareas', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
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
                        style: TextStyle(color: Colors.black54, fontSize: 16),
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
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hasta: ${_dueDateText(t.dueDate)}',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            t.description,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 7),
                          Row(
                            children: [
                              _priorityChip(t.priority),
                              const SizedBox(width: 6),
                              _labelChip(t.label),
                            ],
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: Icon(
                          t.completed ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: t.completed ? Colors.green : Colors.white38,
                        ),
                        onPressed: () => taskProvider.toggleTaskCompleted(i),
                      ),
                    ),
                  );
                }).toList(),
                const SizedBox(height: 70),
              ],
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
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'Hoy';
    } else if (date.isBefore(now)) {
      return 'Ayer';
    } else if (date.difference(now).inDays == 1) {
      return 'Mañana';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Widget _priorityChip(String priority) {
    Color color;
    switch (priority) {
      case 'Urgente':
        color = Colors.red;
        break;
      case 'Alta':
        color = Colors.orange;
        break;
      case 'Media':
        color = Colors.yellow[800]!;
        break;
      case 'Baja':
        color = Colors.green[700]!;
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
      child: Text(priority, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }

  Widget _labelChip(String label) {
    Color color;
    Color textColor = Colors.black;
    switch (label) {
      case 'Investigación':
        color = Colors.blue[900]!;
        textColor = Colors.white;
        break;
      case 'Estudio':
        color = Colors.orange[300]!;
        break;
      case 'Ejercicio':
        color = Colors.green[300]!;
        break;
      case 'Viaje':
        color = Colors.purple[200]!;
        break;
      case 'Trabajo':
        color = Colors.teal[200]!;
        break;
      case 'Personal':
        color = Colors.pink[200]!;
        break;
      case 'Salud':
        color = Colors.red[200]!;
        break;
      case 'Finanzas':
        color = Colors.amber[300]!;
        break;
      case 'Otro':
        color = Colors.grey[400]!;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        border: Border.all(color: color, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }
}

// Pantalla para agregar tarea
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
  String _priority = 'Urgente';
  String _label = 'Investigación';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1928),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Nueva tarea', style: TextStyle(fontFamily: 'Serif', color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('¿Qué harás?...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              TextFormField(
                decoration: const InputDecoration(
                  hintText: 'Agrega una descripción...',
                  hintStyle: TextStyle(color: Colors.white54),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white38)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                ),
                style: const TextStyle(color: Colors.white),
                validator: (v) => v == null || v.isEmpty ? 'Campo requerido' : null,
                onSaved: (v) => _title = v ?? '',
              ),
              const SizedBox(height: 12),
              const Text('Fecha límite', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now().subtract(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setState(() => _dueDate = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    _dueDate == null ? 'dd/mm/aaaa' : '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}',
                    style: TextStyle(color: _dueDate == null ? Colors.white54 : Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Asignar prioridad', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Urgente'),
                    selected: _priority == 'Urgente',
                    selectedColor: Colors.red[700],
                    onSelected: (_) => setState(() => _priority = 'Urgente'),
                  ),
                  ChoiceChip(
                    label: const Text('Alta'),
                    selected: _priority == 'Alta',
                    selectedColor: Colors.orange[700],
                    onSelected: (_) => setState(() => _priority = 'Alta'),
                  ),
                  ChoiceChip(
                    label: const Text('Media'),
                    selected: _priority == 'Media',
                    selectedColor: Colors.yellow[700],
                    onSelected: (_) => setState(() => _priority = 'Media'),
                  ),
                  ChoiceChip(
                    label: const Text('Baja'),
                    selected: _priority == 'Baja',
                    selectedColor: Colors.green[700],
                    onSelected: (_) => setState(() => _priority = 'Baja'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Etiqueta', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Investigación', style: TextStyle(color: Colors.black)),
                    selected: _label == 'Investigación',
                    selectedColor: Colors.blue[900],
                    backgroundColor: Colors.white,
                    onSelected: (_) => setState(() => _label = 'Investigación'),
                  ),
                  ChoiceChip(
                    label: const Text('Estudio'),
                    selected: _label == 'Estudio',
                    selectedColor: Colors.orange[300],
                    labelStyle: const TextStyle(color: Colors.black),
                    onSelected: (_) => setState(() => _label = 'Estudio'),
                  ),
                  ChoiceChip(
                    label: const Text('Ejercicio'),
                    selected: _label == 'Ejercicio',
                    selectedColor: Colors.green[300],
                    labelStyle: const TextStyle(color: Colors.black),
                    onSelected: (_) => setState(() => _label = 'Ejercicio'),
                  ),
                  ChoiceChip(
                    label: const Text('Viaje'),
                    selected: _label == 'Viaje',
                    selectedColor: Colors.purple[200],
                    labelStyle: const TextStyle(color: Colors.black),
                    onSelected: (_) => setState(() => _label = 'Viaje'),
                  ),
                  ChoiceChip(
                    label: const Text('Trabajo'),
                    selected: _label == 'Trabajo',
                    selectedColor: Colors.teal[200],
                    labelStyle: const TextStyle(color: Colors.black),
                    onSelected: (_) => setState(() => _label = 'Trabajo'),
                  ),
                  ChoiceChip(
                    label: const Text('Personal'),
                    selected: _label == 'Personal',
                    selectedColor: Colors.pink[200],
                    labelStyle: const TextStyle(color: Colors.black),
                    onSelected: (_) => setState(() => _label = 'Personal'),
                  ),
                  ChoiceChip(
                    label: const Text('Salud'),
                    selected: _label == 'Salud',
                    selectedColor: Colors.red[200],
                    labelStyle: const TextStyle(color: Colors.black),
                    onSelected: (_) => setState(() => _label = 'Salud'),
                  ),
                  ChoiceChip(
                    label: const Text('Finanzas'),
                    selected: _label == 'Finanzas',
                    selectedColor: Colors.amber[300],
                    labelStyle: const TextStyle(color: Colors.black),
                    onSelected: (_) => setState(() => _label = 'Finanzas'),
                  ),
                  ChoiceChip(
                    label: const Text('Otro'),
                    selected: _label == 'Otro',
                    selectedColor: Colors.grey[400],
                    labelStyle: const TextStyle(color: Colors.black),
                    onSelected: (_) => setState(() => _label = 'Otro'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CB3F4),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    if (_formKey.currentState!.validate() && _dueDate != null) {
                      _formKey.currentState!.save();
                      Provider.of<TaskProvider>(context, listen: false).addTask(
                        Task(
                          title: _title,
                          description: _description,
                          dueDate: _dueDate!,
                          priority: _priority,
                          label: _label,
                        ),
                      );
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Agregar tarea'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
