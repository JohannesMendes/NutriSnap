import 'dart:convert';
import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../models/user_profile.dart';

/// Guarda todos os dados do app direto no aparelho (Hive), sem servidor.
/// Também oferece exportar/importar um backup manual em .json, pra o
/// usuário não perder os dados ao trocar de celular.
class LocalStorageService {
  static const _profileBox = 'profile_box';
  static const _profileKey = 'user_profile';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_profileBox);
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

  /// Gera um arquivo .json com todos os dados e abre o menu de
  /// compartilhamento do celular (WhatsApp, Google Drive, e-mail, etc.)
  static Future<void> exportBackup() async {
    final box = Hive.box(_profileBox);
    final data = <String, dynamic>{};
    for (final key in box.keys) {
      data[key.toString()] = box.get(key);
    }

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

    final box = Hive.box(_profileBox);
    for (final entry in content.entries) {
      await box.put(entry.key, entry.value);
    }
    return true;
  }
}
