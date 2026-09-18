import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/user_profile_service.dart';
import '../admin/admin_approval_screen.dart';
import '../paywall/paywall_screen.dart';

/// Aba/tela de Perfil: mostra os dados da conta e o status da
/// assinatura em tempo real (mesmo StreamBuilder do LicenseGate, então
/// qualquer mudança feita pelo admin no Firestore ou uma assinatura
/// confirmada aparece aqui na hora, sem precisar reabrir o app).
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    final uid = user?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: uid == null
          ? const Center(child: Text('Nenhuma conta autenticada.'))
          : StreamBuilder<AccountStatus?>(
              stream: UserProfileService.watchProfile(uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Não foi possível carregar seu perfil.\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  );
                }

                final profile = snapshot.data;

                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _AccountCard(email: user?.email),
                    const SizedBox(height: 20),
                    if (profile == null)
                      const _LoadingPlanCard()
                    else
                      _PlanCard(profile: profile),
                    if (profile != null && profile.isAdmin) ...[
                      const SizedBox(height: 20),
                      const _AdminPanelCard(),
                    ],
                  ],
                );
              },
            ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final String? email;
  const _AccountCard({required this.email});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: AppColors.surfaceLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sua conta',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  email ?? 'E-mail não disponível',
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Só aparece pra contas com `tipo_plano == 'admin'` — atalho pro painel
/// de aprovações de pagamento manual (ver AdminApprovalScreen).
class _AdminPanelCard extends StatelessWidget {
  const _AdminPanelCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.secondary, width: 1.2),
      ),
      child: Row(
        children: [
          const Icon(Icons.admin_panel_settings_rounded, color: AppColors.secondary),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Aprovações pendentes',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdminApprovalScreen()),
            ),
            child: const Text('Abrir'),
          ),
        ],
      ),
    );
  }
}

class _LoadingPlanCard extends StatelessWidget {
  const _LoadingPlanCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18)),
      child: const Row(
        children: [
          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.primary)),
          SizedBox(width: 12),
          Text('Carregando plano...', style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

/// Cartão com o status da assinatura: nome do plano, selo de acesso
/// total (admin/ilimitado), contador de dias restantes (trial) e o
/// botão de gerenciar/mudar de plano.
class _PlanCard extends StatelessWidget {
  final AccountStatus profile;
  const _PlanCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final isFullAccess = profile.isUnlimited; // admin OU ilimitado
    final daysRemaining = profile.daysRemaining;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: isFullAccess ? Border.all(color: AppColors.secondary, width: 1.4) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Plano atual', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const Spacer(),
              if (isFullAccess)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.verified_rounded, size: 14, color: Colors.black),
                      SizedBox(width: 4),
                      Text(
                        'Acesso total',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            profile.planDisplayName,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (isFullAccess)
            const Text(
              'Sua conta tem acesso irrestrito a todos os recursos do NutriSnap, '
              'sem limite de uso e sem cobrança.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
            )
          else if (daysRemaining != null)
            _DaysRemainingRow(daysRemaining: daysRemaining, expired: profile.isTrialExpired)
          else
            const Text(
              'Assinatura ativa — renovação automática, sem necessidade de ação.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
            ),
          if (!isFullAccess) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PaywallScreen()),
                ),
                icon: const Icon(Icons.workspace_premium_rounded),
                label: Text(profile.isTrial ? 'Ver planos e assinar' : 'Gerenciar / mudar de plano'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DaysRemainingRow extends StatelessWidget {
  final int daysRemaining;
  final bool expired;
  const _DaysRemainingRow({required this.daysRemaining, required this.expired});

  @override
  Widget build(BuildContext context) {
    final color = expired || daysRemaining <= 3 ? AppColors.danger : AppColors.primary;
    return Row(
      children: [
        Icon(Icons.timer_outlined, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          expired
              ? 'Seu período de testes acabou'
              : '$daysRemaining ${daysRemaining == 1 ? 'dia restante' : 'dias restantes'} de teste grátis',
          style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
