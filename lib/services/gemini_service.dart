import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Exceção lançada quando algo dá errado ao falar com a API do Gemini.
/// Guarda o erro técnico original (pra debug/log) mas expõe uma
/// [friendlyMessage] pronta pra mostrar na tela, sem vazar JSON bruto,
/// stack trace ou código de status pro usuário final.
class GeminiApiException implements Exception {
  final String friendlyMessage;
  final String technicalDetails;

  GeminiApiException(this.friendlyMessage, this.technicalDetails);

  @override
  String toString() => friendlyMessage;

  /// Mapeia um erro HTTP da API do Gemini (status code + corpo da resposta)
  /// pra uma mensagem amigável, cobrindo os casos mais comuns: sobrecarga
  /// temporária, limite de requisições, chave inválida, etc.
  factory GeminiApiException.fromHttpError(int statusCode, String body) {
    final lowerBody = body.toLowerCase();
    String friendly;
    if (statusCode == 503 || lowerBody.contains('unavailable') || lowerBody.contains('overloaded') || lowerBody.contains('high demand')) {
      friendly = 'O servidor da IA está sobrecarregado no momento. Tente novamente em alguns segundos.';
    } else if (statusCode == 429 || lowerBody.contains('rate limit') || lowerBody.contains('quota')) {
      friendly = 'Muitas tentativas em pouco tempo. Aguarde um instante e tente de novo.';
    } else if (statusCode == 401 || statusCode == 403) {
      friendly = 'Sua chave da API do Gemini parece inválida ou sem permissão. Confira em Configurações.';
    } else if (statusCode == 400) {
      friendly = 'Não consegui processar essa solicitação. Tente descrever de outra forma.';
    } else if (statusCode >= 500) {
      friendly = 'O servidor da IA está com instabilidade no momento. Tente novamente em instantes.';
    } else {
      friendly = 'Algo deu errado ao falar com a IA. Tente novamente em instantes.';
    }
    return GeminiApiException(friendly, 'HTTP $statusCode: $body');
  }

  /// Mapeia falhas de rede (sem internet, timeout, DNS, etc.) pra uma
  /// mensagem amigável.
  factory GeminiApiException.fromNetworkError(Object error) {
    return GeminiApiException(
      'Sem conexão com o servidor. Verifique sua internet e tente novamente.',
      error.toString(),
    );
  }

  /// Mapeia falhas ao interpretar a resposta da IA (JSON inesperado, campo
  /// faltando, etc.) pra uma mensagem amigável.
  factory GeminiApiException.fromParsingError(Object error) {
    return GeminiApiException(
      'A IA retornou uma resposta inesperada. Tente novamente ou reformule o texto.',
      error.toString(),
    );
  }
}

/// Envia a foto do prato pra API do Gemini e recebe de volta a estimativa
/// de alimentos, peso e macros — tudo em uma única chamada.
class GeminiService {
  static const _model = 'gemini-2.5-flash';

