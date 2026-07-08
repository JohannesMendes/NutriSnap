import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/user_profile.dart';
import '../models/meal.dart';
import '../config/app_config.dart';

/// Guarda todos os dados do app direto no aparelho (Hive), sem servidor
/// e sem nenhuma configuração externa — persistência 100% local e
/// transparente pro usuário.
class LocalStorageService {
  static const _profileBox = 'profile_box';
  static const _profileKey = 'user_profile';
  static const _targetsKey = 'daily_targets';
  static const _diaryBox = 'diary_box'; // uma chave por dia, formato yyyy-MM-dd

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_profileBox);
    await Hive.openBox(_diaryBox);
  }

  static Future<void> saveProfile(UserProfile profile) async {
    final box = Hive.box(_profileBox);
    await box.put(_profileKey, jsonEncode(profile.toMap()));
  }

  static UserProfile? loadProfile() {
    final box = Hive.box(_profileBox);
    final raw = box.get(_profileKey);
    if (raw == null) return null;
    return UserProfile.fromMap('local', jsonDecode(raw));
  }

  static bool hasProfile() => Hive.box(_profileBox).containsKey(_profileKey);

  static Future<void> saveTargets(DailyTargets targets) async {
    final box = Hive.box(_profileBox);
    await box.put(_targetsKey, jsonEncode({
      'calories': targets.calories,
      'proteinG': targets.proteinG,
      'carbsG': targets.carbsG,
      'fatG': targets.fatG,
      'waterMl': targets.waterMl,
    }));
  }

  static DailyTargets? loadTargets() {
    final box = Hive.box(_profileBox);
    final raw = box.get(_targetsKey);
    if (raw == null) return null;
    final map = jsonDecode(raw);
    return DailyTargets(
      calories: map['calories'],
      proteinG: map['proteinG'],
      carbsG: map['carbsG'],
      fatG: map['fatG'],
      waterMl: map['waterMl'],
    );
  }

  static String _dayKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  // ---------------- Água ----------------

  static int loadWaterForDate(DateTime date) {
    final box = Hive.box(_diaryBox);
    return box.get('water_${_dayKey(date)}', defaultValue: 0) as int;
  }

  static Future<void> addWater(DateTime date, int ml) async {
    final box = Hive.box(_diaryBox);
    final key = 'water_${_dayKey(date)}';
    final current = box.get(key, defaultValue: 0) as int;
    await box.put(key, current + ml);
  }

  // ---------------- Foto diária (check-in) ----------------

  static Future<void> savePhotoPath(DateTime date, String path) async {
    final box = Hive.box(_diaryBox);
    await box.put('photo_${_dayKey(date)}', path);
  }

  static String? loadPhotoPath(DateTime date) {
    final box = Hive.box(_diaryBox);
    return box.get('photo_${_dayKey(date)}');
  }

  /// Retorna todas as fotos de check-in salvas, mais recentes primeiro.
  static List<MapEntry<String, String>> loadAllPhotos() {
    final box = Hive.box(_diaryBox);
    final entries = box.keys
        .where((k) => k.toString().startsWith('photo_'))
        .map((k) => MapEntry(k.toString().replaceFirst('photo_', ''), box.get(k) as String))
        .toList();
    entries.sort((a, b) => b.key.compareTo(a.key));
    return entries;
  }

  // ---------------- Configurações (API key + lembretes) ----------------

  static Future<void> saveGeminiApiKey(String key) async {
    final box = Hive.box(_profileBox);
    await box.put('gemini_api_key', key);
  }

  static String? loadGeminiApiKey() {
    final userKey = Hive.box(_profileBox).get('gemini_api_key') as String?;
    if (userKey != null && userKey.isNotEmpty) return userKey;
    // Sem chave própria salva -> usa a chave de testes embutida no build
    // (injetada via --dart-define, não fica no código-fonte).
    return kBuiltInGeminiApiKey.isNotEmpty ? kBuiltInGeminiApiKey : null;
  }

  /// Indica se a chave em uso é a própria do usuário (não a de testes).
  static bool hasCustomGeminiApiKey() {
    final userKey = Hive.box(_profileBox).get('gemini_api_key') as String?;
    return userKey != null && userKey.isNotEmpty;
  }

  /// Horários dos lembretes, salvos como "HH:mm". Chaves: breakfast, lunch,
  /// dinner, water_start, water_end, water_interval_hours.
  static Future<void> saveReminderSettings(Map<String, String> settings) async {
    final box = Hive.box(_profileBox);
    await box.put('reminder_settings', jsonEncode(settings));
  }

  static Map<String, String> loadReminderSettings() {
    final box = Hive.box(_profileBox);
    final raw = box.get('reminder_settings');
    if (raw == null) {
      return {
        'breakfast': '08:00',
        'lunch': '12:30',
        'dinner': '19:30',
        'water_start': '08:00',
        'water_end': '22:00',
        'water_interval_hours': '2',
      };
    }
    return Map<String, String>.from(jsonDecode(raw));
  }

  /// Retorna as refeições do dia informado. Se o dia ainda não tem nada
  /// salvo, cria as 3 refeições padrão (Café da Manhã, Almoço, Jantar).
  static List<Meal> loadMealsForDate(DateTime date) {
    final box = Hive.box(_diaryBox);
    final raw = box.get(_dayKey(date));
    if (raw == null) return Meal.defaultMeals();
    final list = jsonDecode(raw) as List;
    return list.map((m) => Meal.fromMap(Map<String, dynamic>.from(m))).toList();
  }

  static Future<void> saveMealsForDate(DateTime date, List<Meal> meals) async {
    final box = Hive.box(_diaryBox);
    await box.put(_dayKey(date), jsonEncode(meals.map((m) => m.toMap()).toList()));
  }

  /// Retorna as datas (mais recentes primeiro) que já têm pelo menos um
  /// alimento registrado — é o que alimenta a tela de Histórico. Cada dia
  /// já fica salvo com sua própria chave desde o início, então "arquivar"
  /// é automático: só precisamos listar o que já existe.
  static List<DateTime> loadDiaryDatesWithEntries() {
    final box = Hive.box(_diaryBox);
    final dateKeyPattern = RegExp(r'^\d{4}-\d{1,2}-\d{1,2}$');
    final dates = <DateTime>[];
    for (final k in box.keys) {
      final key = k.toString();
      if (!dateKeyPattern.hasMatch(key)) continue;
      final raw = box.get(key);
      if (raw == null) continue;
      try {
        final list = jsonDecode(raw) as List;
        final meals = list.map((m) => Meal.fromMap(Map<String, dynamic>.from(m))).toList();
        final hasFood = meals.any((m) => m.entries.isNotEmpty);
        if (hasFood) {
          final parts = key.split('-');
          dates.add(DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2])));
        }
      } catch (_) {
        // Chave inesperada — ignora.
      }
    }
    dates.sort((a, b) => b.compareTo(a));
    return dates;
  }
}
