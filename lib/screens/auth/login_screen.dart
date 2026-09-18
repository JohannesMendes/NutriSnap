import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';

/// Primeira tela que um usuário não autenticado vê. Alterna entre "Entrar"
/// e "Criar conta" no mesmo formulário, pra não precisar de duas telas
/// separadas. A navegação pro resto do app acontece sozinha: assim que o
/// Firebase confirma o login, o AuthGate (em main.dart) reage à mudança
/// de estado e troca de tela — esta tela nunca chama Navigator.push.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _isRegisterMode = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorText;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      if (_isRegisterMode) {
        await AuthService.register(
          email: _emailCtrl.text,
          password: _passwordCtrl.text,
          name: _nameCtrl.text,
        );
      } else {
        await AuthService.signIn(email: _emailCtrl.text, password: _passwordCtrl.text);
      }
      // Não navega manualmente — o AuthGate troca de tela sozinho ao
      // detectar o novo estado de autenticação.
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _errorText = e.friendlyMessage);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = await showDialog<String>(
      context: context,
      builder: (context) {
        final ctrl = TextEditingController(text: _emailCtrl.text);
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Redefinir senha'),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(hintText: 'Seu e-mail cadastrado'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.of(context).pop(ctrl.text), child: const Text('Enviar')),
          ],
        );
      },
    );
    if (email == null || email.trim().isEmpty) return;
    try {
      await AuthService.sendPasswordResetEmail(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enviamos um link de redefinição de senha pro seu e-mail.')),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.friendlyMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Image.asset('assets/images/app_icon.png', width: 84, height: 84),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _isRegisterMode ? 'Criar conta' : 'Bem-vindo de volta',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isRegisterMode
                        ? 'Crie sua conta pra começar a registrar suas refeições.'
                        : 'Entre com sua conta pra continuar seu progresso.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 32),
                  if (_isRegisterMode) ...[
                    TextFormField(
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        hintText: 'Nome',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe seu nome' : null,
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      hintText: 'E-mail',
                      prefixIcon: Icon(Icons.mail_outline_rounded),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Informe seu e-mail';
                      if (!v.contains('@') || !v.contains('.')) return 'E-mail inválido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      hintText: 'Senha',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Informe sua senha';
                      if (v.length < 6) return 'Use pelo menos 6 caracteres';
                      return null;
                    },
                  ),
                  if (!_isRegisterMode) ...[
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isLoading ? null : _forgotPassword,
                        child: const Text('Esqueci minha senha'),
                      ),
                    ),
                  ] else
                    const SizedBox(height: 20),
                  if (_errorText != null) ...[
                    const SizedBox(height: 4),
                    Text(_errorText!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.black),
                          )
                        : Text(_isRegisterMode ? 'Criar conta' : 'Entrar'),
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => setState(() {
                                _isRegisterMode = !_isRegisterMode;
                                _errorText = null;
                              }),
                      child: Text(
                        _isRegisterMode
                            ? 'Já tem uma conta? Entrar'
                            : 'Ainda não tem conta? Criar agora',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
