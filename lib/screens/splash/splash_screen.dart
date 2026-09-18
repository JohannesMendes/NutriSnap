import 'package:flutter/material.dart';
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
      // Mesma cor de fundo da logo (extraída do PNG enviado), pra a
      // splash ficar visualmente idêntica à marca — sem borda ou "caixa"
      // em volta da imagem.
      backgroundColor: const Color(0xFF00BF63),
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Image.asset(
              'assets/images/logo_lockup.png',
              width: 260,
            ),
          ),
        ),
      ),
    );
  }
}
