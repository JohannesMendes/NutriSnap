import 'package:firebase_auth/firebase_auth.dart';
import 'user_profile_service.dart';

/// Exceção com mensagem amigável em português — a UI nunca precisa
/// traduzir os códigos de erro do Firebase na mão.
class AuthException implements Exception {
  final String friendlyMessage;
  AuthException(this.friendlyMessage);

  @override
  String toString() => friendlyMessage;

  factory AuthException.fromFirebase(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return AuthException('E-mail inválido.');
      case 'user-disabled':
        return AuthException('Essa conta foi desativada.');
      case 'user-not-found':
        return AuthException('Não encontramos uma conta com esse e-mail.');
      case 'wrong-password':
      case 'invalid-credential':
        return AuthException('E-mail ou senha incorretos.');
      case 'email-already-in-use':
        return AuthException('Já existe uma conta cadastrada com esse e-mail.');
      case 'weak-password':
        return AuthException('Senha muito fraca — use pelo menos 6 caracteres.');
      case 'too-many-requests':
        return AuthException('Muitas tentativas. Aguarde um pouco e tente de novo.');
      case 'network-request-failed':
        return AuthException('Sem conexão com a internet. Verifique e tente novamente.');
      default:
        return AuthException('Não foi possível concluir. Tente novamente em instantes.');
    }
  }
}

/// Fala com o Firebase Authentication (login/cadastro por e-mail e senha).
/// A tela de login escuta [authStateChanges] pra decidir, em tempo real,
/// se mostra o formulário de login ou o resto do app.
class AuthService {
  static FirebaseAuth get _auth => FirebaseAuth.instance;

  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  static User? get currentUser => _auth.currentUser;

  static Future<void> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
    } on FirebaseAuthException catch (e) {
      throw AuthException.fromFirebase(e);
    }
  }

  static Future<void> register({required String email, required String password, String? name}) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
      if (name != null && name.trim().isNotEmpty) {
        await credential.user?.updateDisplayName(name.trim());
      }
      final uid = credential.user?.uid;
      if (uid != null) {
        // Cria o documento de perfil (plano trial de 15 dias) assim que a
        // conta é criada — ver UserProfileService e o LicenseGate em main.dart.
        await UserProfileService.createProfileIfNeeded(uid);
      }
    } on FirebaseAuthException catch (e) {
      throw AuthException.fromFirebase(e);
    }
  }

  static Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException.fromFirebase(e);
    }
  }

  static Future<void> signOut() => _auth.signOut();
}
