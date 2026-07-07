import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/local_storage_service.dart';
import '../../models/user_profile.dart';
import '../diary/diary_screen.dart';

/// Tela inicial: resumo do dia (consumido vs meta) + acesso ao diário e
/// ao backup manual.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _working = false;

  int get _consumedToday {
    final meals = LocalStorageService.loadMealsForDate(DateTime.now());
    return meals.fold(0, (sum, m) => sum + m.totalCalories);
  }

  Future<void> _export() async {
    setState(() => _working = true);
    try {
      await LocalStorageService.exportBackup();
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _import() async {
    setState(() => _working = true);
    try {
      final ok = await LocalStorageService.importBackup();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? 'Backup restaurado! Reinicie o app pra ver os dados.'
              : 'Nenhum arquivo selecionado.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final DailyTargets? targets = LocalStorageService.loadTargets();
    final consumed = _consumedToday;
    final target = targets?.calories ?? 0;
    final remaining = target - consumed;
    final progress = target > 0 ? (consumed / target).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Hoje')),
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
                            ? (remaining >= 0
                                ? '$remaining kcal restantes'
                                : '${-remaining} kcal acima da meta')
                            : 'Meta não calculada',
                        style: TextStyle(
                          color: remaining < 0 ? AppColors.danger : AppColors.textSecondary,
                        ),
                      ),
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
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Backup dos dados', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  const Text(
                    'Seus dados ficam salvos só neste aparelho. Exporte um '
                    'backup de vez em quando pra não perder nada ao trocar '
                    'de celular.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _working ? null : _export,
                          icon: const Icon(Icons.upload_rounded),
                          label: const Text('Exportar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _working ? null : _import,
                          icon: const Icon(Icons.download_rounded),
                          label: const Text('Importar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
