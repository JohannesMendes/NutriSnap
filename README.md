# NutriSnap 🥗

App mobile de evolução e nutrição inteligente, 100% gratuito, com calculadora
de metas, diário de refeições e registro de alimentos por foto (IA).

## Status atual

✅ Login e cadastro (Firebase Auth)
✅ Calculadora de metas diárias (calorias, macros e água)
⏳ Diário de refeições, contador de água, registro por foto com IA e
notificações — próximas entregas.

## Como subir isso pro seu GitHub (sem terminal)

1. Extraia o .zip que o Claude te mandou.
2. No repositório **NutriSnap** que você criou no GitHub, clique em
   **"Add file" → "Upload files"**.
3. Arraste **todo o conteúdo** da pasta extraída (incluindo a pasta oculta
   `.github`) pra dentro da janela do navegador.
4. Clique em **"Commit changes"**.

> ⚠️ Atenção: pastas que começam com ponto (como `.github`) às vezes ficam
> escondidas no seu explorador de arquivos. Ative "mostrar arquivos ocultos"
> no Windows/Mac antes de arrastar, senão o workflow do Actions não sobe.

## Configurar o Firebase (sem precisar de terminal)

1. Acesse https://console.firebase.google.com → **"Adicionar projeto"** →
   nomeie como quiser (ex: "NutriSnap").
2. Dentro do projeto, clique no ícone do **Android** pra adicionar um app.
3. Nome do pacote: `com.nutrisnap.app` (tem que bater com o que o Actions vai
   gerar — já deixei configurado assim no workflow).
4. Baixe o arquivo **`google-services.json`** que o Firebase oferece e coloque
   ele em `android/app/google-services.json` no seu repositório (depois que o
   Actions rodar a primeira vez e criar a pasta `android/`, ou peça pro Claude
   gerar essa pasta antes).
5. Ainda no Console, vá em **Configurações do projeto → Geral** e copie os
   valores (API Key, App ID, Sender ID, Project ID, Storage Bucket).
6. Abra `lib/firebase_options.dart` no repositório e cole cada valor no lugar
   de `COLE_AQUI_...`.
7. No Console, ative **Authentication → Sign-in method → E-mail/senha**.
8. Ative também o **Firestore Database** (modo produção, região mais próxima).

## Como pegar seu .apk pra instalar no celular

1. Depois de subir os arquivos, vá na aba **"Actions"** do seu repositório no
   GitHub.
2. Espere o workflow **"Build APK"** terminar (ícone verde ✅, leva uns 3-5
   minutos).
3. Clique no workflow finalizado → role até **"Artifacts"** → baixe
   **"nutrisnap-apk"** (vem como .zip contendo o .apk).
4. Transfira o .apk pro celular (Google Drive, e-mail, cabo USB) e instale
   (talvez precise permitir "instalar de fontes desconhecidas" nas
   configurações do Android).

## Próxima etapa

Assim que Firebase estiver configurado e o primeiro build passar, entramos no
diário de refeições + integração com a API do Gemini pro reconhecimento de
alimentos por foto.
