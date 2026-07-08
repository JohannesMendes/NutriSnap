import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gal/gal.dart';
import '../../theme/app_theme.dart';
import '../../models/food_entry.dart';
import '../../services/gemini_service.dart';
import '../../services/local_storage_service.dart';
import '../settings/settings_screen.dart';

/// O core do app: tira foto do prato (de uma fruta a um prato completo),
/// a IA (Gemini) identifica os alimentos, estima peso e macros, e o
/// usuário confirma antes de jogar tudo pro diário.
class PhotoScanScreen extends StatefulWidget {
  const PhotoScanScreen({super.key});

  @override
  State<PhotoScanScreen> createState() => _PhotoScanScreenState();
}

/// Uma linha editável de resultado da IA: mantém os próprios controllers
/// pra permitir corrigir nome, peso e macros antes de confirmar o envio
/// ao diário.
class _EditableEntry {
  final String id;
  final TextEditingController name;
  final TextEditingController grams;
  final TextEditingController calories;
  final TextEditingController protein;
  final TextEditingController carbs;
  final TextEditingController fat;

  _EditableEntry.fromFoodEntry(FoodEntry e)
      : id = e.id,
        name = TextEditingController(text: e.name),
        grams = TextEditingController(text: e.grams.toStringAsFixed(0)),
        calories = TextEditingController(text: e.calories.toString()),
        protein = TextEditingController(text: e.proteinG.toStringAsFixed(1)),
        carbs = TextEditingController(text: e.carbsG.toStringAsFixed(1)),
        fat = TextEditingController(text: e.fatG.toStringAsFixed(1));

  _EditableEntry.blank()
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

class _PhotoScanScreenState extends State<PhotoScanScreen> {
  File? _photo;
  bool _loading = false;
  String? _error;
  List<_EditableEntry> _editable = [];

  @override
  void dispose() {
    for (final e in _editable) {
      e.dispose();
    }
    super.dispose();
  }

  Future<void> _takePhoto() async {
    final apiKey = LocalStorageService.loadGeminiApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      if (!mounted) return;
      final go = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Configure sua chave do Gemini'),
          content: const Text(
            'Pra usar o scanner por foto, você precisa cadastrar uma chave '
            'gratuita da API do Gemini nas Configurações.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Ir pra Configurações')),
          ],
        ),
      );
      if (go == true && mounted) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
      }
      return;
    }

    final picked = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 80);
    if (picked == null) return;

    final file = File(picked.path);
    setState(() {
      _photo = file;
      _loading = true;
      _error = null;
      for (final e in _editable) {
        e.dispose();
      }
      _editable = [];
    });

    // Pergunta se pode salvar a foto na galeria (pasta dedicada do app),
    // pra montar o histórico visual de evolução ao longo do tempo.
    try {
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) await Gal.requestAccess();
      if (await Gal.hasAccess()) {
        await Gal.putImage(file.path, album: 'NutriSnap');
      }
    } catch (_) {
      // Sem permissão ou galeria indisponível — segue o fluxo normalmente,
      // isso não deve travar o registro do alimento.
    }

    try {
      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);
      final raw = await GeminiService.analyzeFoodPhoto(apiKey: apiKey, base64Image: base64Image);
      final parsed = raw
          .map((m) => FoodEntry(
                id: '${DateTime.now().microsecondsSinceEpoch}_${m['name']}',
                name: m['name'] ?? 'Alimento',
                grams: (m['grams'] as num?)?.toDouble() ?? 0,
                calories: (m['calories'] as num?)?.round() ?? 0,
                proteinG: (m['protein_g'] as num?)?.toDouble() ?? 0,
                carbsG: (m['carbs_g'] as num?)?.toDouble() ?? 0,
                fatG: (m['fat_g'] as num?)?.toDouble() ?? 0,
              ))
          .toList();
      setState(() {
        _editable = parsed.map((e) => _EditableEntry.fromFoodEntry(e)).toList();
      });
    } catch (e) {
      setState(() => _error = 'Não consegui analisar a foto: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _removeRow(_EditableEntry entry) {
    setState(() {
      _editable.remove(entry);
      entry.dispose();
    });
  }

  void _addBlankRow() {
    setState(() => _editable.add(_EditableEntry.blank()));
  }

  void _confirmAndSave() {
    final entries = _editable.map((e) => e.toFoodEntry()).toList();
    Navigator.of(context).pop(entries);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scanner de prato (IA)')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_photo != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(_photo!, height: 180, fit: BoxFit.cover),
              ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loading ? null : _takePhoto,
              icon: const Icon(Icons.camera_alt_rounded),
              label: Text(_photo == null ? 'Tirar foto do prato' : 'Tirar outra foto'),
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Analisando o prato...', style: TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
            if (_error != null) Text(_error!, style: const TextStyle(color: AppColors.danger)),
            if (!_loading && _editable.isNotEmpty)
              Expanded(
                child: ListView(
                  children: [
                    const Text(
                      'Confira e corrija antes de salvar:',
                      style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'A IA pode errar — ajuste nome, peso ou macros, remova o que estiver errado ou adicione o que ela esqueceu.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    ..._editable.map((entry) => _EditableFoodCard(
                          key: ValueKey(entry.id),
                          entry: entry,
                          onRemove: () => _removeRow(entry),
                        )),
                    const SizedBox(height: 4),
                    OutlinedButton.icon(
                      onPressed: _addBlankRow,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Adicionar item que a IA esqueceu'),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _editable.isEmpty ? null : _confirmAndSave,
                      child: const Text('Confirmar e salvar no diário'),
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

/// Card editável de um item identificado pela IA (ou adicionado manualmente
/// nessa etapa de conferência). Nome + peso em uma linha, macros em outra.
class _EditableFoodCard extends StatelessWidget {
  final _EditableEntry entry;
  final VoidCallback onRemove;

  const _EditableFoodCard({required Key key, required this.entry, required this.onRemove}) : super(key: key);

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
