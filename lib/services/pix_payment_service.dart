import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'auth_service.dart';

/// Cobrança Pix criada no servidor (Mercado Pago).
class PixCharge {
  final String paymentDocId; // id do documento em `pagamentos` (acompanha o status)
  final String qrCode; // "copia e cola"
  final String qrCodeBase64; // imagem do QR code (PNG em base64)
  final DateTime expiresAt;
  final double amount;

  const PixCharge({
    required this.paymentDocId,
    required this.qrCode,
    required this.qrCodeBase64,
    required this.expiresAt,
    required this.amount,
  });
}

class PixPaymentException implements Exception {
  final String message;
  const PixPaymentException(this.message);
  @override
  String toString() => message;
}

class PixPaymentService {
  static String get _endpoint => '$kBackendBaseUrl/api/createPayment';

  /// Pede ao servidor um Pix pro plano [planId]. O preço é definido no
  /// servidor — o app só diz qual plano quer.
  static Future<PixCharge> createCharge(String planId) async {
    final user = AuthService.currentUser;
    if (user == null) throw const PixPaymentException('Faça login de novo para continuar.');

    final idToken = await user.getIdToken();
    http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode({'planId': planId}),
          )
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      throw const PixPaymentException('Sem conexão com o servidor. Verifique a internet e tente de novo.');
    }

    Map<String, dynamic> data = {};
    try {
      data = Map<String, dynamic>.from(jsonDecode(response.body));
    } catch (_) {}

    if (response.statusCode != 200) {
      throw PixPaymentException(
        (data['message'] as String?) ?? 'Não foi possível gerar o Pix. Tente novamente.',
      );
    }

    return PixCharge(
      paymentDocId: data['paymentDocId'] as String,
      qrCode: data['qrCode'] as String,
      qrCodeBase64: (data['qrCodeBase64'] as String?) ?? '',
      expiresAt: DateTime.tryParse((data['expiresAt'] as String?) ?? '') ??
          DateTime.now().add(const Duration(minutes: 30)),
      amount: (data['amount'] as num).toDouble(),
    );
  }

  /// Status do pagamento em tempo real: "pendente", "aprovado",
  /// "rejeitado", "cancelado", "expirado"...
  static Stream<String> watchStatus(String paymentDocId) {
    return FirebaseFirestore.instance
        .collection('pagamentos')
        .doc(paymentDocId)
        .snapshots()
        .map((doc) => (doc.data()?['status'] as String?) ?? 'pendente');
  }
}
