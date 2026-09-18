// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, TargetPlatform, defaultTargetPlatform;

/// ⚠️ ARQUIVO PLACEHOLDER — PRECISA SER GERADO DE VERDADE ANTES DO BUILD.
///
/// Este arquivo normalmente é gerado automaticamente pela CLI oficial do
/// FlutterFire, e NÃO deve ser editado à mão — os valores abaixo são só
/// placeholders pra o projeto compilar a estrutura de código, mas o app
/// vai falhar ao iniciar (`Firebase.initializeApp`) até você rodar:
///
///   1. `dart pub global activate flutterfire_cli`
///   2. `firebase login` (se ainda não tiver feito)
///   3. Na raiz do projeto: `flutterfire configure`
///      -> escolha (ou crie) o projeto Firebase
///      -> selecione as plataformas (Android/iOS)
///      -> isso SOBRESCREVE este arquivo com as chaves reais do seu
///         projeto Firebase (apiKey, appId, projectId, etc.)
///
/// Depois disso, ative o método de login "E-mail/senha" no Console do
/// Firebase (Authentication > Sign-in method) e crie os campos
/// `min_version` (String, ex: "1.2.0") e `update_url` (String, link da
/// Play Store) no Remote Config — é isso que a tela de atualização
/// obrigatória lê.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions não foi configurado pra Web. Rode `flutterfire configure`.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions não foi configurado pra essa plataforma (${Platform.operatingSystem}).',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'SUBSTITUA_VIA_FLUTTERFIRE_CONFIGURE',
    appId: 'SUBSTITUA_VIA_FLUTTERFIRE_CONFIGURE',
    messagingSenderId: 'SUBSTITUA_VIA_FLUTTERFIRE_CONFIGURE',
    projectId: 'SUBSTITUA_VIA_FLUTTERFIRE_CONFIGURE',
    storageBucket: 'SUBSTITUA_VIA_FLUTTERFIRE_CONFIGURE',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'SUBSTITUA_VIA_FLUTTERFIRE_CONFIGURE',
    appId: 'SUBSTITUA_VIA_FLUTTERFIRE_CONFIGURE',
    messagingSenderId: 'SUBSTITUA_VIA_FLUTTERFIRE_CONFIGURE',
    projectId: 'SUBSTITUA_VIA_FLUTTERFIRE_CONFIGURE',
    storageBucket: 'SUBSTITUA_VIA_FLUTTERFIRE_CONFIGURE',
    iosBundleId: 'com.nutrisnap.nutrisnap',
  );
}
