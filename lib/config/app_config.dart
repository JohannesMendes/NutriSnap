/// Antes, a chave da API do Gemini era injetada em tempo de compilação via
/// `--dart-define=GEMINI_API_KEY=...` e ficava embutida no binário do app —
/// qualquer pessoa com o APK conseguia extraí-la com uma ferramenta de
/// descompilação.
///
/// Agora o app nunca fala direto com o Gemini: ele chama esta URL de
/// backend (uma Netlify Function, ver netlify/functions/analyzeFood.mts), que
/// guarda a chave como variável de ambiente no servidor e nunca a expõe —
/// sem exigir nenhum plano pago (diferente do Firebase Functions, que
/// exige o plano Blaze). Configurável via
/// `--dart-define=BACKEND_BASE_URL=...` (ex: no GitHub Actions), com um
/// valor padrão apontando pro deploy de produção no Netlify.
const String _kFallbackBackendBaseUrl = 'https://nutrisnap-backend.netlify.app';

const String _kBackendBaseUrlRaw = String.fromEnvironment(
  'BACKEND_BASE_URL',
  defaultValue: _kFallbackBackendBaseUrl,
);

/// Se o build passar `--dart-define=BACKEND_BASE_URL=` com valor vazio
/// (ex: o secret BACKEND_BASE_URL não está configurado no GitHub Actions),
/// `String.fromEnvironment` retorna '' em vez do `defaultValue` — porque a
/// chave foi passada, só que vazia. Sem essa checagem, o app tentava bater
/// numa URL sem host nenhum, o que derrubava toda análise de foto/texto
/// com um erro que nem chegava a ser tratado como falha de rede.
final String kBackendBaseUrl =
    _kBackendBaseUrlRaw.trim().isEmpty ? _kFallbackBackendBaseUrl : _kBackendBaseUrlRaw.trim();

/// Endpoint único usado tanto pra análise por foto quanto por texto — o
/// corpo da requisição (`mode: "photo" | "text"`) define qual caminho a
/// função de backend segue. `/api/...` é a rota da Netlify Function
/// (qualquer arquivo dentro de api/ vira automaticamente um endpoint com
/// esse prefixo).
String get kAnalyzeFoodEndpoint => '$kBackendBaseUrl/api/analyzeFood';