  static Future<List<Map<String, dynamic>>> analyzeFoodPhoto({
    required String apiKey,
    required String base64Image,
  }) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$apiKey',
    );

    const prompt = '''
Você é um nutricionista analisando uma foto de comida com extremo rigor visual. Siga estas regras OBRIGATÓRIAS, nessa ordem, para cada alimento identificado:

1. CONTAGEM E MULTIPLICAÇÃO (regra mais importante):
   Antes de calcular qualquer valor, CONTE quantas unidades idênticas ou semelhantes
   daquele alimento estão visíveis (ex: 3 fatias de pão, 2 ovos, 5 morangos, 4 pedaços
   de frango). O valor final de calorias e de cada macro DEVE ser o resultado de:
   (valor nutricional de 1 unidade) x (quantidade contada).
   Nunca devolva o valor de uma única unidade se houver mais de uma visível — some tudo.

2. ESCALA E PROPORÇÃO — fatia vs. inteiro:
   Antes de estimar o peso, procure referências de tamanho na própria foto: garfo,
   faca, colher, tamanho do prato, copo, mão, embalagem. Use essas referências para
   decidir se o que você vê é uma PORÇÃO/FATIA INDIVIDUAL ou o ALIMENTO INTEIRO.
   Exemplo: uma fatia de bolo de ~3cm de largura é uma FATIA, não o bolo inteiro —
   estime o peso dessa fatia especificamente, nunca o peso do bolo completo.

3. CETICISMO COM PESO/VOLUME:
   Estime o peso com base no tamanho e densidade do que está REALMENTE visível na
   foto. NUNCA assuma o peso padrão de uma embalagem, receita ou porção comercial
   inteira, a menos que a embalagem/alimento completo esteja de fato 100% exposto
   e inteiro na imagem. Na dúvida entre um valor menor e um maior, prefira o menor
   (mais realista para o que está visível).

4. Depois de aplicar as regras acima, calcule as calorias e os macros (proteína,
   carboidrato, gordura) já como TOTAIS do item (considerando a quantidade e o
   peso real estimados), não como valores de referência por 100g.

Responda APENAS com um JSON válido (sem markdown, sem texto adicional, sem
comentários), no formato de uma lista. Para cada item, inclua os campos abaixo —
"quantity" e "unit" documentam a contagem que você usou, e "grams"/"calories"/
os macros já devem vir multiplicados pela quantidade total:
[
  {
    "name": "Pão de forma",
    "quantity": 3,
    "unit": "fatia",
    "grams": 75,
    "calories": 210,
    "protein_g": 6,
    "carbs_g": 39,
    "fat_g": 3
  }
]
''';

    http.Response response;
    try {
      response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt},
                {
                  'inline_data': {'mime_type': 'image/jpeg', 'data': base64Image}
                },
              ],
            },
          ],
          'generationConfig': {
            'response_mime_type': 'application/json',
          },
        }),
      ).timeout(const Duration(seconds: 45));
    } on TimeoutException catch (e) {
      throw GeminiApiException.fromNetworkError(e);
    } on SocketException catch (e) {
      throw GeminiApiException.fromNetworkError(e);
    } on http.ClientException catch (e) {
      throw GeminiApiException.fromNetworkError(e);
    }

    if (response.statusCode != 200) {
      throw GeminiApiException.fromHttpError(response.statusCode, response.body);
    }

    try {
      final data = jsonDecode(response.body);
      String text = data['candidates'][0]['content']['parts'][0]['text'] as String;

      // Remove blocos de markdown (```json ... ```) caso o modelo os inclua.
      text = text.replaceAll('```json', '').replaceAll('```', '').trim();

      final list = jsonDecode(text) as List;
      return list.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      throw GeminiApiException.fromParsingError(e);
    }
  }

  /// Envia uma frase livre digitada pelo usuário (ex: "4 fatias de pão de
  /// forma", "comi 3 ovos mexidos e uma fatia de pão", "café com leite e
  /// 2 colheres de açúcar") pro modelo de texto do Gemini e recebe de volta
  /// a mesma estrutura usada pela análise de foto — permitindo que a tela
  /// de conferência seja idêntica nos dois fluxos.
  static Future<List<Map<String, dynamic>>> analyzeFoodText({
    required String apiKey,
    required String description,
  }) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$apiKey',
    );

    final prompt = '''
Você é um nutricionista experiente, especialista em culinária brasileira e em
suplementação de academia, interpretando uma descrição em texto livre
(português coloquial, escrita por um usuário comum de app) do que ele comeu
ou vai comer. Você NUNCA se recusa a interpretar e NUNCA deixa de responder
por falta de detalhes — sempre faz a melhor estimativa possível, mesmo com
informação incompleta. Siga estas regras OBRIGATÓRIAS, nessa ordem, para
cada alimento identificado:

1. SEGMENTAÇÃO: A frase pode conter um ou vários alimentos separados por "e",
   vírgula, ou apenas espaço (ex: "3 ovos mexidos e uma fatia de pão", "café
   com leite e 2 colheres de açúcar"). Identifique CADA alimento/ingrediente
   como um item separado na lista de resposta — não agrupe itens diferentes
   em um só.

2. RIGOR COM QUANTIDADES (regra mais importante — nunca falhe nisso):
   Leia a quantidade informada pelo usuário, seja em algarismo ("4", "2") ou
   por extenso ("quatro", "duas", "uma", "meia", "meio"). Se nenhuma
   quantidade for mencionada, assuma 1 unidade/porção padrão do alimento.
   Interprete corretamente variações de escrita como "4 pão de forma",
   "4 fatias de pão de forma", "quatro fatias de pão de forma" e "pão de
   forma x4" como a MESMA coisa: 4 fatias de pão de forma — o número
   (escrito em algarismo OU por extenso) SEMPRE deve disparar a
   multiplicação, sem exceção, e SEMPRE deve ser mapeado pro alimento certo
   da frase (nunca ignore nem confunda qual alimento aquele número se refere).
   O valor final de calorias e de cada macro DEVE ser o resultado de:
   (valor nutricional de 1 unidade/porção) x (quantidade detectada).
   Nunca devolva o valor de uma única unidade se a quantidade for maior —
   some tudo.

3. EXTRAÇÃO DE UNIDADE: Identifique a unidade usada pelo usuário (fatia,
   unidade, colher (de sopa/chá), xícara, copo, grama, pedaço, fatia, prato,
   concha, scoop, dose etc.). Se o usuário não mencionar unidade nenhuma
   (ex: "4 pão de forma"), infira a unidade mais natural para aquele
   alimento (nesse exemplo, "fatia").

4. FLEXIBILIDADE DE ESPECIFICIDADE — dos dois extremos, você deve lidar bem:
   a) TERMOS ULTRA ESPECÍFICOS (marca, sabor, tipo exato): ex: "Whey Protein
      Isolado Growth sabor chocolate", "Refrigerante Coca-Cola zero lata",
      "Iogurte Grego Nestlé Nature". Use seu conhecimento sobre o produto
      real (marca + tipo) pra estimar os macros com precisão de rótulo
      quando souber; senão, use a média de categoria (ex: whey isolado
      genérico) sem travar ou pedir mais informação.
   b) TERMOS VAGOS/GENÉRICOS: ex: "um pedaço de bolo", "um prato de almoço
      normal", "um lanchinho", "uma marmita". NUNCA falhe ou devolva
      vazio nesses casos — estime como um nutricionista experiente
      estimaria, usando a composição mais provável e comum no Brasil:
      - "um pedaço de bolo" → assuma bolo caseiro comum (ex: bolo de
        chocolate/cenoura), porção de 60g a 80g.
      - "um prato de almoço normal"/"prato feito" → assuma arroz, feijão,
        uma proteína (carne/frango) e salada, nas proporções típicas de um
        prato brasileiro médio (~500-650 kcal).
      - "um lanchinho" → assuma algo leve e comum tipo um sanduíche simples
        ou uma fruta com algo, ~150-250 kcal.
      Escolha sempre o cenário mais COMUM e realista, nunca o extremo
      (nem o menor nem o maior possível), e nunca deixe de dar uma resposta
      numérica completa.

5. DICIONÁRIO CULTURAL BRASILEIRO E DE ACADEMIA: Reconheça e interprete
   corretamente gírias, expressões regionais e termos típicos do dia a dia
   e da rotina fitness no Brasil, incluindo mas não se limitando a:
   "pão na chapa" (pão francês tostado na chapa com manteiga), "cafezinho"
   (café pequeno, geralmente com açúcar), "shake de hipercalórico"/"massa"
   (suplemento hipercalórico batido com leite), "filé de frango grelhado",
   "tapioca", "pão de queijo", "marmita fitness", "whey", "bcaa", "creatina",
   "coxinha", "pastel", "misto quente", "suco natural", "vitamina de
   banana", "quentinha", "self-service"/"por quilo". Interprete essas
   expressões com o mesmo rigor de qualquer alimento formal.

6. CONHECIMENTO NUTRICIONAL: Calcule o peso estimado (gramas) de cada
   unidade/porção usando seu conhecimento nutricional padrão (ex: 1 fatia de
   pão de forma ≈ 25g, 1 ovo médio ≈ 50g, 1 colher de sopa de açúcar ≈ 12g),
   e a partir daí as calorias e macros (proteína, carboidrato, gordura) já
   como TOTAIS do item (considerando a quantidade detectada), não como
   valores de referência por 100g.

7. TOLERÂNCIA A ESCRITA INFORMAL: O usuário pode escrever sem acentos, com
   abreviações, gírias ou erros de digitação (ex: "pao de forma", "cafe com
   leite"). Interprete o alimento mesmo assim, sem pedir esclarecimento —
   faça sua melhor estimativa nutricional sempre. Você NUNCA responde com
   lista vazia, erro ou pedido de mais informação — sempre entrega pelo
   menos uma estimativa completa e razoável.

Responda APENAS com um JSON válido (sem markdown, sem texto adicional, sem
comentários), no formato de uma lista. Para cada item, inclua os campos
abaixo — "quantity" e "unit" documentam a quantidade/unidade que você
detectou, e "grams"/"calories"/os macros já devem vir multiplicados pela
quantidade total:
[
  {
    "name": "Pão de forma",
    "quantity": 4,
    "unit": "fatia",
    "grams": 100,
    "calories": 280,
    "protein_g": 8,
    "carbs_g": 52,
    "fat_g": 4
  }
]

Texto do usuário para interpretar: "$description"
''';

    http.Response response;
    try {
      response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt},
              ],
            },
          ],
          'generationConfig': {
            'response_mime_type': 'application/json',
          },
        }),
      ).timeout(const Duration(seconds: 45));
    } on TimeoutException catch (e) {
      throw GeminiApiException.fromNetworkError(e);
    } on SocketException catch (e) {
      throw GeminiApiException.fromNetworkError(e);
    } on http.ClientException catch (e) {
      throw GeminiApiException.fromNetworkError(e);
    }

    if (response.statusCode != 200) {
      throw GeminiApiException.fromHttpError(response.statusCode, response.body);
    }

    try {
      final data = jsonDecode(response.body);
      String text = data['candidates'][0]['content']['parts'][0]['text'] as String;

      // Remove blocos de markdown (```json ... ```) caso o modelo os inclua.
      text = text.replaceAll('```json', '').replaceAll('```', '').trim();

      final list = jsonDecode(text) as List;
      return list.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      throw GeminiApiException.fromParsingError(e);
    }
  }
}
