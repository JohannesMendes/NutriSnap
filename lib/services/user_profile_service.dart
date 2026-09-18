import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/plans_config.dart';

/// Planos que dão acesso liberado sem checagem de prazo — "ilimitado" é o
/// plano de quem assinou (via paywall, ou setado manualmente pelo
/// admin/suporte no Console do Firestore), "admin" é pra contas internas
/// de administração/teste.
const _unlimitedPlanTypes = {'ilimitado', 'admin'};

class UserProfile {
  final String uid;
  final DateTime dataCriacao;
  final String tipoPlano; // "trial" | "ilimitado" | "admin" | id de um plano pago (ver plans_config.dart)
  final bool bloqueado;

  const UserProfile({
    required this.uid,
    required this.dataCriacao,
    required this.tipoPlano,
    required this.bloqueado,
  });

  bool get isUnlimited => _unlimitedPlanTypes.contains(tipoPlano);
  bool get isTrial => tipoPlano == 'trial';

  int get trialDaysElapsed => DateTime.now().difference(dataCriacao).inDays;
  int get trialDaysRemaining => (kTrialDurationDays - trialDaysElapsed).clamp(0, kTrialDurationDays);
  bool get isTrialExpired => isTrial && trialDaysElapsed > kTrialDurationDays;

  /// true quando o usuário pode de fato usar o app: não está bloqueado
  /// manualmente, e (tem plano ilimitado/admin, tem um plano pago, OU
  /// ainda está dentro dos 15 dias de trial).
  bool get hasAccess => !bloqueado && (isUnlimited || !isTrialExpired);

  factory UserProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final ts = data['data_criacao'];
    return UserProfile(
      uid: doc.id,
      dataCriacao: ts is Timestamp ? ts.toDate() : DateTime.now(),
      tipoPlano: (data['tipo_plano'] as String?) ?? 'trial',
      bloqueado: (data['bloqueado'] as bool?) ?? false,
    );
  }
}

/// Fala com a coleção `usuarios` do Firestore — um documento por conta,
/// com o id do documento igual ao uid do Firebase Auth.
class UserProfileService {
  static CollectionReference<Map<String, dynamic>> get _collection =>
      FirebaseFirestore.instance.collection('usuarios');

  /// Chamado logo depois de criar a conta no Firebase Auth (ver
  /// AuthService.register). Cria o documento com os valores padrão do
  /// trial — se por algum motivo já existir (ex: reinstalação, retry),
  /// não sobrescreve nada.
  static Future<void> createProfileIfNeeded(String uid) async {
    final ref = _collection.doc(uid);
    final snapshot = await ref.get();
    if (snapshot.exists) return;
    await ref.set({
      'data_criacao': FieldValue.serverTimestamp(),
      'tipo_plano': 'trial',
      'bloqueado': false,
    });
  }

  /// Stream em tempo real do perfil — assim, se o admin liberar/bloquear
  /// a conta ou o usuário assinar um plano em outro aparelho, o app
  /// reage na hora, sem precisar reabrir.
  static Stream<UserProfile?> watchProfile(String uid) {
    return _collection.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserProfile.fromDoc(doc);
    });
  }

  /// Chamado pelo botão "Assinar Agora" na paywall — simula a confirmação
  /// do pagamento e já libera o acesso, atualizando `tipo_plano` pro id
  /// do plano escolhido (ver plans_config.dart).
  static Future<void> activatePlan(String uid, String planId) async {
    await _collection.doc(uid).set({
      'tipo_plano': planId,
      'assinatura_ativada_em': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
