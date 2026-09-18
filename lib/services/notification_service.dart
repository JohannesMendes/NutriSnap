import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import 'local_storage_service.dart';

/// Agenda lembretes diários (café/almoço/jantar) e de água, recorrentes
/// todos os dias no mesmo horário — usando notificações locais, sem
/// nenhum servidor por trás.
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

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
    importance: Importance.high,
    priority: Priority.high,
  );

  // createNotificationChannel espera um AndroidNotificationChannel (só a
  // definição do canal), diferente do AndroidNotificationDetails (usado na
  // hora de agendar cada notificação) — por isso duas versões, uma de cada
  // tipo, com os mesmos ids/nomes.
  static const _mealChannelDef = AndroidNotificationChannel(
    'meal_reminders',
    'Lembretes de refeição',
    description: 'Lembretes pra registrar suas refeições',
    importance: Importance.high,
  );

  static const _waterChannelDef = AndroidNotificationChannel(
    'water_reminders',
    'Lembretes de água',
    description: 'Lembretes pra beber água ao longo do dia',
    importance: Importance.high,
  );

  static const _darwinDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentSound: true,
    presentBadge: true,
  );

  static Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation(await _deviceTimeZoneName()));
    } catch (_) {
      // Se não conseguir detectar o fuso do aparelho, segue com o fuso
      // padrão da lib (UTC) — os horários ainda funcionam, só não seguem
      // o fuso local até o próximo _scheduleDaily recalcular.
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false, // pedimos explicitamente em requestPermission()
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit, macOS: iosInit);
    await _plugin.initialize(initSettings);

    // Cria os canais Android explicitamente. Sem isso, em alguns
    // aparelhos/fabricantes o primeiro agendamento silenciosamente não
    // dispara porque o canal só é criado de fato na primeira notificação
    // "imediata" — nunca em uma agendada.
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_mealChannelDef);
    await androidPlugin?.createNotificationChannel(_waterChannelDef);

    _initialized = true;
  }

  static Future<String> _deviceTimeZoneName() async {
    // O plugin `timezone` não traz detecção automática de fuso; usamos o
    // offset atual do aparelho pra escolher o fuso mais próximo. Isso é
    // suficiente pra manter os lembretes no horário local, mesmo sem uma
    // lib de geolocalização de fuso.
    final offset = DateTime.now().timeZoneOffset;
    if (offset == const Duration(hours: -3)) return 'America/Sao_Paulo';
    return 'UTC';
  }

  /// Pede permissão pra mostrar notificações (Android 13+ e iOS) e, no
  /// Android 12+, também a permissão de alarmes exatos — sem essa segunda
  /// permissão, o sistema pode atrasar os lembretes por minutos ou horas
  /// ("modo economia de bateria"), o que é a causa mais comum de
  /// lembretes que "não disparam na hora certa".
  static Future<void> requestPermission() async {
    if (!_initialized) await init();

    if (Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
      await androidPlugin?.requestExactAlarmsPermission();
    } else if (Platform.isIOS || Platform.isMacOS) {
      final iosPlugin = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      await iosPlugin?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  static Future<bool> _canScheduleExactAlarms() async {
    if (!Platform.isAndroid) return true;
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await androidPlugin?.canScheduleExactNotifications() ?? false;
  }

  static Future<void> _scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    required AndroidNotificationDetails channel,
    required bool exact,
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
      NotificationDetails(android: channel, iOS: _darwinDetails, macOS: _darwinDetails),
      // Usa horário exato quando o usuário concedeu a permissão (o padrão
      // hoje em dia); só recorre ao modo inexato como fallback, pra não
      // travar o app numa exceção quando a permissão não foi concedida.
      androidScheduleMode: exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // repete todo dia
    );
  }

  static int _parseHour(String hhmm) => int.parse(hhmm.split(':')[0]);
  static int _parseMinute(String hhmm) => int.parse(hhmm.split(':')[1]);

  /// Recria todos os lembretes com base nas configurações salvas. Chamado
  /// tanto ao salvar Configurações quanto na abertura do app (se o perfil
  /// já existe) — assim os lembretes continuam ativos mesmo que o usuário
  /// nunca abra a tela de Configurações depois do onboarding.
  static Future<void> rescheduleAll() async {
    if (!_initialized) await init();
    await _plugin.cancelAll();
    final settings = LocalStorageService.loadReminderSettings();
    final mealsEnabled = settings['meals_enabled'] != 'false';
    final waterEnabled = settings['water_enabled'] != 'false';
    final exact = await _canScheduleExactAlarms();
    if (!exact) {
      debugPrint(
        'NutriSnap: permissão de alarme exato não concedida — lembretes '
        'podem atrasar. Peça pro usuário liberar em Configurações do '
        'aparelho > Apps > NutriSnap > Alarmes e lembretes.',
      );
    }

    if (mealsEnabled) {
      await _scheduleDaily(
        id: 1,
        title: 'Café da manhã 🍳',
        body: 'Hora de registrar seu café da manhã no NutriSnap.',
        hour: _parseHour(settings['breakfast']!),
        minute: _parseMinute(settings['breakfast']!),
        channel: _mealChannel,
        exact: exact,
      );
      await _scheduleDaily(
        id: 2,
        title: 'Almoço 🍽️',
        body: 'Hora de registrar seu almoço no NutriSnap.',
        hour: _parseHour(settings['lunch']!),
        minute: _parseMinute(settings['lunch']!),
        channel: _mealChannel,
        exact: exact,
      );
      await _scheduleDaily(
        id: 3,
        title: 'Jantar 🌙',
        body: 'Hora de registrar seu jantar no NutriSnap.',
        hour: _parseHour(settings['dinner']!),
        minute: _parseMinute(settings['dinner']!),
        channel: _mealChannel,
        exact: exact,
      );
    }

    if (waterEnabled) {
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
          exact: exact,
        );
      }
    }
  }
}
