import 'package:cloud_firestore/cloud_firestore.dart';

/// Status possíveis de uma solicitação de "já paguei" (pagamento manual
/// via PIX, sem gateway automático). O admin decide aprovar ou rejeitar
/// depois de conferir o PIX no banco.
enum PaymentRequestStatus {
  pendente,
  aprovado,
  rejeitado;

  static PaymentRequestStatus fromString(String? value) {
    switch (value) {
      case 'aprovado':
        return PaymentRequestStatus.aprovado;
      case 'rejeitado':
        return PaymentRequestStatus.rejeitado;
      default:
        return PaymentRequestStatus.pendente;
    }
  }
}

/// Uma solicitação criada quando o usuário aperta "Já paguei" na paywall.
/// Guarda os dados necessários pro admin conferir o PIX no banco sem
/// precisar perguntar nada pelo WhatsApp/e-mail: nome, e-mail (da conta
/// logada) e o nome usado na conta de pagamento (o que aparece no
/// extrato/comprovante do PIX, que pode ser diferente do nome do app).
class PaymentRequest {
  final String id;
  final String uid;
  final String nome;
  final String? email;
  final String planoId;
  final String nomeContaPagamento;
  final PaymentRequestStatus status;
  final DateTime criadoEm;

  const PaymentRequest({
    required this.id,
    required this.uid,
    required this.nome,
    required this.email,
    required this.planoId,
    required this.nomeContaPagamento,
    required this.status,
    required this.criadoEm,
  });

  factory PaymentRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final ts = data['criado_em'];
    return PaymentRequest(
      id: doc.id,
      uid: (data['uid'] as String?) ?? '',
      nome: (data['nome'] as String?) ?? '',
      email: data['email'] as String?,
      planoId: (data['plano_id'] as String?) ?? '',
      nomeContaPagamento: (data['nome_conta_pagamento'] as String?) ?? '',
      status: PaymentRequestStatus.fromString(data['status'] as String?),
      criadoEm: ts is Timestamp ? ts.toDate() : DateTime.now(),
    );
  }
}
