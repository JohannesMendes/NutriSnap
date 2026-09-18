import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/user_profile_service.dart';
import 'paywall/paywall_screen.dart';
import 'paywall/blocked_account_screen.dart';

/// Fica entre o login e o resto do app: escuta o documento de perfil do
/// usuário no Firestore em tempo real e decide o que mostrar:
///   - bloqueado -> BlockedAccountScreen (não dá pra usar o app)
///   - trial vencido (>15 dias) -> PaywallScreen (precisa assinar)
///   - ilimitado/admin/plano pago/trial ainda válido -> libera [child]
///
/// Como é um Stream, qualquer mudança no Firestore (assinatura confirmada,
/// admin liberando a conta, etc.) reflete na hora, sem precisar reabrir o
/// app.
class LicenseGate extends StatelessWidget {
  final Widget child;
  const LicenseGate({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) {
      // Não deveria acontecer (LicenseGate só é montado com usuário
      // logado), mas por segurança não deixa passar sem sessão válida.
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return StreamBuilder(
      stream: UserProfileService.watchProfile(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }

        final profile = snapshot.data;
        if (profile == null) {
          // Conta autenticada mas sem documento de perfil ainda — pode
          // acontecer em contas criadas antes dessa funcionalidade existir,
          // ou se a criação do doc falhou no cadastro. Cria agora
          // (auto-cura) com o trial de 15 dias começando a partir de hoje.
          UserProfileService.createProfileIfNeeded(uid);
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }

        if (profile.bloqueado) return const BlockedAccountScreen();
        if (!profile.hasAccess) return const PaywallScreen();
        return child;
      },
    );
  }
}
