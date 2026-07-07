import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'services/local_storage_service.dart';
import 'screens/onboarding/goal_calculator_screen.dart';
import 'screens/home/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa o armazenamento local (Hive) — tudo fica salvo no aparelho,
  // sem nenhum servidor externo.
  await LocalStorageService.init();

  runApp(const NutriSnapApp());
}

class NutriSnapApp extends StatelessWidget {
  const NutriSnapApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Se já existe um perfil salvo localmente, vai direto pra Home.
    // Senão, mostra a calculadora de metas (que funciona como onboarding).
    final hasProfile = LocalStorageService.hasProfile();

    return MaterialApp(
      title: 'NutriSnap',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: hasProfile ? const HomeScreen() : const GoalCalculatorScreen(),
    );
  }
}
