enum Gender { male, female }

enum ActivityLevel {
  sedentary(1.2, 'Sedentário (pouco ou nenhum exercício)'),
  light(1.375, 'Leve (exercício 1-3x/semana)'),
  moderate(1.55, 'Moderado (exercício 3-5x/semana)'),
  active(1.725, 'Ativo (exercício 6-7x/semana)'),
  athlete(1.9, 'Atleta (exercício intenso diário)');

  final double factor;
  final String label;
  const ActivityLevel(this.factor, this.label);
}

enum Goal {
  lose('Perder peso', -0.20),
  maintain('Manter peso', 0.0),
  gain('Ganhar peso', 0.15);

  final String label;
  final double calorieAdjustment; // % aplicado sobre o gasto total
  const Goal(this.label, this.calorieAdjustment);
}

class UserProfile {
  final String? uid;
  final String name;
  final Gender gender;
  final int age;
  final double heightCm;
  final double currentWeightKg;
  final double goalWeightKg;
  final ActivityLevel activityLevel;
  final Goal goal;

  UserProfile({
    this.uid,
    required this.name,
    required this.gender,
    required this.age,
    required this.heightCm,
    required this.currentWeightKg,
    required this.goalWeightKg,
    required this.activityLevel,
    required this.goal,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'gender': gender.name,
        'age': age,
        'heightCm': heightCm,
        'currentWeightKg': currentWeightKg,
        'goalWeightKg': goalWeightKg,
        'activityLevel': activityLevel.name,
        'goal': goal.name,
      };

  factory UserProfile.fromMap(String uid, Map<String, dynamic> map) => UserProfile(
        uid: uid,
        name: map['name'] ?? '',
        gender: Gender.values.byName(map['gender']),
        age: map['age'],
        heightCm: (map['heightCm'] as num).toDouble(),
        currentWeightKg: (map['currentWeightKg'] as num).toDouble(),
        goalWeightKg: (map['goalWeightKg'] as num).toDouble(),
        activityLevel: ActivityLevel.values.byName(map['activityLevel']),
        goal: Goal.values.byName(map['goal']),
      );
}

/// Resultado da calculadora: metas diárias calculadas.
class DailyTargets {
  final int calories;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final int waterMl;

  const DailyTargets({
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.waterMl,
  });

  /// Usado na tela "Minhas Metas e Perfil" (Configurações) pra permitir
  /// que o usuário sobrescreva manualmente a meta calórica e/ou de água,
  /// mantendo os macros (proteína/carbo/gordura) coerentes com o cálculo
  /// baseado no perfil.
  DailyTargets copyWith({int? calories, int? proteinG, int? carbsG, int? fatG, int? waterMl}) {
    return DailyTargets(
      calories: calories ?? this.calories,
      proteinG: proteinG ?? this.proteinG,
      carbsG: carbsG ?? this.carbsG,
      fatG: fatG ?? this.fatG,
      waterMl: waterMl ?? this.waterMl,
    );
  }
}
