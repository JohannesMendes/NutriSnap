# NutriSnap 🥗

App mobile de evolução e nutrição inteligente, 100% gratuito, com calculadora
de metas, diário de refeições e registro de alimentos por foto (IA).

**Todos os dados ficam salvos localmente no aparelho** (Hive) — sem
servidor, sem custo, sem configuração de backend. O usuário pode exportar um
backup manual (.json) a qualquer momento pra não perder os dados ao trocar
de celular.

## Status atual

✅ Perfil local + calculadora de metas diárias (calorias, macros e água)
✅ Backup manual (exportar/importar via .json)
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

## Como funciona o backup

- Na tela inicial, o botão **"Exportar"** gera um arquivo `nutrisnap_backup.json`
  e abre o menu de compartilhamento do Android — o usuário pode mandar pra
  si mesmo por e-mail, salvar no Google Drive, WhatsApp, etc.
- O botão **"Importar"** deixa escolher esse arquivo de volta (útil ao trocar
  de celular ou reinstalar o app) e restaura todos os dados.

## Próxima etapa

Diário de refeições + integração com a API do Gemini pro reconhecimento de
alimentos por foto.
