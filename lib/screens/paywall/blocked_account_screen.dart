import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';

/// Mostrada quando `bloqueado: true` no documento do usuário no Firestore
/// — bloqueio manual (ex: suporte/admin desativou a conta), diferente do
/// trial expirado (que vai pra PaywallScreen). Não tem como "assinar"
/// pra sair daqui — só sair da conta e falar com o suporte.
class BlockedAccountScreen extends StatelessWidget {
  const BlockedAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
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
                  const Icon(Icons.block_rounded, size: 56, color: AppColors.danger),
                  const SizedBox(height: 24),
                  const Text(
                    'Conta bloqueada',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Sua conta foi bloqueada. Entre em contato com o suporte '
                    'pra mais informações.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 28),
                  OutlinedButton(onPressed: AuthService.signOut, child: const Text('Sair da conta')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
