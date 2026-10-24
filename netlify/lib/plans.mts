// Tabela de planos usada PELO SERVIDOR. É a fonte da verdade do preço e da
// duração: o app só manda o id do plano ("semanal", "mensal" ou "anual") e
// o servidor decide quanto cobrar — assim ninguém consegue pagar menos
// alterando o app.
//
// ⚠️ Se mudar um preço, mude também em lib/config/plans_config.dart
// (que é só o texto exibido na tela).
export const PLANS: Record<string, { title: string; amount: number; days: number }> = {
  semanal: { title: 'Prata (semanal)', amount: 6.9, days: 7 },
  mensal: { title: 'Ouro (mensal)', amount: 12.9, days: 30 },
  anual: { title: 'Diamante (anual)', amount: 99.9, days: 365 },
};
