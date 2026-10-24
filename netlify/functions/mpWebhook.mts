// Webhook do Mercado Pago: é chamado quando um pagamento muda de status.
//
// Segurança em 3 camadas antes de liberar qualquer plano:
//   1. confere a assinatura (x-signature) com o segredo do webhook;
//   2. NÃO confia no corpo do aviso — consulta o pagamento direto na API
//      do Mercado Pago;
//   3. confere se o valor pago bate com o plano cobrado e se aquele
//      pagamento ainda não foi processado (não libera duas vezes).

import type { Config } from '@netlify/functions';
import { createHmac, timingSafeEqual } from 'node:crypto';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { db } from '../lib/firebase.mts';
import { PLANS } from '../lib/plans.mts';

const STATUS_MAP: Record<string, string> = {
  approved: 'aprovado',
  pending: 'pendente',
  in_process: 'pendente',
  authorized: 'pendente',
  rejected: 'rejeitado',
  cancelled: 'cancelado',
  expired: 'expirado',
  refunded: 'reembolsado',
  charged_back: 'estornado',
};

// Quem já tem acesso especial não pode ter o plano rebaixado por um pagamento.
const PROTECTED_PLANS = ['admin', 'ilimitado'];

function validSignature(req: Request, dataId: string, secret: string) {
  const header = req.headers.get('x-signature') || '';
  const requestId = req.headers.get('x-request-id') || '';
  let ts = '';
  let v1 = '';
  for (const part of header.split(',')) {
    const [k, v] = part.split('=').map((s) => s.trim());
    if (k === 'ts') ts = v;
    if (k === 'v1') v1 = v;
  }
  if (!ts || !v1) return false;

  let manifest = '';
  if (dataId) manifest += `id:${dataId.toLowerCase()};`;
  if (requestId) manifest += `request-id:${requestId};`;
  manifest += `ts:${ts};`;

  const expected = createHmac('sha256', secret).update(manifest).digest('hex');
  const a = Buffer.from(expected);
  const b = Buffer.from(v1);
  return a.length === b.length && timingSafeEqual(a, b);
}

export default async (req: Request) => {
  const secret = Netlify.env.get('MP_WEBHOOK_SECRET');
  const mpToken = Netlify.env.get('MP_ACCESS_TOKEN');
  if (!secret || !mpToken) {
    console.error('MP_WEBHOOK_SECRET ou MP_ACCESS_TOKEN não configurados.');
    return new Response('config', { status: 500 });
  }

  const url = new URL(req.url);
  const body: any = await req.json().catch(() => ({}));
  const dataId = String(url.searchParams.get('data.id') ?? body?.data?.id ?? '');
  const type = String(url.searchParams.get('type') ?? body?.type ?? url.searchParams.get('topic') ?? '');

  if (!validSignature(req, url.searchParams.get('data.id') ?? '', secret)) {
    console.warn('Assinatura inválida no webhook do Mercado Pago.');
    return new Response('invalid signature', { status: 401 });
  }
  if (type !== 'payment' || !dataId) return new Response('ignored', { status: 200 });

  // Consulta o pagamento direto no Mercado Pago (fonte da verdade).
  const res = await fetch(`https://api.mercadopago.com/v1/payments/${encodeURIComponent(dataId)}`, {
    headers: { Authorization: `Bearer ${mpToken}` },
    signal: AbortSignal.timeout(20000),
  });
  if (res.status === 404) return new Response('payment not found', { status: 200 }); // ex.: notificação de teste
  if (!res.ok) {
    console.error('Erro ao consultar pagamento', res.status, await res.text());
    return new Response('mp error', { status: 500 }); // o Mercado Pago tenta de novo
  }
  const pay: any = await res.json();
  const docId = pay.external_reference;
  if (!docId) return new Response('no reference', { status: 200 });

  const payRef = db().collection('pagamentos').doc(String(docId));

  try {
    await db().runTransaction(async (tx) => {
      const snap = await tx.get(payRef);
      if (!snap.exists) return;
      const p = snap.data()!;

      if (p.status === 'aprovado') return; // já processado: não libera duas vezes
      if (String(pay.id) !== p.mp_payment_id) return; // não é o pagamento que a gente criou

      if (pay.status !== 'approved') {
        tx.update(payRef, { status: STATUS_MAP[pay.status] ?? 'pendente', atualizado_em: FieldValue.serverTimestamp() });
        return;
      }

      const plan = PLANS[p.plano_id];
      if (!plan || Number(pay.transaction_amount) !== p.valor || pay.currency_id !== 'BRL') {
        console.error('Pagamento aprovado, mas valor/plano não bate', pay.id, pay.transaction_amount, p.valor);
        tx.update(payRef, { status: 'valor_divergente', atualizado_em: FieldValue.serverTimestamp() });
        return;
      }

      const userRef = db().collection('usuarios').doc(p.uid);
      const userSnap = await tx.get(userRef);
      const user = userSnap.data() ?? {};

      if (PROTECTED_PLANS.includes(user.tipo_plano)) {
        // Conta admin/ilimitada: só registra o pagamento, não mexe no plano.
        tx.update(payRef, { status: 'aprovado', aprovado_em: FieldValue.serverTimestamp(), plano_alterado: false });
        return;
      }

      // Renovação antecipada soma ao tempo que ainda resta.
      const current: Date | undefined = user.plano_expira_em?.toDate?.();
      const base = current && current.getTime() > Date.now() ? current : new Date();
      const newExpiry = new Date(base.getTime() + plan.days * 24 * 60 * 60 * 1000);

      tx.set(
        userRef,
        {
          tipo_plano: p.plano_id,
          plano_expira_em: Timestamp.fromDate(newExpiry),
          assinatura_ativada_em: FieldValue.serverTimestamp(),
          ultimo_pagamento_id: String(pay.id),
        },
        { merge: true },
      );
      tx.update(payRef, { status: 'aprovado', aprovado_em: FieldValue.serverTimestamp(), plano_alterado: true });
    });
  } catch (err) {
    console.error('Falha ao processar o pagamento', err);
    return new Response('error', { status: 500 }); // tenta de novo
  }

  return new Response('ok', { status: 200 });
};

export const config: Config = {
  path: '/api/mpWebhook',
};
