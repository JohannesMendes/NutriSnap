import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/food_entry.dart';

/// Uma linha editável de resultado da IA: mantém os próprios controllers
/// pra permitir corrigir nome, peso e macros antes de confirmar o envio
/// ao diário. Usado tanto pela tela de scan por foto quanto pela tela de
/// entrada de texto livre — as duas caem na mesma experiência de conferência.
class EditableEntry {
  final String id;
  final TextEditingController name;
  final TextEditingController grams;
  final TextEditingController calories;
  final TextEditingController protein;
  final TextEditingController carbs;
  final TextEditingController fat;

  EditableEntry.fromFoodEntry(FoodEntry e)
      : id = e.id,
        name = TextEditingController(text: e.name),
        grams = TextEditingController(text: e.grams.toStringAsFixed(0)),
        calories = TextEditingController(text: e.calories.toString()),
        protein = TextEditingController(text: e.proteinG.toStringAsFixed(1)),
        carbs = TextEditingController(text: e.carbsG.toStringAsFixed(1)),
        fat = TextEditingController(text: e.fatG.toStringAsFixed(1));

  EditableEntry.blank()
      : id = DateTime.now().microsecondsSinceEpoch.toString(),
        name = TextEditingController(),
        grams = TextEditingController(),
        calories = TextEditingController(),
        protein = TextEditingController(),
        carbs = TextEditingController(),
        fat = TextEditingController();

  FoodEntry toFoodEntry() => FoodEntry(
        id: id,
        name: name.text.trim().isEmpty ? 'Alimento' : name.text.trim(),
        grams: double.tryParse(grams.text.replaceAll(',', '.')) ?? 0,
        calories: int.tryParse(calories.text) ?? 0,
        proteinG: double.tryParse(protein.text.replaceAll(',', '.')) ?? 0,
        carbsG: double.tryParse(carbs.text.replaceAll(',', '.')) ?? 0,
        fatG: double.tryParse(fat.text.replaceAll(',', '.')) ?? 0,
      );

  void dispose() {
    name.dispose();
    grams.dispose();
    calories.dispose();
    protein.dispose();
    carbs.dispose();
    fat.dispose();
  }
}

/// Card editável de um item identificado pela IA (ou adicionado manualmente
/// nessa etapa de conferência). Nome + peso em uma linha, macros em outra.
class EditableFoodCard extends StatelessWidget {
  final EditableEntry entry;
  final VoidCallback onRemove;

  const EditableFoodCard({required Key key, required this.entry, required this.onRemove}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: entry.name,
                    decoration: const InputDecoration(labelText: 'Alimento', isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: entry.grams,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'g', isDense: true),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                  onPressed: onRemove,
                  tooltip: 'Remover item',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: entry.calories,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'kcal', isDense: true),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: entry.protein,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'P (g)', isDense: true),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: entry.carbs,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'C (g)', isDense: true),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: entry.fat,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'G (g)', isDense: true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Converte um valor numérico vindo do Gemini pra double, de forma
/// tolerante: o modelo normalmente devolve um `num` de verdade (por causa
/// do `response_mime_type: application/json`), mas às vezes devolve o
/// mesmo valor como `String` (ex: "150" em vez de 150), ou vírgula em vez
/// de ponto decimal. Um cast direto (`as num?`) quebra nesses casos com um
/// TypeError que não é um [GeminiApiException] — e antes isso derrubava o
/// parsing inteiro do item, fazendo a tela de scan mostrar sempre "Algo deu
/// errado ao analisar a foto", mesmo com o backend respondendo certinho.
double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) {
    return double.tryParse(value.trim().replaceAll(',', '.'));
  }
  return null;
}

int? _toInt(dynamic value) {
  final d = _toDouble(value);
  return d?.round();
}

/// Converte a lista bruta vinda do Gemini (mesmo formato usado pra foto e
/// pra texto) em [FoodEntry]s prontos, já com a contagem/unidade visível
/// no nome quando fizer sentido (ex: "Pão de forma (4 fatia)"). Itens
/// individualmente malformados são pulados (com log) em vez de derrubar a
/// lista inteira.
List<FoodEntry> parseGeminiFoodList(List<Map<String, dynamic>> raw) {
  final entries = <FoodEntry>[];
  for (final m in raw) {
    try {
      final baseName = (m['name'] ?? 'Alimento').toString();
      final quantity = _toInt(m['quantity']);
      final unit = m['unit']?.toString().trim();
      final displayName = (quantity != null && quantity > 1 && unit != null && unit.isNotEmpty)
          ? '$baseName ($quantity $unit)'
          : baseName;
      entries.add(FoodEntry(
        id: '${DateTime.now().microsecondsSinceEpoch}_${entries.length}_$baseName',
        name: displayName,
        grams: _toDouble(m['grams']) ?? 0,
        calories: _toInt(m['calories']) ?? 0,
        proteinG: _toDouble(m['protein_g']) ?? 0,
        carbsG: _toDouble(m['carbs_g']) ?? 0,
        fatG: _toDouble(m['fat_g']) ?? 0,
      ));
    } catch (_) {
      // Item pontualmente malformado — ignora só esse item, não derruba a
      // análise inteira (o usuário ainda consegue conferir/adicionar o
      // resto e, se quiser, adicionar esse item manualmente).
    }
  }
  return entries;
}
