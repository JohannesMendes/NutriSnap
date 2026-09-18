/// Configuração central da tela de assinaturas (paywall). Mude preços,
/// títulos, descrições e destaque por aqui — a tela visual
/// (paywall_screen.dart) só lê essa lista, nunca precisa ser mexida pra
/// ajustar valores ou textos.
///
/// `id` é o valor gravado no Firestore (`tipo_plano`) quando o usuário
/// assina — mantenha estável mesmo se mudar o `title` depois, senão
/// assinaturas já ativas perdem a referência de qual plano é.
class SubscriptionPlan {
  final String id;
  final String title;
  final String priceLabel;
  final String periodLabel;
  final String? originalPriceLabel; // preço "de", riscado — opcional
  final String? badgeLabel; // ex: "Mais vantajoso", "-20%"
  final bool highlight; // dá destaque visual ao card (borda/cor diferente)
  final List<String> features;

  const SubscriptionPlan({
    required this.id,
    required this.title,
    required this.priceLabel,
    required this.periodLabel,
    this.originalPriceLabel,
    this.badgeLabel,
    this.highlight = false,
    this.features = const [],
  });
}

/// Lista exibida na paywall, nessa ordem. Os valores de exemplo pedidos:
/// semanal R$10, mensal e anual configuráveis (com desconto no anual).
const List<SubscriptionPlan> kSubscriptionPlans = [
  SubscriptionPlan(
    id: 'semanal',
    title: 'Semanal',
    priceLabel: 'R\$ 10,00',
    periodLabel: '/semana',
    features: [
      'Scanner de foto por IA ilimitado',
      'Diário e histórico completos',
      'Lembretes de refeição e água',
    ],
  ),
  SubscriptionPlan(
    id: 'mensal',
    title: 'Mensal',
    priceLabel: 'R\$ 29,90',
    periodLabel: '/mês',
    originalPriceLabel: 'R\$ 40,00',
    badgeLabel: '-25%',
    features: [
      'Tudo do plano Semanal',
      'Economize comparado ao semanal',
    ],
  ),
  SubscriptionPlan(
    id: 'anual',
    title: 'Anual',
    priceLabel: 'R\$ 199,90',
    periodLabel: '/ano',
    originalPriceLabel: 'R\$ 358,80',
    badgeLabel: 'Mais vantajoso',
    highlight: true,
    features: [
      'Tudo do plano Mensal',
      'Equivale a R\$ 16,66/mês',
      'Melhor custo-benefício',
    ],
  ),
];

/// Duração do período de teste gratuito, em dias, contada a partir de
/// `data_criacao` (gravado no Firestore no momento do cadastro).
const int kTrialDurationDays = 15;
