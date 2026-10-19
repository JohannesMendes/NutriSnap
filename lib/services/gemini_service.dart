import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

/// Exceção lançada quando algo dá errado ao falar com o backend de IA.
/// Guarda o erro técnico original (pra debug/log) mas expõe uma
/// [friendlyMessage] pronta pra mostrar na tela, sem vazar JSON bruto,
/// stack trace ou código de status pro usuário final.
class GeminiApiException implements Exception {
  final String friendlyMessage;
  final String technicalDetails;

  GeminiApiException(this.friendlyMessage, this.technicalDetails);

  @override
  String toString() => friendlyMessage;

  /// Mapeia um erro HTTP retornado pelo nosso backend (que por sua vez
  /// repassa/traduz erros do Gemini) pra uma mensagem amigável, cobrindo
  /// os casos mais comuns: sobrecarga temporária, limite de requisições,
  /// instabilidade no servidor, etc. Como a chave da API agora vive só no
  /// backend, o usuário final nunca precisa (nem consegue) ver erros de
  /// chave inválida — isso é um problema de configuração do servidor, não
  /// do aparelho dele.
  factory GeminiApiException.fromHttpError(int statusCode, String body) {
    final lowerBody = body.toLowerCase();
    String friendly;
    if (statusCode == 503 || lowerBody.contains('unavailable') || lowerBody.contains('overloaded') || lowerBody.contains('high demand')) {
      friendly = 'O servidor da IA está sobrecarregado no momento. Tente novamente em alguns segundos.';
    } else if (statusCode == 429 || lowerBody.contains('rate limit') || lowerBody.contains('quota')) {
      friendly = 'Muitas tentativas em pouco tempo. Aguarde um instante e tente de novo.';
    } else if (statusCode == 400) {
      friendly = 'Não consegui processar essa solicitação. Tente descrever de outra forma.';
    } else if (statusCode >= 500) {
      friendly = 'O servidor da IA está com instabilidade no momento. Tente novamente em instantes.';
    } else if (statusCode == 404) {
      friendly = 'O modelo de IA do servidor não está disponível (erro 404). Tente novamente mais tarde.';
    } else if (statusCode == 401 || statusCode == 403) {
      friendly = 'Acesso ao servidor da IA bloqueado (erro $statusCode). Verifique a protecao de deploy do Vercel.';
    } else {
      friendly = 'Algo deu errado ao falar com a IA (erro $statusCode). Tente novamente em instantes.';
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

/// Fala com o nosso backend seguro (Firebase Cloud Functions) — nunca
/// direto com a API do Gemini. A chave da API do Gemini fica só no
/// servidor (como Secret), então ela nunca é embutida no app nem pode ser
/// extraída do APK. O app manda a foto/texto pro backend e recebe de
/// volta a estimativa de alimentos, peso e macros já pronta.
class GeminiService {
  static Future<Map<String, dynamic>> _post(Map<String, dynamic> body) async {
    http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(kAnalyzeFoodEndpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 50));
    } on TimeoutException catch (e) {
      throw GeminiApiException.fromNetworkError(e);
    } on SocketException catch (e) {
      throw GeminiApiException.fromNetworkError(e);
    } on http.ClientException catch (e) {
      throw GeminiApiException.fromNetworkError(e);
    } catch (e) {
      // Qualquer outra falha ao montar/enviar a requisição (URI inválida,
      // sem host configurado, etc.) vira um erro de rede tratável.
      throw GeminiApiException.fromNetworkError(e);
    }

    if (response.statusCode != 200) {
      throw GeminiApiException.fromHttpError(response.statusCode, response.body);
    }

    try {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    } catch (e) {
      throw GeminiApiException.fromParsingError(e);
    }
  }

  static Future<List<Map<String, dynamic>>> _callBackend(Map<String, dynamic> body) async {
    final data = await _post(body);
    try {
      final list = data['items'] as List;
      return list.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      throw GeminiApiException.fromParsingError(e);
    }
  }

  /// Envia um áudio (WAV, base64) pro backend, que transcreve exatamente o
  /// que foi dito. O texto devolvido segue o mesmo caminho do "adicionar
  /// por texto" (analyzeFoodText).
  static Future<String> transcribeAudio({required String base64Audio}) async {
    final Map<String, dynamic> data;
    try {
      data = await _post({'mode': 'transcribe', 'base64Audio': base64Audio});
    } on GeminiApiException catch (e) {
      // Mostra um pedacinho do erro técnico pra facilitar descobrir a causa
      // (ex.: backend desatualizado no Netlify vs. erro do Gemini).
      final t = e.technicalDetails;
      final detail = t.length > 180 ? '${t.substring(0, 180)}...' : t;
      throw GeminiApiException('Não consegui transcrever o áudio.\n[$detail]', t);
    }
    final transcript = (data['transcript'] as String?)?.trim() ?? '';
    if (transcript.isEmpty) {
      throw GeminiApiException(
        'Não consegui entender o áudio. Tente falar mais perto do microfone.',
        'empty transcript',
      );
    }
    return transcript;
  }

  /// Envia a foto do prato pro backend, que repassa pra API do Gemini e
  /// devolve a estimativa de alimentos, peso e macros — tudo em uma única
  /// chamada.
  static Future<List<Map<String, dynamic>>> analyzeFoodPhoto({
    required String base64Image,
  }) {
    return _callBackend({'mode': 'photo', 'base64Image': base64Image});
  }

  /// Envia uma frase livre digitada pelo usuário (ex: "4 fatias de pão de
  /// forma", "comi 3 ovos mexidos e uma fatia de pão", "café com leite e
  /// 2 colheres de açúcar") pro backend, que interpreta com o Gemini e
  /// devolve a mesma estrutura usada pela análise de foto — permitindo que
  /// a tela de conferência seja idêntica nos dois fluxos.
  static Future<List<Map<String, dynamic>>> analyzeFoodText({
    required String description,
  }) {
    return _callBackend({'mode': 'text', 'description': description});
  }
}
