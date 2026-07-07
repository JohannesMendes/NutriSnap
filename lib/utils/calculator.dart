import '../models/user_profile.dart';

/// Calcula as metas diárias do usuário usando a fórmula de Mifflin-St Jeor,
/// considerada mais precisa que Harris-Benedict pra população em geral.
class GoalCalculator {
  static DailyTargets calculate(UserProfile profile) {
    // 1. Taxa Metabólica Basal (TMB)
    double bmr;
    if (profile.gender == Gender.male) {
      bmr = (10 * profile.currentWeightKg) +
          (6.25 * profile.heightCm) -
          (5 * profile.age) +
          5;
    } else {
      bmr = (10 * profile.currentWeightKg) +
          (6.25 * profile.heightCm) -
          (5 * profile.age) -
          161;
    }

    // 2. Gasto Energético Total Diário (TDEE) = TMB x fator de atividade
    final tdee = bmr * profile.activityLevel.factor;

    // 3. Ajuste conforme objetivo (déficit, manutenção ou superávit calórico)
    final targetCalories = tdee * (1 + profile.goal.calorieAdjustment);

    // 4. Distribuição de macronutrientes
    // Proteína: 2.0g/kg (preserva massa magra, essencial em déficit)
    // Gordura: 25% das calorias totais
    // Carboidrato: preenche o restante
    final proteinG = profile.currentWeightKg * 2.0;
    final proteinKcal = proteinG * 4;

    final fatKcal = targetCalories * 0.25;
    final fatG = fatKcal / 9;

    final carbsKcal = targetCalories - proteinKcal - fatKcal;
    final carbsG = carbsKcal / 4;

    // 5. Água: 35ml por kg de peso corporal (padrão usado por nutricionistas)
    final waterMl = profile.currentWeightKg * 35;

    return DailyTargets(
      calories: targetCalories.round(),
      proteinG: proteinG.round(),
      carbsG: carbsG.round(),
      fatG: fatG.round(),
      waterMl: waterMl.round(),
    );
  }
}
