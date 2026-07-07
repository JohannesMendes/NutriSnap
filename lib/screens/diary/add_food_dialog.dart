import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/food_entry.dart';
import '../../models/user_profile.dart';
import '../../utils/food_estimator.dart';
import '../../services/local_storage_service.dart';

/// Formulário manual com estimativa inteligente:
/// - Alimento simples (maçã, banana, ovo...) -> calcula direto, sem pedir peso.
/// - Alimento complexo (arroz, feijão...) -> pergunta se sabe o peso; se não
///   souber, usa uma média adaptada ao objetivo do usuário (emagrecer/ganhar).
/// - Alimento não reconhecido -> cai pro formulário manual completo.
class AddFoodDialog extends StatefulWidget {
  const AddFoodDialog({super.key});

  @override
  State<AddFoodDialog> createState() => _AddFoodDialogState();
}

class _AddFoodDialogState extends State<AddFoodDialog> {
  final _nameCtrl = TextEditingController();
  final _gramsCtrl = TextEditingController();
  final _caloriesCtrl = TextEditingController();
  final _proteinCtrl = TextEditingController();
  final _carbsCtrl = TextEditingController();
  final _fatCtrl = TextEditingController();

  bool _showManualFields = false;
  bool _askingGrams = false;
  String? _hintText;

  void _onNameChanged(String value) {
    setState(() {
      _askingGrams = false;
      _hintText = null;
      if (value.trim().isEmpty) {
        _showManualFields = false;
        return;
      }
      if (FoodEstimator.isKnown(value)) {
        if (FoodEstimator.isSimpleFood(value)) {
          _hintText = 'Reconhecido — vou calcular uma porção padrão automaticamente.';
          _showManualFields = false;
        } else {
          _askingGrams = true;
          _showManualFields = false;
        }
      } else {
        _showManualFields = true;
      }
    });
  }

  void _confirmSmart({double? grams}) {
    final profile = LocalStorageService.loadProfile();
    final entry = FoodEstimator.estimate(
      name: _nameCtrl.text,
      grams: grams,
      userGoal: profile?.goal,
    );
    if (entry != null) Navigator.of(context).pop(entry);
  }

  void _saveManual() {
    if (_nameCtrl.text.isEmpty || _caloriesCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha ao menos o nome e as calorias.')),
      );
      return;
    }
    final entry = FoodEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: _nameCtrl.text,
      grams: double.tryParse(_gramsCtrl.text) ?? 0,
      calories: int.tryParse(_caloriesCtrl.text) ?? 0,
      proteinG: double.tryParse(_proteinCtrl.text) ?? 0,
      carbsG: double.tryParse(_carbsCtrl.text) ?? 0,
      fatG: double.tryParse(_fatCtrl.text) ?? 0,
    );
    Navigator.of(context).pop(entry);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Adicionar alimento'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameCtrl,
              onChanged: _onNameChanged,
              decoration: const InputDecoration(hintText: 'Nome do alimento (ex: maçã, arroz...)'),
            ),
            if (_hintText != null) ...[
              const SizedBox(height: 8),
              Text(_hintText!, style: const TextStyle(color: AppColors.primary, fontSize: 12)),
            ],
            if (_askingGrams) ...[
              const SizedBox(height: 14),
              const Text('Sabe o peso (em gramas)?', style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              TextField(
                controller: _gramsCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: 'Peso em gramas (opcional)'),
              ),
            ],
            if (_showManualFields) ...[
              const SizedBox(height: 10),
              const Text('Alimento não reconhecido — preencha manualmente:',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 10),
              TextField(
                controller: _gramsCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: 'Peso (g) — opcional'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _caloriesCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: 'Calorias (kcal)'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _proteinCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: 'Proteína (g)'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _carbsCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: 'Carbo (g)'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _fatCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: 'Gordura (g)'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_showManualFields) {
              _saveManual();
            } else if (_askingGrams) {
              final grams = double.tryParse(_gramsCtrl.text);
              _confirmSmart(grams: grams); // null = usa média pelo objetivo
            } else if (_nameCtrl.text.isNotEmpty && FoodEstimator.isKnown(_nameCtrl.text)) {
              _confirmSmart();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Digite o nome de um alimento.')),
              );
            }
          },
          child: const Text('Adicionar'),
        ),
      ],
    );
  }
}
