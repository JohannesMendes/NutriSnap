// Firebase Admin: só roda no servidor (Netlify). Usa uma conta de serviço
// guardada em variáveis de ambiente — nunca vai pro app nem pro GitHub.
import { initializeApp, getApps, cert } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { getAuth } from 'firebase-admin/auth';

function init() {
  if (getApps().length > 0) return;
  const projectId = Netlify.env.get('FIREBASE_PROJECT_ID');
  const clientEmail = Netlify.env.get('FIREBASE_CLIENT_EMAIL');
  const privateKey = Netlify.env.get('FIREBASE_PRIVATE_KEY');
  if (!projectId || !clientEmail || !privateKey) {
    throw new Error('Variáveis do Firebase ausentes no Netlify (FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, FIREBASE_PRIVATE_KEY).');
  }
  initializeApp({
    credential: cert({
      projectId,
      clientEmail,
      // No Netlify a chave costuma ficar com "\n" literal: converte pra quebra de linha real.
      privateKey: privateKey.replace(/\\n/g, '\n'),
    }),
  });
}

export function db() {
  init();
  return getFirestore();
}

export function adminAuth() {
  init();
  return getAuth();
}
