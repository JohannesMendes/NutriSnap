import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/local_storage_service.dart';
import '../../models/user_profile.dart';
import '../diary/diary_screen.dart';
import '../settings/settings_screen.dart';
import '../history/history_screen.dart';

/// Tela inicial: resumo do dia (consumido vs meta), contador de água e
/// acesso ao diário/configurações.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  DateTime _today = DateTime.now();
  Timer? _midnightCheckTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Verifica a cada minuto se a data virou (cobre o caso do app ficar
    // aberto passando da meia-noite, sem precisar sair e voltar).
    _midnightCheckTimer = Timer.periodic(const Duration(minutes: 1), (_) => _checkDayRollover());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnightCheckTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Cobre o caso do celular ficar no bolso/tela bloqueada e o usuário
    // voltar pro app já no dia seguinte.
    if (state == AppLifecycleState.resumed) _checkDayRollover();
  }

  void _checkDayRollover() {
    final now = DateTime.now();
    final changed = now.year != _today.year || now.month != _today.month || now.day != _today.day;
    if (changed && mounted) {
      // O dia anterior já está salvo com sua própria chave (ver
      // LocalStorageService) — não precisa "arquivar" nada explicitamente,
      // só resetar o que a tela mostra pro novo dia.
      setState(() => _today = now);
    }
  }

  int get _consumedToday {
    final meals = LocalStorageService.loadMealsForDate(_today);
    return meals.fold(0, (sum, m) => sum + m.totalCalories);
  }

  Future<void> _addWater(int ml) async {
    await LocalStorageService.addWater(_today, ml);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final DailyTargets? targets = LocalStorageService.loadTargets();
    final consumed = _consumedToday;
    final target = targets?.calories ?? 0;
    final remaining = target - consumed;
    final progress = target > 0 ? (consumed / target).clamp(0.0, 1.0) : 0.0;
    final water = LocalStorageService.loadWaterForDate(_today);
    final waterTarget = targets?.waterMl ?? 2000;
    final waterProgress = waterTarget > 0 ? (water / waterTarget).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hoje'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Resumo do dia', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      backgroundColor: AppColors.surfaceLight,
                      valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('$consumed kcal consumidas',
                          style: const TextStyle(color: AppColors.textSecondary)),
                      Text(
                        target > 0
                            ? (remaining >= 0 ? '$remaining kcal restantes' : '${-remaining} kcal acima')
                            : 'Meta não calculada',
                        style: TextStyle(color: remaining < 0 ? AppColors.danger : AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('💧 Água', style: Theme.of(context).textTheme.titleMedium),
                      Text('$water / $waterTarget ml',
                          style: const TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: waterProgress,
                      minHeight: 10,
                      backgroundColor: AppColors.surfaceLight,
                      valueColor: const AlwaysStoppedAnimation(AppColors.water),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _WaterButton(label: '+200ml', onTap: () => _addWater(200)),
                      const SizedBox(width: 8),
                      _WaterButton(label: '+300ml', onTap: () => _addWater(300)),
                      const SizedBox(width: 8),
                      _WaterButton(label: '+500ml', onTap: () => _addWater(500)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const DiaryScreen()))
                .then((_) => setState(() {})),
            icon: const Icon(Icons.restaurant_menu_rounded),
            label: const Text('Abrir diário de refeições'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const HistoryScreen())),
            icon: const Icon(Icons.calendar_month_rounded),
            label: const Text('Ver histórico de dias anteriores'),
          ),
        ],
      ),
    );
  }
}

class _WaterButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _WaterButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: OutlinedButton(onPressed: onTap, child: Text(label)),
    );
  }
}
