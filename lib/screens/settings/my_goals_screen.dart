import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/user_profile.dart';
import '../../utils/calculator.dart';
import '../../services/local_storage_service.dart';
import '../../services/auth_service.dart';
import '../../services/user_profile_service.dart';
import '../onboarding/goal_calculator_screen.dart';

/// Seção "Minhas Metas e Perfil": permite ver e atualizar as métricas do
/// usuário (nome, altura, peso atual, meta de peso, meta de água e meta
/// calórica) a qualquer momento, sem precisar refazer o cadastro inteiro.
/// Salva local (Hive, reflete na Home na hora) e faz backup no Firestore.
class MyGoalsScreen extends StatefulWidget {
  const MyGoalsScreen({super.key});

  @override
  State<MyGoalsScreen> createState() => _MyGoalsScreenState();
}

class _MyGoalsScreenState extends State<MyGoalsScreen> {
  late UserProfile? _profile;
  late DailyTargets? _targets;

  late final TextEditingController _nameCtrl;
  late final TextEditingController _heightCtrl;
  late final TextEditingController _weightCtrl;
  late final TextEditingController _goalWeightCtrl;
  late final TextEditingController _waterGoalCtrl;
  late final TextEditingController _calorieGoalCtrl;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _profile = LocalStorageService.loadProfile();
    _targets = LocalStorageService.loadTargets();

    _nameCtrl = TextEditingController(text: _profile?.name ?? '');
    _heightCtrl = TextEditingController(text: _profile?.heightCm.toStringAsFixed(0) ?? '');
    _weightCtrl = TextEditingController(text: _profile?.currentWeightKg.toStringAsFixed(1) ?? '');
    _goalWeightCtrl = TextEditingController(text: _profile?.goalWeightKg.toStringAsFixed(1) ?? '');
    _waterGoalCtrl = TextEditingController(text: _targets?.waterMl.toString() ?? '');
    _calorieGoalCtrl = TextEditingController(text: _targets?.calories.toString() ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _goalWeightCtrl.dispose();
    _waterGoalCtrl.dispose();
    _calorieGoalCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final currentProfile = _profile;
    if (currentProfile == null) return;

    if (_nameCtrl.text.trim().isEmpty ||
        _heightCtrl.text.isEmpty ||
        _weightCtrl.text.isEmpty ||
        _goalWeightCtrl.text.isEmpty ||
        _waterGoalCtrl.text.isEmpty ||
        _calorieGoalCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha todos os campos.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final updatedProfile = UserProfile(
        uid: currentProfile.uid,
        name: _nameCtrl.text.trim(),
        gender: currentProfile.gender,
        age: currentProfile.age,
        heightCm: double.parse(_heightCtrl.text.replaceAll(',', '.')),
        currentWeightKg: double.parse(_weightCtrl.text.replaceAll(',', '.')),
        goalWeightKg: double.parse(_goalWeightCtrl.text.replaceAll(',', '.')),
        activityLevel: currentProfile.activityLevel,
        goal: currentProfile.goal,
      );

      // Recalcula os macros (proteína/carbo/gordura) a partir do perfil
      // atualizado, mas deixa a meta de calorias e de água exatamente
      // como o usuário digitou — pra ele poder ajustar manualmente sem o
      // app "corrigir" o valor por baixo.
      final recalculated = GoalCalculator.calculate(updatedProfile);
      final updatedTargets = recalculated.copyWith(
        calories: int.parse(_calorieGoalCtrl.text),
        waterMl: int.parse(_waterGoalCtrl.text),
      );

      await LocalStorageService.saveProfile(updatedProfile);
      await LocalStorageService.saveTargets(updatedTargets);

      final uid = AuthService.currentUser?.uid;
      if (uid != null) {
        await UserProfileService.saveGoalsBackup(
          uid,
          profile: updatedProfile.toMap(),
          targets: {
            'calories': updatedTargets.calories,
            'proteinG': updatedTargets.proteinG,
            'carbsG': updatedTargets.carbsG,
            'fatG': updatedTargets.fatG,
            'waterMl': updatedTargets.waterMl,
          },
        );
      }

      if (!mounted) return;
      setState(() {
        _profile = updatedProfile;
        _targets = updatedTargets;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Metas atualizadas! Já refletem na tela inicial.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Confira os valores digitados e tente novamente.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _finalizeGoal() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Finalizar meta atual?'),
        content: const Text(
          'Isso encerra seu objetivo/ciclo atual e leva você de volta pra '
          'calculadora de metas, pra definir um novo objetivo (peso, '
          'atividade, calorias) do zero. Seu histórico de refeições e água '
          'já registrados NÃO é apagado.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Finalizar e recomeçar')),
        ],
      ),
    );
    if (confirmed != true) return;

    await LocalStorageService.resetProfileAndTargets();
    if (!mounted) return;
    // Limpa toda a pilha de navegação e manda pra calculadora de metas —
    // assim o usuário começa o novo ciclo do zero, sem telas antigas
    // (Home com dados velhos, Configurações, etc.) empilhadas por trás.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const GoalCalculatorScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Minhas Metas e Perfil')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Nenhum perfil encontrado ainda. Complete a calculadora de metas primeiro.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Minhas Metas e Perfil')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Perfil', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 12),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Nome'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _heightCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Altura (cm)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _weightCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Peso atual (kg)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _goalWeightCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Meta de peso (kg)'),
          ),
          const SizedBox(height: 28),
          const Text('Metas diárias', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 4),
          const Text(
            'Os macros (proteína, carboidrato, gordura) são recalculados '
            'automaticamente a partir do seu perfil. Calorias e água você '
            'pode ajustar manualmente aqui.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _calorieGoalCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Meta calórica (kcal)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _waterGoalCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Meta de água (ml)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.black),
                  )
                : const Text('Salvar alterações'),
          ),
          const SizedBox(height: 32),
          const Divider(color: AppColors.surfaceLight),
          const SizedBox(height: 12),
          const Text('Novo ciclo', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          const Text(
            'Bateu sua meta de peso ou quer mudar de objetivo? Finalize o '
            'ciclo atual e refaça a calculadora com novos dados.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger)),
            onPressed: _finalizeGoal,
            icon: const Icon(Icons.flag_circle_outlined),
            label: const Text('Finalizar meta atual / iniciar novo ciclo'),
          ),
        ],
      ),
    );
  }
}
