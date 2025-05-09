import 'package:shared_preferences/shared_preferences.dart';
import '../models/task_model.dart';
import 'dart:convert';

class TaskStorage {
  static const String _tasksKey = 'tasks';

  Future<void> saveTasks(List<Task> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final tasksJson = tasks
        .map((task) => jsonEncode(task.toJson()))
        .toList();
    await prefs.setStringList(_tasksKey, tasksJson);
  }

  Future<List<Task>> loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final tasksJson = prefs.getStringList(_tasksKey) ?? [];
    return tasksJson
        .map((json) => Task.fromJson(Map<String, dynamic>.from(jsonDecode(json))))
        .toList();
  }
}
