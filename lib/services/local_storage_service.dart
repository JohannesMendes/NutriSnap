import 'dart:convert';
import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../models/user_profile.dart';
import '../models/meal.dart';

/// Guarda todos os dados do app direto no aparelho (Hive), sem servidor.
/// Também oferece exportar/importar um backup manual em .json, pra o
/// usuário não perder os dados ao trocar de celular.
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

  /// Gera um arquivo .json com todos os dados (perfil + diário) e abre o
  /// menu de compartilhamento do celular (WhatsApp, Google Drive, e-mail, etc.)
  static Future<void> exportBackup() async {
    final profileBox = Hive.box(_profileBox);
    final diaryBox = Hive.box(_diaryBox);
    final data = <String, dynamic>{
      _profileBox: {for (final k in profileBox.keys) k.toString(): profileBox.get(k)},
      _diaryBox: {for (final k in diaryBox.keys) k.toString(): diaryBox.get(k)},
    };

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/nutrisnap_backup.json');
    await file.writeAsString(jsonEncode(data));

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Backup do NutriSnap',
    );
  }

  /// Deixa o usuário escolher um arquivo .json de backup e restaura os
  /// dados a partir dele.
  static Future<bool> importBackup() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.single.path == null) return false;

    final file = File(result.files.single.path!);
    final content = jsonDecode(await file.readAsString()) as Map<String, dynamic>;

    if (content.containsKey(_profileBox)) {
      final profileBox = Hive.box(_profileBox);
      for (final entry in (content[_profileBox] as Map<String, dynamic>).entries) {
        await profileBox.put(entry.key, entry.value);
      }
    }
    if (content.containsKey(_diaryBox)) {
      final diaryBox = Hive.box(_diaryBox);
      for (final entry in (content[_diaryBox] as Map<String, dynamic>).entries) {
        await diaryBox.put(entry.key, entry.value);
      }
    }
    return true;
  }
}
