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
    // Frutas (unidade simples)
    _KnownFood(name: 'maçã', caloriesPer100g: 52, proteinPer100g: 0.3, carbsPer100g: 14, fatPer100g: 0.2, isSimple: true, defaultUnitGrams: 130),
    _KnownFood(name: 'banana', caloriesPer100g: 89, proteinPer100g: 1.1, carbsPer100g: 23, fatPer100g: 0.3, isSimple: true, defaultUnitGrams: 120),
    _KnownFood(name: 'laranja', caloriesPer100g: 47, proteinPer100g: 0.9, carbsPer100g: 12, fatPer100g: 0.1, isSimple: true, defaultUnitGrams: 130),
    _KnownFood(name: 'pera', caloriesPer100g: 57, proteinPer100g: 0.4, carbsPer100g: 15, fatPer100g: 0.1, isSimple: true, defaultUnitGrams: 130),
    _KnownFood(name: 'manga', caloriesPer100g: 60, proteinPer100g: 0.8, carbsPer100g: 15, fatPer100g: 0.4, isSimple: true, defaultUnitGrams: 200),
    _KnownFood(name: 'mamão', caloriesPer100g: 43, proteinPer100g: 0.5, carbsPer100g: 11, fatPer100g: 0.3, isSimple: true, defaultUnitGrams: 160),
    _KnownFood(name: 'abacaxi', caloriesPer100g: 50, proteinPer100g: 0.5, carbsPer100g: 13, fatPer100g: 0.1, isSimple: true, defaultUnitGrams: 150),
    _KnownFood(name: 'uva', caloriesPer100g: 69, proteinPer100g: 0.7, carbsPer100g: 18, fatPer100g: 0.2, isSimple: true, defaultUnitGrams: 90),
    _KnownFood(name: 'morango', caloriesPer100g: 32, proteinPer100g: 0.7, carbsPer100g: 7.7, fatPer100g: 0.3, isSimple: true, defaultUnitGrams: 100),
    _KnownFood(name: 'abacate', caloriesPer100g: 160, proteinPer100g: 2, carbsPer100g: 8.5, fatPer100g: 14.7, isSimple: true, defaultUnitGrams: 150),
    _KnownFood(name: 'ovo', caloriesPer100g: 155, proteinPer100g: 13, carbsPer100g: 1.1, fatPer100g: 11, isSimple: true, defaultUnitGrams: 50),
    _KnownFood(name: 'pão francês', caloriesPer100g: 300, proteinPer100g: 8, carbsPer100g: 58, fatPer100g: 3, isSimple: true, defaultUnitGrams: 50),
    _KnownFood(name: 'pão integral', caloriesPer100g: 253, proteinPer100g: 13, carbsPer100g: 41, fatPer100g: 4.2, isSimple: true, defaultUnitGrams: 30),
    _KnownFood(name: 'tapioca', caloriesPer100g: 240, proteinPer100g: 0.6, carbsPer100g: 60, fatPer100g: 0.1, isSimple: true, defaultUnitGrams: 60),

    // Carboidratos / acompanhamentos (porção ajustada pelo objetivo)
    _KnownFood(name: 'arroz', caloriesPer100g: 130, proteinPer100g: 2.7, carbsPer100g: 28, fatPer100g: 0.3),
    _KnownFood(name: 'feijão', caloriesPer100g: 127, proteinPer100g: 8.7, carbsPer100g: 23, fatPer100g: 0.5),
    _KnownFood(name: 'lentilha', caloriesPer100g: 116, proteinPer100g: 9, carbsPer100g: 20, fatPer100g: 0.4),
    _KnownFood(name: 'grão de bico', caloriesPer100g: 164, proteinPer100g: 8.9, carbsPer100g: 27, fatPer100g: 2.6),
    _KnownFood(name: 'batata', caloriesPer100g: 77, proteinPer100g: 2, carbsPer100g: 17, fatPer100g: 0.1),
    _KnownFood(name: 'batata doce', caloriesPer100g: 86, proteinPer100g: 1.6, carbsPer100g: 20, fatPer100g: 0.1),
    _KnownFood(name: 'mandioca', caloriesPer100g: 160, proteinPer100g: 1.4, carbsPer100g: 38, fatPer100g: 0.3),
    _KnownFood(name: 'abóbora', caloriesPer100g: 26, proteinPer100g: 1, carbsPer100g: 6.5, fatPer100g: 0.1),
    _KnownFood(name: 'macarrão', caloriesPer100g: 158, proteinPer100g: 6, carbsPer100g: 31, fatPer100g: 0.9),
    _KnownFood(name: 'milho', caloriesPer100g: 96, proteinPer100g: 3.4, carbsPer100g: 21, fatPer100g: 1.5),
    _KnownFood(name: 'aveia', caloriesPer100g: 389, proteinPer100g: 17, carbsPer100g: 66, fatPer100g: 7),
    _KnownFood(name: 'granola', caloriesPer100g: 471, proteinPer100g: 10, carbsPer100g: 64, fatPer100g: 20),

    // Proteínas
    _KnownFood(name: 'frango', caloriesPer100g: 165, proteinPer100g: 31, carbsPer100g: 0, fatPer100g: 3.6),
    _KnownFood(name: 'carne', caloriesPer100g: 250, proteinPer100g: 26, carbsPer100g: 0, fatPer100g: 17),
    _KnownFood(name: 'peixe', caloriesPer100g: 140, proteinPer100g: 24, carbsPer100g: 0, fatPer100g: 5),
    _KnownFood(name: 'salmão', caloriesPer100g: 208, proteinPer100g: 20, carbsPer100g: 0, fatPer100g: 13),
    _KnownFood(name: 'atum', caloriesPer100g: 132, proteinPer100g: 28, carbsPer100g: 0, fatPer100g: 1.3),
    _KnownFood(name: 'presunto', caloriesPer100g: 145, proteinPer100g: 18, carbsPer100g: 2, fatPer100g: 7),
    _KnownFood(name: 'queijo', caloriesPer100g: 350, proteinPer100g: 25, carbsPer100g: 2, fatPer100g: 27),

    // Laticínios
    _KnownFood(name: 'leite', caloriesPer100g: 61, proteinPer100g: 3.2, carbsPer100g: 4.8, fatPer100g: 3.3),
    _KnownFood(name: 'iogurte', caloriesPer100g: 61, proteinPer100g: 3.5, carbsPer100g: 4.7, fatPer100g: 3.3),
    _KnownFood(name: 'iogurte grego', caloriesPer100g: 97, proteinPer100g: 9, carbsPer100g: 4, fatPer100g: 5),
    _KnownFood(name: 'requeijão', caloriesPer100g: 264, proteinPer100g: 9, carbsPer100g: 3, fatPer100g: 24),
    _KnownFood(name: 'manteiga', caloriesPer100g: 717, proteinPer100g: 0.9, carbsPer100g: 0.1, fatPer100g: 81),

    // Gorduras / oleaginosas
    _KnownFood(name: 'azeite', caloriesPer100g: 884, proteinPer100g: 0, carbsPer100g: 0, fatPer100g: 100),
    _KnownFood(name: 'castanha', caloriesPer100g: 656, proteinPer100g: 14, carbsPer100g: 12, fatPer100g: 66),
    _KnownFood(name: 'amendoim', caloriesPer100g: 567, proteinPer100g: 26, carbsPer100g: 16, fatPer100g: 49),

    // Vegetais / legumes
    _KnownFood(name: 'brócolis', caloriesPer100g: 34, proteinPer100g: 2.8, carbsPer100g: 7, fatPer100g: 0.4),
    _KnownFood(name: 'cenoura', caloriesPer100g: 41, proteinPer100g: 0.9, carbsPer100g: 10, fatPer100g: 0.2),
    _KnownFood(name: 'tomate', caloriesPer100g: 18, proteinPer100g: 0.9, carbsPer100g: 3.9, fatPer100g: 0.2),
    _KnownFood(name: 'alface', caloriesPer100g: 15, proteinPer100g: 1.4, carbsPer100g: 2.9, fatPer100g: 0.2),
    _KnownFood(name: 'pepino', caloriesPer100g: 16, proteinPer100g: 0.7, carbsPer100g: 3.6, fatPer100g: 0.1),
    _KnownFood(name: 'cebola', caloriesPer100g: 40, proteinPer100g: 1.1, carbsPer100g: 9, fatPer100g: 0.1),

    // Adoçantes / temperos / condimentos (o que a IA costuma confundir)
    _KnownFood(name: 'mel', caloriesPer100g: 304, proteinPer100g: 0.3, carbsPer100g: 82, fatPer100g: 0),
    _KnownFood(name: 'açúcar', caloriesPer100g: 387, proteinPer100g: 0, carbsPer100g: 100, fatPer100g: 0),
    _KnownFood(name: 'canela', caloriesPer100g: 247, proteinPer100g: 4, carbsPer100g: 81, fatPer100g: 1.2),
    _KnownFood(name: 'cacau em pó', caloriesPer100g: 228, proteinPer100g: 20, carbsPer100g: 58, fatPer100g: 14),
    _KnownFood(name: 'chocolate', caloriesPer100g: 546, proteinPer100g: 4.9, carbsPer100g: 61, fatPer100g: 31),

    // Bebidas / outros
    _KnownFood(name: 'café', caloriesPer100g: 2, proteinPer100g: 0.1, carbsPer100g: 0, fatPer100g: 0),
    _KnownFood(name: 'whey protein', caloriesPer100g: 400, proteinPer100g: 80, carbsPer100g: 8, fatPer100g: 6),
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

  /// Retorna nomes de alimentos conhecidos que combinam com o que o
  /// usuário está digitando, pra mostrar sugestões de busca inteligente.
  static List<String> suggestions(String query, {int limit = 6}) {
    final lower = query.trim().toLowerCase();
    if (lower.isEmpty) return [];
    return _database
        .where((f) => f.name.contains(lower))
        .map((f) => f.name)
        .take(limit)
        .toList();
  }

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
