/// Um item de alimento registrado dentro de uma refeição.
class FoodEntry {
  final String id;
  final String name;
  final double grams;
  final int calories;
  final double proteinG;
  final double carbsG;
  final double fatG;

  FoodEntry({
    required this.id,
    required this.name,
    required this.grams,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'grams': grams,
        'calories': calories,
        'proteinG': proteinG,
        'carbsG': carbsG,
        'fatG': fatG,
      };

  factory FoodEntry.fromMap(Map<String, dynamic> map) => FoodEntry(
        id: map['id'],
        name: map['name'],
        grams: (map['grams'] as num).toDouble(),
        calories: map['calories'],
        proteinG: (map['proteinG'] as num).toDouble(),
        carbsG: (map['carbsG'] as num).toDouble(),
        fatG: (map['fatG'] as num).toDouble(),
      );
}
