import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../config/plans_config.dart';
import '../../models/payment_request.dart';
import '../../services/payment_request_service.dart';

/// Painel só pra contas com `tipo_plano == 'admin'` (ver ProfileScreen,
/// que é quem mostra o link pra essa tela). Lista as solicitações de
/// "já paguei" pendentes — nome, e-mail, plano escolhido e o nome usado
/// na conta do PIX — pro admin conferir no banco e aprovar ou rejeitar
/// com um toque, sem precisar mexer no Console do Firestore na mão.
class AdminApprovalScreen extends StatelessWidget {
  const AdminApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Aprovações pendentes')),
      body: StreamBuilder<List<PaymentRequest>>(
        stream: PaymentRequestService.watchPending(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Não foi possível carregar as solicitações.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            );
          }

          final requests = snapshot.data ?? [];
          if (requests.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nenhuma solicitação pendente no momento.',
                  style: TextStyle(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _RequestCard(request: requests[index]),
          );
        },
      ),
    );
  }
}

class _RequestCard extends StatefulWidget {
  final PaymentRequest request;
  const _RequestCard({required this.request});

  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  bool _isProcessing = false;

  Future<void> _respond(Future<void> Function() action) async {
    setState(() => _isProcessing = true);
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível concluir: $e')),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final plan = subscriptionPlanById(request.planoId);
    final dateLabel = _formatDate(request.criadoEm);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            request.nome.isNotEmpty ? request.nome : '(sem nome cadastrado)',
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            request.email ?? '(sem e-mail)',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          _InfoRow(label: 'Plano', value: plan != null ? '${plan.title} — ${plan.priceLabel}${plan.periodLabel}' : request.planoId),
          const SizedBox(height: 6),
          _InfoRow(label: 'Nome no PIX', value: request.nomeContaPagamento),
          const SizedBox(height: 6),
          _InfoRow(label: 'Enviado em', value: dateLabel),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isProcessing ? null : () => _respond(() => PaymentRequestService.reject(request)),
                  child: const Text('Rejeitar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : () => _respond(() => PaymentRequestService.approve(request)),
                  child: _isProcessing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.black),
                        )
                      : const Text('Aprovar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Formata sem depender do pacote `intl` (não presente no projeto) —
/// ex.: "18/09/2026 14:05".
String _formatDate(DateTime date) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year} ${two(date.hour)}:${two(date.minute)}';
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
