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

  try {
    // Evita o erro "[core/duplicate-app] A Firebase App named "[DEFAULT]"
    // already exists". Causa real: o workflow de build (build_apk.yml) copia
    // um google-services.json E aplica o plugin do Google Services no Gradle.
    // Isso faz o Android inicializar o app "[DEFAULT]" sozinho (antes mesmo
    // do main() rodar), então quando chamamos Firebase.initializeApp(options:
    // ...) aqui embaixo com as opções explícitas do firebase_options.dart,
    // o Firebase reclama que "[DEFAULT]" já existe. Isso acontece sempre,
    // em todo abertura do app — por isso a checagem "apps.isEmpty" sozinha
    // não resolve (o app nativo já existe antes do Dart rodar).
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } on FirebaseException catch (error) {
      if (error.code != 'duplicate-app') rethrow;
      // Já existe um "[DEFAULT]" (auto-inicializado nativamente) — está tudo
      // bem, só seguimos usando ele em vez de tentar criar outro.
    }

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
  } catch (error, stackTrace) {
    // Se a inicialização falhar (Firebase, Hive, etc.), não deixa o app
    // travado na Splash Screen sem explicação — mostra uma tela de erro
    // com os detalhes para facilitar o diagnóstico.
    debugPrint('Erro na inicialização do app: $error\n$stackTrace');
    runApp(InitErrorApp(error: error, stackTrace: stackTrace));
  }
}

/// App mínimo exibido quando a inicialização (Firebase/Hive/etc.) falha.
/// Mostra o erro na tela para facilitar o diagnóstico e permite tentar
/// novamente sem precisar fechar e reabrir o app manualmente.
class InitErrorApp extends StatelessWidget {
  const InitErrorApp({super.key, required this.error, this.stackTrace});

  final Object error;
  final StackTrace? stackTrace;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NutriSnap',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: InitErrorScreen(error: error, stackTrace: stackTrace),
    );
  }
}

class InitErrorScreen extends StatelessWidget {
  const InitErrorScreen({super.key, required this.error, this.stackTrace});

  final Object error;
  final StackTrace? stackTrace;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 64),
              const SizedBox(height: 16),
              const Text(
                'Não foi possível iniciar o app',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ocorreu um erro ao conectar com os serviços do NutriSnap. '
                'Verifique sua conexão com a internet e tente novamente. '
                'Se o problema persistir, envie o detalhe técnico abaixo ao suporte.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 20),
              Container(
                constraints: const BoxConstraints(maxHeight: 220),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    error.toString(),
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  // Reinicia o fluxo de inicialização do zero.
                  main();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
