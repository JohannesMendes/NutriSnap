import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/meal.dart';
import '../../services/local_storage_service.dart';
import 'add_food_dialog.dart';

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key});

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  final _date = DateTime.now();
  late List<Meal> _meals;

  @override
  void initState() {
    super.initState();
    _meals = LocalStorageService.loadMealsForDate(_date);
  }

  Future<void> _persist() async {
    await LocalStorageService.saveMealsForDate(_date, _meals);
  }

  Future<void> _addFood(Meal meal) async {
    final entry = await showDialog(
      context: context,
      builder: (_) => const AddFoodDialog(),
    );
    if (entry == null) return;
    setState(() => meal.entries.add(entry));
    _persist();
  }

  void _removeFood(Meal meal, String entryId) {
    setState(() => meal.entries.removeWhere((e) => e.id == entryId));
    _persist();
  }

  Future<void> _addCustomMeal() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Nova refeição'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Ex: Lanche da tarde, Ceia...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Criar'),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    setState(() {
      _meals.add(Meal(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name.trim(),
        isDefault: false,
      ));
    });
    _persist();
  }

  int get _totalCalories => _meals.fold(0, (sum, m) => sum + m.totalCalories);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Diário de refeições')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total do dia', style: TextStyle(color: AppColors.textSecondary)),
                  Text('$_totalCalories kcal',
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ..._meals.map((meal) => _MealCard(
                meal: meal,
                onAddFood: () => _addFood(meal),
                onRemoveFood: (id) => _removeFood(meal, id),
              )),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _addCustomMeal,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Nova refeição personalizada'),
          ),
        ],
      ),
    );
  }
}

class _MealCard extends StatelessWidget {
  final Meal meal;
  final VoidCallback onAddFood;
  final void Function(String entryId) onRemoveFood;

  const _MealCard({
    required this.meal,
    required this.onAddFood,
    required this.onRemoveFood,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: meal.isDefault,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(meal.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('${meal.totalCalories} kcal',
                  style: const TextStyle(color: AppColors.textSecondary)),
            ],
          ),
          children: [
            ...meal.entries.map((e) => ListTile(
                  dense: true,
                  title: Text(e.name),
                  subtitle: Text(
                    '${e.grams > 0 ? "${e.grams.toStringAsFixed(0)}g · " : ""}${e.calories} kcal · P:${e.proteinG.toStringAsFixed(0)}g C:${e.carbsG.toStringAsFixed(0)}g G:${e.fatG.toStringAsFixed(0)}g',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textSecondary),
                    onPressed: () => onRemoveFood(e.id),
                  ),
                )),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: OutlinedButton.icon(
                onPressed: onAddFood,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Adicionar alimento'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
