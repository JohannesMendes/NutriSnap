/// Configuração central da tela de assinaturas (paywall). Mude preços,
/// títulos, descrições e destaque por aqui — a tela visual
/// (paywall_screen.dart) só lê essa lista, nunca precisa ser mexida pra
/// ajustar valores ou textos.
///
/// `id` é o valor gravado no Firestore (`tipo_plano`) quando o usuário
/// assina — mantenha estável mesmo se mudar o `title`/nome comercial
/// depois, senão assinaturas já ativas perdem a referência de qual plano
/// é. Por isso os ids continuam `semanal`/`mensal`/`anual` mesmo com os
/// nomes comerciais novos (Prata/Ouro/Diamante) — só a exibição mudou.
class SubscriptionPlan {
  final String id;
  final String title; // nome comercial exibido (Prata, Ouro, Diamante)
  final String priceLabel;
  final String periodLabel;
  final String? originalPriceLabel; // preço "de", riscado — opcional
  final String? badgeLabel; // ex: "Mais Vantajoso", "-20%"
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

/// Lista exibida na paywall, nessa ordem — estratégia de ancoragem de
/// preços: o Prata (semanal) aparece primeiro com o valor "por semana"
/// alto de propósito, fazendo o Ouro (mensal) parecer uma economia óbvia
/// e o Diamante (anual) parecer o melhor negócio de todos.
///
///   - Prata    (semanal): R$ 6,90/semana  -> ancoragem alta
///   - Ouro     (mensal):  R$ 12,90/mês    -> bem mais barato que
///     assinar o Prata 4x seguidas no mês (R$ 27,60)
///   - Diamante (anual):   R$ 99,90/ano   -> equivale a ~R$ 8,33/mês,
///     o mais vantajoso de todos, com badge e destaque visual maiores
const List<SubscriptionPlan> kSubscriptionPlans = [
  SubscriptionPlan(
    id: 'semanal',
    title: 'Prata',
    priceLabel: 'R\$ 6,90',
    periodLabel: '/semana',
    features: [
      'Scanner de foto por IA ilimitado',
      'Diário e histórico completos',
      'Lembretes de refeição e água',
    ],
  ),
  SubscriptionPlan(
    id: 'mensal',
    title: 'Ouro',
    priceLabel: 'R\$ 12,90',
    periodLabel: '/mês',
    badgeLabel: 'Economize vs. semanal',
    features: [
      'Tudo do plano Prata',
      'Sai bem mais em conta que 4 semanas do Prata',
    ],
  ),
  SubscriptionPlan(
    id: 'anual',
    title: 'Diamante',
    priceLabel: 'R\$ 99,90',
    periodLabel: '/ano',
    badgeLabel: 'Mais Vantajoso',
    highlight: true,
    features: [
      'Tudo do plano Ouro',
      'Equivale a R\$ 8,33/mês',
      'Melhor custo-benefício de todos os planos',
    ],
  ),
];

/// Duração do período de teste gratuito, em dias, contada a partir de
/// `data_criacao` (gravado no Firestore no momento do cadastro).
const int kTrialDurationDays = 15;

/// Busca os dados completos do plano (nome comercial, preço etc.) a
/// partir do `id` salvo no Firestore. Retorna null se o id não bater com
/// nenhum plano pago cadastrado (ex.: 'trial', 'ilimitado', 'admin').
SubscriptionPlan? subscriptionPlanById(String id) {
  for (final plan in kSubscriptionPlans) {
    if (plan.id == id) return plan;
  }
  return null;
}
