import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/user_profile.dart';
import '../models/meal.dart';

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

  // ---------------- Configurações (lembretes) ----------------
  //
  // A chave da API do Gemini não fica mais no aparelho: o scanner de IA
  // agora fala com um backend seguro (Firebase Cloud Functions), que
  // guarda a chave só no servidor. Ver lib/config/app_config.dart e
  // lib/services/gemini_service.dart.

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

  /// Retorna as refeições do dia informado. A ESTRUTURA de refeições
  /// (quais blocos existem — padrão e personalizados) é permanente e vive
  /// separada do consumo diário: aqui, montamos cada dia combinando essa
  /// estrutura fixa com os alimentos daquele dia específico. Assim, um
  /// bloco personalizado como "Lanche da Tarde" nunca some na virada da
  /// meia-noite — só os alimentos dele são zerados.
  static List<Meal> loadMealsForDate(DateTime date) {
    final structure = loadMealStructure();
    final box = Hive.box(_diaryBox);
    final raw = box.get(_dayKey(date));

    final dayMeals = <String, Meal>{};
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      for (final m in list) {
        final meal = Meal.fromMap(Map<String, dynamic>.from(m));
        dayMeals[meal.id] = meal;
      }
    }

    final result = structure
        .map((tpl) => Meal(
              id: tpl.id,
              name: tpl.name,
              isDefault: tpl.isDefault,
              entries: dayMeals[tpl.id]?.entries ?? [],
            ))
        .toList();

    // Refeições que só existem nos dados desse dia (ex: criadas antes dessa
    // versão, quando a estrutura ainda não era persistida à parte) também
    // entram na lista, e a estrutura é atualizada pra incluí-las dali em
    // diante — sem perder nenhum bloco que o usuário já tinha criado.
    var structureChanged = false;
    for (final m in dayMeals.values) {
      if (!result.any((r) => r.id == m.id)) {
        result.add(Meal(id: m.id, name: m.name, isDefault: m.isDefault, entries: m.entries));
        structureChanged = true;
      }
    }
    if (structureChanged) {
      _saveMealStructure(result);
    }
    return result;
  }

  static Future<void> saveMealsForDate(DateTime date, List<Meal> meals) async {
    final box = Hive.box(_diaryBox);
    await box.put(_dayKey(date), jsonEncode(meals.map((m) => m.toMap()).toList()));
    // Mantém a estrutura (quais blocos de refeição existem) sempre em dia,
    // independente do dia — é o que garante que blocos novos sobrevivam
    // ao reset diário.
    await _saveMealStructure(meals);
  }

  static const _mealStructureKey = 'meal_structure';

  /// A lista de blocos de refeição que o usuário tem hoje (padrão +
  /// personalizados), sem os alimentos — é o "esqueleto" fixo que se repete
  /// todo dia, vazio, até o usuário adicionar comida nele.
  static List<Meal> loadMealStructure() {
    final box = Hive.box(_profileBox);
    final raw = box.get(_mealStructureKey);
    if (raw == null) return Meal.defaultMeals();
    final list = jsonDecode(raw) as List;
    return list.map((m) => Meal.fromMap(Map<String, dynamic>.from(m))).toList();
  }

  static Future<void> _saveMealStructure(List<Meal> meals) async {
    final box = Hive.box(_profileBox);
    // Salva só o esqueleto (id/nome/tipo), nunca os alimentos — o consumo
    // fica exclusivamente na chave por dia.
    final shells = meals.map((m) => Meal(id: m.id, name: m.name, isDefault: m.isDefault)).toList();
    await box.put(_mealStructureKey, jsonEncode(shells.map((s) => s.toMap()).toList()));
  }

  // ---------------- Preferência de salvar fotos na galeria (opt-in) ----------------

  static const _askedGalleryKey = 'asked_save_photos_gallery';
  static const _savePhotosKey = 'save_photos_gallery';

  /// Se já perguntamos ao usuário (uma vez só) se ele quer salvar as fotos
  /// das refeições na galeria.
  static bool hasAskedGalleryPreference() =>
      Hive.box(_profileBox).get(_askedGalleryKey, defaultValue: false) as bool;

  static Future<void> setAskedGalleryPreference(bool asked) async {
    await Hive.box(_profileBox).put(_askedGalleryKey, asked);
  }

  /// Preferência do usuário: salvar (true) ou não (false) as fotos das
  /// refeições na galeria do aparelho. Padrão é NÃO salvar (opt-in) até
  /// que o usuário decida explicitamente que quer.
  static bool loadSavePhotosToGallery() =>
      Hive.box(_profileBox).get(_savePhotosKey, defaultValue: false) as bool;

  static Future<void> setSavePhotosToGallery(bool value) async {
    await Hive.box(_profileBox).put(_savePhotosKey, value);
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

  /// Exclui todos os dados de um dia específico do histórico: as
  /// refeições/alimentos registrados naquele dia, o total de água bebida
  /// e a foto de check-in (se houver). Ação irreversível — a tela de
  /// Histórico confirma com o usuário antes de chamar isso.
  static Future<void> deleteDay(DateTime date) async {
    final box = Hive.box(_diaryBox);
    final key = _dayKey(date);
    await box.delete(key);
    await box.delete('water_$key');
    await box.delete('photo_$key');
  }
}
