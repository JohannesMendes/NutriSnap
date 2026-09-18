import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';

/// Tela fixa de bloqueio: aparece quando a versão instalada é menor que a
/// versão mínima exigida (ver ForceUpdateService). Não tem botão de
/// voltar, não fecha com o gesto/botão físico de voltar do Android
/// (PopScope canPop: false) e não some sozinha — o único jeito de sair
/// daqui é abrir a loja e instalar a atualização (o app precisa ser
/// reaberto depois, o que refaz a checagem).
class ForceUpdateScreen extends StatelessWidget {
  final String updateUrl;
  const ForceUpdateScreen({super.key, required this.updateUrl});

  Future<void> _openStore(BuildContext context) async {
    if (updateUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link de atualização não configurado. Procure "NutriSnap" na loja de apps.')),
      );
      return;
    }
    final uri = Uri.tryParse(updateUrl);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o link de atualização.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Impede que o botão de voltar do Android (ou o gesto) feche essa
      // tela — o bloqueio precisa ser inevitável.
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.system_update_rounded, size: 56, color: AppColors.primary),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Atualização obrigatória',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Uma nova versão do NutriSnap está disponível e é '
                    'necessária pra continuar usando o app. Atualize agora '
                    'pra não perder nenhuma novidade ou correção.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _openStore(context),
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Atualizar agora'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
