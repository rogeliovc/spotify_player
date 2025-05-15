import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> showTaskCreatedNotification({
    required int id,
    required String title,
    required String description,
    required DateTime dueDate,
  }) async {
    await flutterLocalNotificationsPlugin.show(
      id,
      '🎉 Nueva tarea: $title',
      'Vence el ${_formatDate(dueDate)}. $description',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'task_channel',
          'Tareas',
          channelDescription: 'Notificaciones de tareas',
          importance: Importance.max,
          priority: Priority.high,
          color: Color(0xFF4CB3F4),
          icon: '@mipmap/ic_launcher',
          styleInformation: BigTextStyleInformation(
            '',
            contentTitle: '🎉 Nueva tarea',
            summaryText: '¡No olvides revisar tu nueva tarea!',
          ),
        ),
      ),
    );
  }

  Future<void> scheduleDailyReminder({
    required int id,
    required String title,
    required String description,
    required DateTime dueDate,
  }) async {
    final now = DateTime.now();
    // Notifica desde hoy hasta 30 días después del vencimiento
    final int totalDays = dueDate.difference(now).inDays >= 0
        ? dueDate.difference(now).inDays + 30
        : 30; // Si ya está vencida, notifica 30 días más
    for (int i = 0; i <= totalDays; i++) {
      final scheduledDate = now.add(Duration(days: i));
      final scheduledDateTime = DateTime(
        scheduledDate.year,
        scheduledDate.month,
        scheduledDate.day,
        9, // 9:00 AM
        0,
        0,
      );
      // Notifica todos los días a las 9:00 AM, incluso después del vencimiento
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id + i,
        scheduledDate.isBefore(dueDate)
            ? '⏰ Recordatorio: $title'
            : '❗️ Tarea vencida: $title',
        scheduledDate.isBefore(dueDate)
            ? 'Vence el ${_formatDate(dueDate)}. $description'
            : 'Esta tarea está vencida desde el ${_formatDate(dueDate)}. $description',
        tz.TZDateTime.from(scheduledDateTime, tz.local),
        NotificationDetails(
          android: AndroidNotificationDetails(
            scheduledDate.isBefore(dueDate)
                ? 'task_channel'
                : 'overdue_channel',
            scheduledDate.isBefore(dueDate) ? 'Tareas' : 'Tareas vencidas',
            channelDescription: scheduledDate.isBefore(dueDate)
                ? 'Notificaciones de tareas'
                : 'Notificaciones de tareas vencidas',
            importance: Importance.max,
            priority: Priority.high,
            color: scheduledDate.isBefore(dueDate)
                ? Color(0xFF4CB3F4)
                : Color(0xFFFF0000),
            icon: '@mipmap/ic_launcher',
            styleInformation: BigTextStyleInformation(
              '',
              contentTitle: scheduledDate.isBefore(dueDate)
                  ? '⏰ Recordatorio diario'
                  : '❗️ Tarea vencida',
              summaryText: scheduledDate.isBefore(dueDate)
                  ? '¡Sigue avanzando en tus tareas!'
                  : '¡No olvides completar tu tarea!',
            ),
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }

  Future<void> schedule12HoursBefore({
    required int id,
    required String title,
    required String description,
    required DateTime dueDate,
  }) async {
    final scheduledDate = dueDate.subtract(const Duration(hours: 12));
    if (scheduledDate.isAfter(DateTime.now())) {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id + 10000,
        '⚡️ ¡Faltan 12 horas! $title',
        'La tarea vence pronto: ${_formatDate(dueDate)}. $description',
        tz.TZDateTime.from(scheduledDate, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'task_channel',
            'Tareas',
            channelDescription: 'Notificaciones de tareas',
            importance: Importance.max,
            priority: Priority.high,
            color: Color(0xFFFFC107),
            icon: '@mipmap/ic_launcher',
            styleInformation: BigTextStyleInformation(
              '',
              contentTitle: '<b>⚡️ ¡Faltan 12 horas!</b>',
              summaryText: '¡Último empujón antes del vencimiento!',
            ),
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }

  Future<void> showOverdueNotification({
    required int id,
    required String title,
    required String description,
    required DateTime dueDate,
  }) async {
    final now = DateTime.now();
    final overdueDuration = now.difference(dueDate);
    final overdueText = _formatDuration(overdueDuration);
    await flutterLocalNotificationsPlugin.show(
      id + 20000,
      '❗️ ¡Tarea vencida! $title',
      'Vencida hace $overdueText. $description',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'overdue_channel',
          'Tareas vencidas',
          channelDescription: 'Notificaciones de tareas vencidas',
          importance: Importance.max,
          priority: Priority.high,
          color: Color(0xFFFF0000),
          icon: '@mipmap/ic_launcher',
          styleInformation: BigTextStyleInformation(
            '',
            contentTitle: '<b>❗️ ¡Tarea vencida!</b>',
            summaryText: '¡No olvides completar tu tarea!',
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    // Si la hora es 00:00, solo muestra la fecha
    if (date.hour == 0 && date.minute == 0) {
      return '${date.day}/${date.month}/${date.year}';
    } else {
      return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays} días';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} horas';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes} minutos';
    } else {
      return 'unos segundos';
    }
  }
}
