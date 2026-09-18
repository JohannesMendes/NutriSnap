import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../config/plans_config.dart';
import '../../services/auth_service.dart';
import '../../services/user_profile_service.dart';

/// Paywall mostrada quando o trial de 15 dias expira (ou pra quem quiser
/// assinar antes disso, se você chamar essa tela de outro lugar). Os 3
/// planos vêm de `kSubscriptionPlans` (lib/config/plans_config.dart) — pra
/// mudar preço/desconto/destaque, mexa só lá, não aqui.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  late String _selectedPlanId;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Plano em destaque pré-selecionado, se existir; senão o primeiro.
    final highlighted = kSubscriptionPlans.where((p) => p.highlight).toList();
    _selectedPlanId = (highlighted.isNotEmpty ? highlighted.first : kSubscriptionPlans.first).id;
  }

  Future<void> _subscribe() async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return;
    setState(() => _isSubmitting = true);
    try {
      // Aqui é onde entraria a integração real de pagamento (Stripe, Play
      // Billing, etc.) antes de liberar o acesso. Por enquanto, simula a
      // confirmação e já atualiza o plano no Firestore — o LicenseGate
      // libera o app automaticamente assim que o documento muda.
      await UserProfileService.activatePlan(uid, _selectedPlanId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Assinatura confirmada! Aproveite o NutriSnap 🎉')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível confirmar a assinatura. Tente novamente.')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          children: [
            const Icon(Icons.lock_clock_rounded, size: 48, color: AppColors.primary),
            const SizedBox(height: 16),
            const Text(
              'Seu período de testes acabou',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Assine um plano pra continuar registrando suas refeições, água '
              'e acompanhando sua evolução no NutriSnap.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 24),
            for (final plan in kSubscriptionPlans) ...[
              _PlanCard(
                plan: plan,
                selected: _selectedPlanId == plan.id,
                onTap: () => setState(() => _selectedPlanId = plan.id),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _subscribe,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.black),
                    )
                  : const Text('Assinar agora'),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: AppColors.surface,
                      title: const Text('Sair da conta?'),
                      content: const Text('Você pode entrar de novo quando quiser assinar.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
                        ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Sair')),
                      ],
                    ),
                  );
                  if (confirmed == true) await AuthService.signOut();
                },
                child: const Text('Sair da conta', style: TextStyle(color: AppColors.textSecondary)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final bool selected;
  final VoidCallback onTap;
  const _PlanCard({required this.plan, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? AppColors.primary
        : (plan.highlight ? AppColors.primary.withOpacity(0.4) : AppColors.surfaceLight);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: selected ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(plan.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                if (plan.badgeLabel != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: plan.highlight ? AppColors.primary : AppColors.secondary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      plan.badgeLabel!,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ),
                ],
                const Spacer(),
                if (plan.originalPriceLabel != null)
                  Text(
                    plan.originalPriceLabel!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(plan.priceLabel, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(width: 4),
                Text(plan.periodLabel, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
            if (plan.features.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...plan.features.map(
                (f) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_rounded, size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Expanded(child: Text(f, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary))),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
