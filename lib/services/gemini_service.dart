import 'dart:convert';
import 'package:http/http.dart' as http;

/// Envia a foto do prato pra API do Gemini e recebe de volta a estimativa
/// de alimentos, peso e macros — tudo em uma única chamada.
class GeminiService {
  static const _model = 'gemini-2.0-flash';

  static Future<List<Map<String, dynamic>>> analyzeFoodPhoto({
    required String apiKey,
    required String base64Image,
  }) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$apiKey',
    );

    const prompt = '''
Analise esta foto de um prato de comida. Identifique cada alimento visível,
estime o peso em gramas e calcule os valores nutricionais aproximados.

Responda APENAS com um JSON válido (sem markdown, sem texto adicional), no
formato de uma lista:
[
  {"name": "Arroz branco", "grams": 150, "calories": 195, "protein_g": 4, "carbs_g": 42, "fat_g": 0.5}
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
