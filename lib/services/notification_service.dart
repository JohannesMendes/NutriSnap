import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import 'local_storage_service.dart';

/// Agenda lembretes diários (café/almoço/jantar) e de água, recorrentes
/// todos os dias no mesmo horário — usando notificações locais, sem
/// nenhum servidor por trás.
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static const _mealChannel = AndroidNotificationDetails(
    'meal_reminders',
    'Lembretes de refeição',
    channelDescription: 'Lembretes pra registrar suas refeições',
    importance: Importance.high,
    priority: Priority.high,
  );

  static const _waterChannel = AndroidNotificationDetails(
    'water_reminders',
    'Lembretes de água',
    channelDescription: 'Lembretes pra beber água ao longo do dia',
    importance: Importance.defaultImportance,
  );

  static Future<void> init() async {
    tzdata.initializeTimeZones();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);
  }

  static Future<void> requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> _scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    required AndroidNotificationDetails channel,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      NotificationDetails(android: channel),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // repete todo dia
    );
  }

  static int _parseHour(String hhmm) => int.parse(hhmm.split(':')[0]);
  static int _parseMinute(String hhmm) => int.parse(hhmm.split(':')[1]);

  /// Recria todos os lembretes com base nas configurações salvas.
  static Future<void> rescheduleAll() async {
    await _plugin.cancelAll();
    final settings = LocalStorageService.loadReminderSettings();

    await _scheduleDaily(
      id: 1,
      title: 'Café da manhã 🍳',
      body: 'Hora de registrar seu café da manhã no NutriSnap.',
      hour: _parseHour(settings['breakfast']!),
      minute: _parseMinute(settings['breakfast']!),
      channel: _mealChannel,
    );
    await _scheduleDaily(
      id: 2,
      title: 'Almoço 🍽️',
      body: 'Hora de registrar seu almoço no NutriSnap.',
      hour: _parseHour(settings['lunch']!),
      minute: _parseMinute(settings['lunch']!),
      channel: _mealChannel,
    );
    await _scheduleDaily(
      id: 3,
      title: 'Jantar 🌙',
      body: 'Hora de registrar seu jantar no NutriSnap.',
      hour: _parseHour(settings['dinner']!),
      minute: _parseMinute(settings['dinner']!),
      channel: _mealChannel,
    );

    // Lembretes de água: espalhados entre o início e o fim do período,
    // a cada N horas configuradas.
    final startHour = _parseHour(settings['water_start']!);
    final endHour = _parseHour(settings['water_end']!);
    final interval = int.parse(settings['water_interval_hours']!);
    var id = 100;
    for (var hour = startHour; hour <= endHour; hour += interval) {
      await _scheduleDaily(
        id: id++,
        title: 'Beba água 💧',
        body: 'Não esqueça de registrar sua ingestão de água.',
        hour: hour,
        minute: 0,
        channel: _waterChannel,
      );
    }
  }
}
