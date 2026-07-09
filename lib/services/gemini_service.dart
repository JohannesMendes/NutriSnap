import 'dart:convert';
import 'package:http/http.dart' as http;

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

    final response = await http.post(
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
    );

    if (response.statusCode != 200) {
      throw Exception('Erro na API do Gemini (${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(response.body);
    String text = data['candidates'][0]['content']['parts'][0]['text'] as String;

    // Remove blocos de markdown (```json ... ```) caso o modelo os inclua.
    text = text.replaceAll('```json', '').replaceAll('```', '').trim();

    final list = jsonDecode(text) as List;
    return list.map((e) => Map<String, dynamic>.from(e)).toList();
  }
}
