import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'services/local_storage_service.dart';
import 'services/notification_service.dart';
import 'screens/splash/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Armazenamento local (Hive) — tudo fica salvo no aparelho, sem servidor.
  await LocalStorageService.init();
  await NotificationService.init();

  // Se o usuário já tem um perfil (não é a primeira vez que abre o app),
  // garante que os lembretes de refeição/água continuem agendados mesmo
  // que ele nunca entre na tela de Configurações — antes, os lembretes só
  // eram (re)agendados quando o usuário salvava as configurações.
  if (LocalStorageService.hasProfile()) {
    await NotificationService.requestPermission();
    await NotificationService.rescheduleAll();
  }

  runApp(const NutriSnapApp());
}

class NutriSnapApp extends StatelessWidget {
  const NutriSnapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NutriSnap',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: const SplashScreen(),
    );
  }
}
