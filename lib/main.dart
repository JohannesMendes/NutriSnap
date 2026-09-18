import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'services/local_storage_service.dart';
import 'services/notification_service.dart';
import 'services/force_update_service.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/update/force_update_screen.dart';
import 'screens/license_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Armazenamento local (Hive) — tudo fica salvo no aparelho, sem servidor.
  await LocalStorageService.init();
  await NotificationService.init();

  // Se o usuário já tem um perfil (não é a primeira vez que abre o app),
  // garante que os lembretes de refeição/água continuem agendados mesmo
  // que ele nunca entre na tela de Configurações — antes, os lembretes só
  // eram (re)agendados quando o usuário salvava as configurações.
  if (LocalStorageService.hasProfile()) {
    await NotificationService.requestPermission();
    await NotificationService.rescheduleAll();
  }

  runApp(const NutriSnapApp());
}

class NutriSnapApp extends StatelessWidget {
  const NutriSnapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NutriSnap',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: const RootGate(),
    );
  }
}

/// Primeira coisa que roda ao abrir o app: checa se existe uma
/// atualização obrigatória pendente ANTES de qualquer outra coisa (mesmo
/// antes de decidir se mostra login ou não) — se houver, trava o app na
/// tela de bloqueio e não deixa passar pra frente de jeito nenhum.
class RootGate extends StatefulWidget {
  const RootGate({super.key});

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  late final Future<ForceUpdateResult> _updateCheck;

  @override
  void initState() {
    super.initState();
    _updateCheck = ForceUpdateService.check();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ForceUpdateResult>(
      future: _updateCheck,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }
        final result = snapshot.data!;
        if (result.mustUpdate) {
          return ForceUpdateScreen(updateUrl: result.updateUrl);
        }
        return const AuthGate();
      },
    );
  }
}

/// Decide, em tempo real, entre a tela de login e o resto do app —
/// escutando diretamente o estado de autenticação do Firebase. Qualquer
/// login, cadastro ou logout feito em qualquer tela reflete aqui na hora,
/// sem precisar de Navigator.push/pop manual.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }
        final user = snapshot.data;
        if (user == null) return const LoginScreen();
        // Usuário logado: agora checa o plano/trial/bloqueio antes de
        // liberar o resto do app (ver LicenseGate).
        return const LicenseGate(child: SplashScreen());
      },
    );
  }
}
