// Cria uma cobrança Pix no Mercado Pago pra um plano do NutriSnap.
//
// App -> POST /api/createPayment  { planId }   (header Authorization: Bearer <idToken do Firebase>)
// Resposta -> { paymentDocId, qrCode, qrCodeBase64, expiresAt, amount }
//
// O plano só é liberado depois, quando o Mercado Pago avisa o webhook
// (netlify/functions/mpWebhook.mts) que o Pix foi pago.

import type { Config } from '@netlify/functions';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { adminAuth, db } from '../lib/firebase.mts';
import { PLANS } from '../lib/plans.mts';

const PIX_VALIDITY_MINUTES = 30;

function json(body: Record<string, unknown>, status = 200) {
  return Response.json(body, { status });
}

// O Mercado Pago quer a data de expiração com fuso, ex.: 2026-10-20T12:00:00.000-03:00
function toMpDate(d: Date) {
  const br = new Date(d.getTime() - 3 * 60 * 60 * 1000);
  return br.toISOString().replace('Z', '-03:00');
}

export default async (req: Request) => {
  if (req.method !== 'POST') return json({ message: 'Método não permitido.' }, 405);

  const mpToken = Netlify.env.get('MP_ACCESS_TOKEN');
  if (!mpToken) return json({ message: 'Pagamento indisponível no momento.' }, 500);

  // 1) Quem está pedindo? (token de login do Firebase)
  const idToken = (req.headers.get('authorization') || '').replace(/^Bearer\s+/i, '');
  if (!idToken) return json({ message: 'Faça login para continuar.' }, 401);
  let uid: string;
  let email: string | undefined;
  try {
    const decoded = await adminAuth().verifyIdToken(idToken);
    uid = decoded.uid;
    email = decoded.email;
  } catch {
    return json({ message: 'Sessão inválida. Entre na conta de novo.' }, 401);
  }
  if (!email) return json({ message: 'Sua conta precisa ter um e-mail para pagar com Pix.' }, 400);

  // 2) Qual plano? O preço vem do servidor, nunca do app.
  const body = await req.json().catch(() => ({}));
  const plan = PLANS[String((body as any)?.planId)];
  if (!plan) return json({ message: 'Plano inválido.' }, 400);

  // 3) Registra a tentativa e cria o Pix no Mercado Pago.
  const ref = db().collection('pagamentos').doc();
  await ref.set({
    uid,
    plano_id: (body as any).planId,
    valor: plan.amount,
    status: 'criando',
    criado_em: FieldValue.serverTimestamp(),
  });

  const siteUrl = Netlify.env.get('PUBLIC_BASE_URL') || Netlify.env.get('URL') || '';
  const expires = new Date(Date.now() + PIX_VALIDITY_MINUTES * 60 * 1000);

  let mp: any;
  try {
    const res = await fetch('https://api.mercadopago.com/v1/payments', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${mpToken}`,
        'Content-Type': 'application/json',
        'X-Idempotency-Key': ref.id,
      },
      body: JSON.stringify({
        transaction_amount: plan.amount,
        description: `NutriSnap - Plano ${plan.title}`,
        payment_method_id: 'pix',
        payer: { email },
        external_reference: ref.id,
        notification_url: `${siteUrl}/api/mpWebhook`,
        date_of_expiration: toMpDate(expires),
      }),
      signal: AbortSignal.timeout(20000),
    });
    const text = await res.text();
    if (!res.ok) {
      console.error('Mercado Pago recusou a criação do Pix', res.status, text);
      await ref.update({ status: 'erro', erro: text.slice(0, 500) });
      return json({ message: 'Não foi possível gerar o Pix agora. Tente de novo em instantes.' }, 502);
    }
    mp = JSON.parse(text);
  } catch (err) {
    console.error('Falha ao falar com o Mercado Pago', err);
    await ref.update({ status: 'erro', erro: String((err as Error)?.message || err).slice(0, 500) });
    return json({ message: 'Não foi possível gerar o Pix agora. Tente de novo em instantes.' }, 502);
  }

  const pix = mp?.point_of_interaction?.transaction_data;
  if (!pix?.qr_code) {
    console.error('Resposta do Mercado Pago sem QR code', JSON.stringify(mp).slice(0, 500));
    await ref.update({ status: 'erro', erro: 'resposta sem qr_code' });
    return json({ message: 'Não foi possível gerar o Pix agora. Tente de novo em instantes.' }, 502);
  }

  await ref.update({
    status: 'pendente',
    mp_payment_id: String(mp.id),
    expira_em: Timestamp.fromDate(expires),
  });

  return json({
    paymentDocId: ref.id,
    qrCode: pix.qr_code,
    qrCodeBase64: pix.qr_code_base64 ?? '',
    expiresAt: expires.toISOString(),
    amount: plan.amount,
  });
};

export const config: Config = {
  path: '/api/createPayment',
};
