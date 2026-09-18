/// Antes, a chave da API do Gemini era injetada em tempo de compilação via
/// `--dart-define=GEMINI_API_KEY=...` e ficava embutida no binário do app —
/// qualquer pessoa com o APK conseguia extraí-la com uma ferramenta de
/// descompilação.
///
/// Agora o app nunca fala direto com o Gemini: ele chama esta URL de
/// backend (uma Firebase Cloud Function), que guarda a chave como Secret
/// no servidor e nunca a expõe. Configurável via
/// `--dart-define=BACKEND_BASE_URL=...` (ex: no GitHub Actions), com um
/// valor padrão apontando pra função de produção.
const String kBackendBaseUrl = String.fromEnvironment(
  'BACKEND_BASE_URL',
  defaultValue:
      'https://southamerica-east1-nutrisnap-backend.cloudfunctions.net',
);

/// Endpoint único usado tanto pra análise por foto quanto por texto — o
/// corpo da requisição (`mode: "photo" | "text"`) define qual caminho a
/// função de backend segue.
String get kAnalyzeFoodEndpoint => '$kBackendBaseUrl/analyzeFood';
