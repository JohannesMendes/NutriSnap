import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/local_storage_service.dart';
import '../onboarding/goal_calculator_screen.dart';
import '../home/home_screen.dart';

/// Tela de abertura com uma animação fluida enquanto os dados locais
/// (Hive) são carregados — evita o app "piscar" direto numa tela crua.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _fade = CurvedAnimation(parent: _controller, curve: const Interval(0, 0.6, curve: Curves.easeIn));
    _controller.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    // Pequeno delay proposital só pra animação respirar — os dados locais
    // (Hive) já são lidos de forma quase instantânea.
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    final hasProfile = LocalStorageService.hasProfile();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, anim, __) => FadeTransition(
          opacity: anim,
          child: hasProfile ? const HomeScreen() : const GoalCalculatorScreen(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(color: AppColors.primary.withOpacity(0.25), blurRadius: 40, spreadRadius: 4),
                    ],
                  ),
                  child: const Icon(Icons.eco_rounded, size: 56, color: AppColors.primary),
                ),
                const SizedBox(height: 20),
                const Text('NutriSnap',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                const Text('Sua evolução, todo dia.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
