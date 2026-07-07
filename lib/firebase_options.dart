import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'dart:io' show Platform;

/// PREENCHA com os dados do SEU projeto Firebase (veja o README, seção
/// "Configurar Firebase sem terminal"). Todos os valores vêm direto do
/// Console do Firebase (Configurações do projeto > Seus apps).
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (Platform.isAndroid) return android;
    throw UnsupportedError('Plataforma não configurada ainda.');
  }

  static const android = FirebaseOptions(
    apiKey: 'COLE_AQUI_A_API_KEY',
    appId: 'COLE_AQUI_O_APP_ID',
    messagingSenderId: 'COLE_AQUI_O_SENDER_ID',
    projectId: 'COLE_AQUI_O_PROJECT_ID',
    storageBucket: 'COLE_AQUI_O_STORAGE_BUCKET',
  );
}
