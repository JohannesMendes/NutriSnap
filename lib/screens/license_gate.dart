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
class LicenseGate extends StatefulWidget {
  final Widget child;
  const LicenseGate({super.key, required this.child});

  @override
  State<LicenseGate> createState() => _LicenseGateState();
}

class _LicenseGateState extends State<LicenseGate> {
  // Evita chamar createProfileIfNeeded de novo a cada rebuild enquanto o
  // documento ainda não existe/chega — antes isso rodava sem parar.
  bool _creatingProfile = false;

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
        if (snapshot.hasError) {
          // Antes ficava preso na bolinha de carregar pra sempre (ex.:
          // Firestore sem banco criado, ou regras de segurança bloqueando
          // a leitura) sem dar nenhuma pista do que houve.
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'Não foi possível carregar seu perfil.',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => setState(() {}),
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

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
          if (!_creatingProfile) {
            _creatingProfile = true;
            UserProfileService.createProfileIfNeeded(uid).catchError((e) {
              // Se der erro aqui de novo (ex.: Firestore sem permissão),
              // libera a tentativa seguinte em vez de travar mudo.
              _creatingProfile = false;
              if (mounted) setState(() {});
            });
          }
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }

        if (profile.bloqueado) return const BlockedAccountScreen();
        if (!profile.hasAccess) return const PaywallScreen();
        return widget.child;
      },
    );
  }
}
