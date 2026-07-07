import 'food_entry.dart';

/// Uma refeição do dia (Café da Manhã, Almoço, Jantar, ou personalizada
/// criada pelo usuário), contendo os alimentos registrados nela.
class Meal {
  final String id;
  final String name;
  final bool isDefault; // true pras 3 refeições padrão (não pode excluir)
  final List<FoodEntry> entries;

  Meal({
    required this.id,
    required this.name,
    required this.isDefault,
    List<FoodEntry>? entries,
  }) : entries = entries ?? [];

  int get totalCalories => entries.fold(0, (sum, e) => sum + e.calories);
  double get totalProtein => entries.fold(0.0, (sum, e) => sum + e.proteinG);
  double get totalCarbs => entries.fold(0.0, (sum, e) => sum + e.carbsG);
  double get totalFat => entries.fold(0.0, (sum, e) => sum + e.fatG);

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'isDefault': isDefault,
        'entries': entries.map((e) => e.toMap()).toList(),
      };

  factory Meal.fromMap(Map<String, dynamic> map) => Meal(
        id: map['id'],
        name: map['name'],
        isDefault: map['isDefault'] ?? false,
        entries: (map['entries'] as List)
            .map((e) => FoodEntry.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
      );

  /// As 3 refeições padrão de todo novo dia.
  static List<Meal> defaultMeals() => [
        Meal(id: 'breakfast', name: 'Café da Manhã', isDefault: true),
        Meal(id: 'lunch', name: 'Almoço', isDefault: true),
        Meal(id: 'dinner', name: 'Jantar', isDefault: true),
      ];
}
