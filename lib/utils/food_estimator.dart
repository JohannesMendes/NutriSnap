import '../models/food_entry.dart';
import '../models/user_profile.dart';

/// Um alimento conhecido na base local, com valores por 100g.
class _KnownFood {
  final String name;
  final double caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;
  final bool isSimple; // true = unidade única (não precisa perguntar peso)
  final double defaultUnitGrams; // peso médio de 1 unidade (se isSimple)

  const _KnownFood({
    required this.name,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    this.isSimple = false,
    this.defaultUnitGrams = 100,
  });
}

/// Estima calorias/macros a partir só do nome do alimento, sem exigir que
/// o usuário pese tudo. Alimentos "simples" (frutas, unidades) usam uma
/// porção padrão. Alimentos "complexos" (arroz, feijão, carnes) usam uma
/// porção média ajustada pelo objetivo do perfil (emagrecer = porção menor,
/// ganhar peso = porção maior) quando o usuário não informa o peso.
class FoodEstimator {
  static const _database = <_KnownFood>[
    _KnownFood(name: 'maçã', caloriesPer100g: 52, proteinPer100g: 0.3, carbsPer100g: 14, fatPer100g: 0.2, isSimple: true, defaultUnitGrams: 130),
    _KnownFood(name: 'banana', caloriesPer100g: 89, proteinPer100g: 1.1, carbsPer100g: 23, fatPer100g: 0.3, isSimple: true, defaultUnitGrams: 120),
    _KnownFood(name: 'laranja', caloriesPer100g: 47, proteinPer100g: 0.9, carbsPer100g: 12, fatPer100g: 0.1, isSimple: true, defaultUnitGrams: 130),
    _KnownFood(name: 'ovo', caloriesPer100g: 155, proteinPer100g: 13, carbsPer100g: 1.1, fatPer100g: 11, isSimple: true, defaultUnitGrams: 50),
    _KnownFood(name: 'pão francês', caloriesPer100g: 300, proteinPer100g: 8, carbsPer100g: 58, fatPer100g: 3, isSimple: true, defaultUnitGrams: 50),
    _KnownFood(name: 'arroz', caloriesPer100g: 130, proteinPer100g: 2.7, carbsPer100g: 28, fatPer100g: 0.3),
    _KnownFood(name: 'feijão', caloriesPer100g: 127, proteinPer100g: 8.7, carbsPer100g: 23, fatPer100g: 0.5),
    _KnownFood(name: 'frango', caloriesPer100g: 165, proteinPer100g: 31, carbsPer100g: 0, fatPer100g: 3.6),
    _KnownFood(name: 'carne', caloriesPer100g: 250, proteinPer100g: 26, carbsPer100g: 0, fatPer100g: 17),
    _KnownFood(name: 'batata', caloriesPer100g: 77, proteinPer100g: 2, carbsPer100g: 17, fatPer100g: 0.1),
    _KnownFood(name: 'macarrão', caloriesPer100g: 158, proteinPer100g: 6, carbsPer100g: 31, fatPer100g: 0.9),
    _KnownFood(name: 'batata doce', caloriesPer100g: 86, proteinPer100g: 1.6, carbsPer100g: 20, fatPer100g: 0.1),
  ];

  /// Tenta achar um alimento conhecido pelo nome digitado (busca parcial).
  static _KnownFood? _match(String name) {
    final lower = name.trim().toLowerCase();
    for (final food in _database) {
      if (lower.contains(food.name) || food.name.contains(lower)) return food;
    }
    return null;
  }

  static bool isKnown(String name) => _match(name) != null;
  static bool isSimpleFood(String name) => _match(name)?.isSimple ?? false;

  /// Porção média em gramas pra alimentos complexos, ajustada pelo
  /// objetivo do usuário. Emagrecer: -25%. Ganhar peso: +30%. Manter: base.
  static double _adaptivePortion(Goal goal) {
    const base = 120.0; // porção média de referência (ex: 1 escumadeira de arroz)
    switch (goal) {
      case Goal.lose:
        return base * 0.75;
      case Goal.gain:
        return base * 1.30;
      case Goal.maintain:
        return base;
    }
  }

  /// Gera o FoodEntry já calculado. [grams] é opcional: se nulo, usa a
  /// porção padrão (unidade simples) ou a média adaptativa pelo objetivo.
  static FoodEntry? estimate({
    required String name,
    double? grams,
    Goal? userGoal,
  }) {
    final food = _match(name);
    if (food == null) return null;

    final effectiveGrams = grams ??
        (food.isSimple ? food.defaultUnitGrams : _adaptivePortion(userGoal ?? Goal.maintain));

    final factor = effectiveGrams / 100;
    return FoodEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.trim(),
      grams: effectiveGrams,
      calories: (food.caloriesPer100g * factor).round(),
      proteinG: food.proteinPer100g * factor,
      carbsG: food.carbsPer100g * factor,
      fatG: food.fatPer100g * factor,
    );
  }
}
