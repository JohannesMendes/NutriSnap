import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/payment_request.dart';
import 'user_profile_service.dart';

/// Fala com a coleção `solicitacoes_pagamento` do Firestore — usada pelo
/// fluxo de pagamento manual via PIX (sem gateway automático): o usuário
/// aperta "Já paguei" na paywall, isso cria um documento aqui, e o admin
/// confere no banco e aprova pelo painel dentro do app (ver
/// AdminApprovalScreen).
class PaymentRequestService {
  static CollectionReference<Map<String, dynamic>> get _collection =>
      FirebaseFirestore.instance.collection('solicitacoes_pagamento');

  /// Cria a solicitação pendente. Chamado pelo botão "Já paguei" na
  /// paywall — não libera acesso nenhum sozinho, só registra pro admin
  /// revisar.
  static Future<void> createRequest({
    required String uid,
    required String nome,
    required String? email,
    required String planoId,
    required String nomeContaPagamento,
  }) async {
    await _collection.add({
      'uid': uid,
      'nome': nome,
      'email': email,
      'plano_id': planoId,
      'nome_conta_pagamento': nomeContaPagamento,
      'status': 'pendente',
      'criado_em': FieldValue.serverTimestamp(),
    });
  }

  /// Stream em tempo real das solicitações pendentes, mais recentes
  /// primeiro — é o que alimenta a lista do painel admin.
  static Stream<List<PaymentRequest>> watchPending() {
    return _collection
        .where('status', isEqualTo: 'pendente')
        .orderBy('criado_em', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(PaymentRequest.fromDoc).toList());
  }

  /// Aprova a solicitação: libera o plano pro usuário (mesma função da
  /// paywall antiga) e marca o pedido como aprovado, pra sumir da lista
  /// de pendentes.
  static Future<void> approve(PaymentRequest request) async {
    await UserProfileService.activatePlan(request.uid, request.planoId);
    await _collection.doc(request.id).set({
      'status': 'aprovado',
      'respondido_em': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Rejeita a solicitação (ex.: PIX não localizado no extrato) sem
  /// liberar nenhum acesso.
  static Future<void> reject(PaymentRequest request) async {
    await _collection.doc(request.id).set({
      'status': 'rejeitado',
      'respondido_em': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
