/// Chave da API do Gemini injetada em tempo de compilação, via
/// `--dart-define=GEMINI_API_KEY=...` (configurado no GitHub Actions a
/// partir de um Secret). Fica vazia se o build não passar essa flag —
/// nesse caso o usuário pode colar a própria chave em Configurações.
const String kBuiltInGeminiApiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
