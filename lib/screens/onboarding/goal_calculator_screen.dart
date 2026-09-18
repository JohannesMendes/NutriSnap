import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/user_profile.dart';
import '../../utils/calculator.dart';
import '../../services/local_storage_service.dart';
import '../../services/notification_service.dart';
import '../home/home_screen.dart';

class GoalCalculatorScreen extends StatefulWidget {
  const GoalCalculatorScreen({super.key});

  @override
  State<GoalCalculatorScreen> createState() => _GoalCalculatorScreenState();
}

class _GoalCalculatorScreenState extends State<GoalCalculatorScreen> {
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _currentWeightCtrl = TextEditingController();
  final _goalWeightCtrl = TextEditingController();

  Gender _gender = Gender.male;
  ActivityLevel _activity = ActivityLevel.moderate;
  Goal _goal = Goal.maintain;

  DailyTargets? _result;

  void _calculate() {
    if (_nameCtrl.text.isEmpty ||
        _ageCtrl.text.isEmpty ||
        _heightCtrl.text.isEmpty ||
        _currentWeightCtrl.text.isEmpty ||
        _goalWeightCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha todos os campos.')),
      );
      return;
    }

    final profile = UserProfile(
      name: _nameCtrl.text,
      gender: _gender,
      age: int.parse(_ageCtrl.text),
      heightCm: double.parse(_heightCtrl.text),
      currentWeightKg: double.parse(_currentWeightCtrl.text),
      goalWeightKg: double.parse(_goalWeightCtrl.text),
      activityLevel: _activity,
      goal: _goal,
    );

    setState(() => _result = GoalCalculator.calculate(profile));
    LocalStorageService.saveProfile(profile);
    LocalStorageService.saveTargets(_result!);
    // Já deixa os lembretes agendados a partir do primeiro uso, com os
    // horários padrão — o usuário pode ajustar depois em Configurações.
    NotificationService.requestPermission().then((_) => NotificationService.rescheduleAll());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Suas metas diárias')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Vamos calcular suas metas personalizadas de calorias, macros e água.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(hintText: 'Seu nome'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<Gender>(
                    initialValue: _gender,
                    dropdownColor: AppColors.surfaceLight,
                    decoration: const InputDecoration(),
                    items: const [
                      DropdownMenuItem(value: Gender.male, child: Text('Masculino')),
                      DropdownMenuItem(value: Gender.female, child: Text('Feminino')),
                    ],
                    onChanged: (v) => setState(() => _gender = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _ageCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: 'Idade'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _heightCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: 'Altura (cm)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _currentWeightCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: 'Peso atual (kg)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _goalWeightCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: 'Peso objetivo (kg)'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ActivityLevel>(
              initialValue: _activity,
              dropdownColor: AppColors.surfaceLight,
              isExpanded: true,
              items: ActivityLevel.values
                  .map((a) => DropdownMenuItem(value: a, child: Text(a.label, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (v) => setState(() => _activity = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Goal>(
              initialValue: _goal,
              dropdownColor: AppColors.surfaceLight,
              items: Goal.values
                  .map((g) => DropdownMenuItem(value: g, child: Text(g.label)))
                  .toList(),
              onChanged: (v) => setState(() => _goal = v!),
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _calculate, child: const Text('Calcular metas')),
            if (_result != null) ...[
              const SizedBox(height: 24),
              _ResultCard(result: _result!),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                ),
                child: const Text('Continuar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final DailyTargets result;
  const _ResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${result.calories} kcal/dia',
                style: const TextStyle(
                    fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primary)),
            const SizedBox(height: 12),
            _MacroRow(label: 'Proteína', value: '${result.proteinG} g', color: AppColors.secondary),
            _MacroRow(label: 'Carboidratos', value: '${result.carbsG} g', color: AppColors.primary),
            _MacroRow(label: 'Gorduras', value: '${result.fatG} g', color: AppColors.danger),
            _MacroRow(label: 'Água', value: '${result.waterMl} ml', color: AppColors.water),
          ],
        ),
      ),
    );
  }
}

class _MacroRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MacroRow({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
