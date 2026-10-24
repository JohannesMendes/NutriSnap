// Porteiro do backend: antes de gastar qualquer centavo com a IA, confere
//   1. se quem chama é um usuário logado de verdade (token do Firebase);
//   2. se a conta está ativa (não bloqueada, trial/plano dentro da validade);
//   3. se ainda não estourou o limite diário de usos.
//
// Sem isso, qualquer pessoa que descobrisse a URL do backend (ela fica
// dentro do APK) poderia usar a sua chave do Gemini e a fatura chegaria
// pra você.

import { adminAuth, db } from './firebase.mts';

const TRIAL_DAYS = 15; // mantenha igual a kTrialDurationDays (lib/config/plans_config.dart)
const FULL_ACCESS_PLANS = ['admin', 'ilimitado'];
const DAY_MS = 24 * 60 * 60 * 1000;

export type GuardResult =
  | { ok: true; uid: string }
  | { ok: false; status: number; code: string; message: string };

const fail = (status: number, code: string, message: string): GuardResult => ({ ok: false, status, code, message });

export async function guardRequest(req: Request): Promise<GuardResult> {
  // 1) Token de login
  const idToken = (req.headers.get('authorization') || '').replace(/^Bearer\s+/i, '');
  if (!idToken) return fail(401, 'unauthenticated', 'Faça login para usar a IA.');
  let uid: string;
  try {
    uid = (await adminAuth().verifyIdToken(idToken)).uid;
  } catch {
    return fail(401, 'unauthenticated', 'Sessão inválida. Entre na conta de novo.');
  }

  // 2) Conta ativa
  const userSnap = await db().collection('usuarios').doc(uid).get();
  const user = userSnap.data();
  if (!user) return fail(403, 'plan_inactive', 'Conta não encontrada.');
  if (user.bloqueado === true) return fail(403, 'blocked', 'Conta bloqueada.');

  const plan: string = user.tipo_plano ?? 'trial';
  if (!FULL_ACCESS_PLANS.includes(plan)) {
    if (plan === 'trial') {
      const created: Date | undefined = user.data_criacao?.toDate?.();
      const daysElapsed = created ? Math.floor((Date.now() - created.getTime()) / DAY_MS) : 0;
      if (daysElapsed > TRIAL_DAYS) return fail(403, 'plan_inactive', 'Período de testes encerrado.');
    } else {
      const expires: Date | undefined = user.plano_expira_em?.toDate?.();
      if (expires && expires.getTime() < Date.now()) return fail(403, 'plan_inactive', 'Plano expirado.');
    }
  }

  // 3) Limite diário por usuário (admin fica de fora)
  if (plan !== 'admin') {
    const limit = Number(Netlify.env.get('DAILY_LIMIT')) || 120;
    const day = new Date(Date.now() - 3 * 60 * 60 * 1000).toISOString().slice(0, 10); // dia no horário de Brasília
    const ref = db().collection('uso').doc(`${uid}_${day}`);
    try {
      const allowed = await db().runTransaction(async (tx) => {
        const snap = await tx.get(ref);
        const count = (snap.data()?.count as number | undefined) ?? 0;
        if (count >= limit) return false;
        tx.set(ref, { uid, dia: day, count: count + 1 });
        return true;
      });
      if (!allowed) return fail(429, 'daily_limit', 'Limite diário de análises atingido. Volte amanhã.');
    } catch (err) {
      console.error('Falha ao contar uso diário', err);
      return fail(503, 'usage_unavailable', 'Serviço temporariamente indisponível. Tente de novo.');
    }
  }

  return { ok: true, uid };
}
