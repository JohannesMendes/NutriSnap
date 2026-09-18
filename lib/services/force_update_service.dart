import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart';

class ForceUpdateResult {
  final bool mustUpdate;
  final String updateUrl;
  const ForceUpdateResult({required this.mustUpdate, required this.updateUrl});
}

/// Checa, a cada abertura do app, se a versão instalada é menor que a
/// versão mínima exigida — configurada no Firebase Remote Config, sem
/// precisar de um novo build/deploy só pra "ligar" o bloqueio.
///
/// No Console do Firebase (Remote Config), crie estes dois parâmetros:
///   - min_version   (String) ex: "1.2.0"  -> versão mínima permitida
///   - update_url    (String) ex: link da Play Store / App Store
class ForceUpdateService {
  static Future<ForceUpdateResult> check() async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: Duration.zero,
      ));
      await remoteConfig.setDefaults({'min_version': '0.0.0', 'update_url': ''});
      await remoteConfig.fetchAndActivate();

      final minVersion = remoteConfig.getString('min_version');
      final updateUrl = remoteConfig.getString('update_url');

      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version; // ex: "1.0.0"

      final mustUpdate = _isLower(currentVersion, minVersion);
      return ForceUpdateResult(mustUpdate: mustUpdate, updateUrl: updateUrl);
    } catch (e) {
      // Sem internet, Remote Config fora do ar, projeto Firebase ainda não
      // configurado etc. — nesses casos, não travamos o usuário: melhor
      // deixar ele usar o app normalmente do que ficar preso numa tela de
      // erro por causa de um problema de rede.
      debugPrint('NutriSnap: falha ao checar atualização obrigatória: $e');
      return const ForceUpdateResult(mustUpdate: false, updateUrl: '');
    }
  }

  /// Compara duas versões no formato "major.minor.patch" (aceita também
  /// formatos parciais, tipo "1.2"). Retorna true se [current] < [min].
  static bool _isLower(String current, String min) {
    final c = _parts(current);
    final m = _parts(min);
    final length = c.length > m.length ? c.length : m.length;
    for (var i = 0; i < length; i++) {
      final cPart = i < c.length ? c[i] : 0;
      final mPart = i < m.length ? m[i] : 0;
      if (cPart != mPart) return cPart < mPart;
    }
    return false;
  }

  static List<int> _parts(String version) {
    return version.trim().split('.').map((p) {
      final digitsOnly = p.replaceAll(RegExp(r'[^0-9]'), '');
      return int.tryParse(digitsOnly) ?? 0;
    }).toList();
  }
}
