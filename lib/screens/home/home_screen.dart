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
                  // Grade compacta: cada botão traz um ícone diferente pra
                  // deixar o tamanho da porção reconhecível de longe, sem
                  // precisar ler o número.
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.5,
                    children: [
                      _WaterButton(icon: Icons.local_cafe_rounded, label: '+200ml', onTap: () => _addWater(200)),
                      _WaterButton(icon: Icons.local_drink_rounded, label: '+300ml', onTap: () => _addWater(300)),
                      _WaterButton(icon: Icons.water_drop_rounded, label: '+500ml', onTap: () => _addWater(500)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SectionButton(
                  icon: Icons.restaurant_menu_rounded,
                  label: 'Diário de refeições',
                  filled: true,
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const DiaryScreen()))
                      .then((_) => setState(() {})),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SectionButton(
                  icon: Icons.calendar_month_rounded,
                  label: 'Histórico',
                  filled: false,
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const HistoryScreen()))
                      .then((_) => setState(() {})),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WaterButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _WaterButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        side: const BorderSide(color: AppColors.water),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: AppColors.water),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

/// Botão de seção com ícone à esquerda, usado pros dois grandes acessos
/// da home (diário de hoje e histórico) — o preenchimento (`filled`)
/// diferencia visualmente a ação principal da secundária.
class _SectionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;
  const _SectionButton({
    required this.icon,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final child = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 22),
        const SizedBox(height: 6),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
      ],
    );
    final padding = const EdgeInsets.symmetric(vertical: 14);
    return filled
        ? ElevatedButton(onPressed: onTap, style: ElevatedButton.styleFrom(padding: padding), child: child)
        : OutlinedButton(onPressed: onTap, style: OutlinedButton.styleFrom(padding: padding), child: child);
  }
}
