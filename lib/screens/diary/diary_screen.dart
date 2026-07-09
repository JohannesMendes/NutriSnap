import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/meal.dart';
import '../../models/user_profile.dart';
import '../../services/local_storage_service.dart';
import '../scan/photo_scan_screen.dart';
import '../scan/text_scan_screen.dart';

class DiaryScreen extends StatefulWidget {
  final DateTime? date;
  const DiaryScreen({super.key, this.date});

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  late final DateTime _date = widget.date ?? DateTime.now();
  late List<Meal> _meals;
  int _water = 0;
  DailyTargets? _targets;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _meals = LocalStorageService.loadMealsForDate(_date);
    _water = LocalStorageService.loadWaterForDate(_date);
    _targets = LocalStorageService.loadTargets();
  }

  Future<void> _persist() async {
    await LocalStorageService.saveMealsForDate(_date, _meals);
  }

  Future<void> _addFoodManual(Meal meal) async {
    final entries = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TextScanScreen()),
    );
    if (entries == null || (entries as List).isEmpty) return;
    setState(() => meal.entries.addAll(entries.cast()));
    _persist();
  }

  Future<void> _addFoodByPhoto(Meal meal) async {
    final entries = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PhotoScanScreen()),
    );
    if (entries == null || (entries as List).isEmpty) return;
    setState(() => meal.entries.addAll(entries.cast()));
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
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
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

  int get _consumedCalories => _meals.fold(0, (sum, m) => sum + m.totalCalories);
  double get _consumedProtein => _meals.fold(0.0, (sum, m) => sum + m.totalProtein);
  double get _consumedCarbs => _meals.fold(0.0, (sum, m) => sum + m.totalCarbs);
  double get _consumedFat => _meals.fold(0.0, (sum, m) => sum + m.totalFat);

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final targets = _targets;

    final isToday = _isSameDay(_date, DateTime.now());
    return Scaffold(
      appBar: AppBar(
        title: Text(isToday
            ? 'Diário de refeições'
            : 'Diário de ${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              children: [
                ..._meals.map((meal) => _MealCard(
                      meal: meal,
                      onAddFoodManual: () => _addFoodManual(meal),
                      onAddFoodByPhoto: () => _addFoodByPhoto(meal),
                      onRemoveFood: (id) => _removeFood(meal, id),
                    )),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _addCustomMeal,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Nova refeição personalizada'),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          if (targets != null)
            _RemainingBar(
              consumedCalories: _consumedCalories,
              targetCalories: targets.calories,
              consumedProtein: _consumedProtein,
              targetProtein: targets.proteinG.toDouble(),
              consumedCarbs: _consumedCarbs,
              targetCarbs: targets.carbsG.toDouble(),
              consumedFat: _consumedFat,
              targetFat: targets.fatG.toDouble(),
              water: _water,
              targetWater: targets.waterMl,
            ),
        ],
      ),
    );
  }
}

/// Barra fixa embaixo mostrando [Meta] - [Consumido] = [Falta], sempre visível.
class _RemainingBar extends StatelessWidget {
  final int consumedCalories, targetCalories, water, targetWater;
  final double consumedProtein, targetProtein, consumedCarbs, targetCarbs, consumedFat, targetFat;

  const _RemainingBar({
    required this.consumedCalories,
    required this.targetCalories,
    required this.consumedProtein,
    required this.targetProtein,
    required this.consumedCarbs,
    required this.targetCarbs,
    required this.consumedFat,
    required this.targetFat,
    required this.water,
    required this.targetWater,
  });

  @override
  Widget build(BuildContext context) {
    final remainingCal = targetCalories - consumedCalories;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.surfaceLight, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Faltam pra hoje', style: TextStyle(color: AppColors.textSecondary)),
              Text(
                remainingCal >= 0 ? '$remainingCal kcal' : 'Meta batida ✅',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: remainingCal >= 0 ? AppColors.primary : AppColors.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _MiniStat('P', targetProtein - consumedProtein, AppColors.secondary),
              _MiniStat('C', targetCarbs - consumedCarbs, AppColors.primary),
              _MiniStat('G', targetFat - consumedFat, AppColors.danger),
              _MiniStat('💧', (targetWater - water).toDouble(), AppColors.water, unit: 'ml'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final double remaining;
  final Color color;
  final String unit;
  const _MiniStat(this.label, this.remaining, this.color, {this.unit = 'g'});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        Text(
          remaining > 0 ? '${remaining.toStringAsFixed(0)}$unit' : '✓',
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _MealCard extends StatelessWidget {
  final Meal meal;
  final VoidCallback onAddFoodManual;
  final VoidCallback onAddFoodByPhoto;
  final void Function(String entryId) onRemoveFood;

  const _MealCard({
    required this.meal,
    required this.onAddFoodManual,
    required this.onAddFoodByPhoto,
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
              Text('${meal.totalCalories} kcal', style: const TextStyle(color: AppColors.textSecondary)),
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
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onAddFoodManual,
                      icon: const Icon(Icons.edit_note_rounded, size: 16),
                      label: const Text('Texto (IA)'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onAddFoodByPhoto,
                      icon: const Icon(Icons.camera_alt_rounded, size: 16),
                      label: const Text('Foto (IA)'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
