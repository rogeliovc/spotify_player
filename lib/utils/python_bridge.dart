import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class PythonBridge {
  static Future<Map<String, dynamic>> getRecommendations(String taskType) async {
    try {
      // Crear proceso Python
      final process = await Process.start(
        'python3',
        [
          'python/recommendation/recommend.py',
        ],
        runInShell: true,
      );

      // Enviar datos al script Python
      process.stdin.writeln(jsonEncode({
        'task_type': taskType,
      }));
      await process.stdin.flush();
      await process.stdin.close();

      // Leer respuesta
      final stdout = await process.stdout.transform(utf8.decoder).join();
      final stderr = await process.stderr.transform(utf8.decoder).join();

      if (stderr.isNotEmpty) {
        throw Exception('Error en el script Python: $stderr');
      }

      // Parsear respuesta
      final result = jsonDecode(stdout);
      return result;
    } catch (e) {
      debugPrint('Error en PythonBridge: $e');
      rethrow;
    }
  }
}
