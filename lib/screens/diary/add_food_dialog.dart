import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/food_entry.dart';

/// Formulário manual: o usuário digita o alimento e seus valores
/// nutricionais (por enquanto manual — o modo por foto/IA entra depois).
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

  void _save() {
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
              decoration: const InputDecoration(hintText: 'Nome do alimento'),
            ),
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
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(onPressed: _save, child: const Text('Adicionar')),
      ],
    );
  }
}
