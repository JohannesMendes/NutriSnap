import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/local_storage_service.dart';

/// Tela inicial: resumo do dia + acesso ao backup manual.
/// Nas próximas entregas entram aqui: diário de refeições, contador de água,
/// registro por foto (IA) e notificações.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _working = false;

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
                  Text('Resumo do dia',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  const Text(
                    'Diário de refeições, contador de água e registro por foto '
                    'com IA chegam na próxima atualização.',
                    style: TextStyle(color: AppColors.textSecondary),
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
                  Text('Backup dos dados',
                      style: Theme.of(context).textTheme.titleMedium),
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
