# NutriSnap 🥗

App mobile de evolução e nutrição inteligente, 100% gratuito, com calculadora
de metas, diário de refeições, contador de água, scanner de prato por foto
(IA) e lembretes diários.

**Todos os dados ficam salvos localmente no aparelho** (Hive) — sem
servidor, sem custo, sem configuração de backend.

## Status atual

✅ Perfil local + calculadora de metas diárias (calorias, macros e água)
✅ Diário de refeições (padrão + personalizadas) com estimativa inteligente
   por objetivo pra entrada manual
✅ Contagem regressiva fixa (quanto falta bater a meta do dia)
✅ Contador de água
✅ Scanner de prato por foto via IA (Gemini) — identifica os alimentos,
   estima peso e macros automaticamente
✅ Fotos das refeições salvas numa pasta dedicada na galeria do celular
   (evolução visual ao longo do tempo)
✅ Lembretes diários de refeição e água (notificações locais)
✅ Splash screen animada

## Como subir isso pro seu GitHub (sem terminal)

1. Extraia o .zip que o Claude te mandou.
2. No repositório **NutriSnap**, apague os arquivos antigos e clique em
   **"Add file" → "Upload files"**.
3. Arraste **todo o conteúdo** da pasta extraída (incluindo a pasta oculta
   `.github`) pra dentro da janela do navegador.
4. Clique em **"Commit changes"**.

## Como configurar o scanner de foto (Gemini)

1. Acesse https://aistudio.google.com/apikey e gere uma chave gratuita
   (não precisa cartão de crédito).
2. Dentro do app, vá em **Configurações** (ícone de engrenagem na Home) e
   cole a chave no campo indicado.
3. Pronto — o botão "Foto (IA)" dentro de cada refeição já vai funcionar.

## Como pegar o .apk e testar (agora com link público!)

Antes o .apk ficava num "Artifact" que exigia login no GitHub. Agora ele sai
como uma **Release pública**, com link direto — dá pra mandar pra qualquer
pessoa testar, sem ela precisar entender nada de GitHub:

1. Depois de subir os arquivos, vá na aba **"Actions"** e espere o build
   terminar (3-6 min).
2. Vá na aba **"Releases"** do repositório (ou acesse
   `https://github.com/SEU_USUARIO/NutriSnap/releases`).
3. A release mais recente vai ter o arquivo **NutriSnap.apk** — esse link é
   público, qualquer um com o link consegue baixar direto no navegador do
   celular, sem precisar de conta no GitHub.
4. Instale (pode pedir pra permitir "fontes desconhecidas" no Android).

## Próxima etapa

Ajustes finos de layout e polish visual, conforme o que você for testando.
