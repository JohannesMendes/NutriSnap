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

class _PhotoScanScreenState extends State<PhotoScanScreen> {
  File? _photo;
  bool _loading = false;
  String? _error;
  List<FoodEntry> _results = [];

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
      _results = [];
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
      setState(() {
        _results = raw
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
      });
    } catch (e) {
      setState(() => _error = 'Não consegui analisar a foto: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
                child: Image.file(_photo!, height: 220, fit: BoxFit.cover),
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
            if (_results.isNotEmpty)
              Expanded(
                child: ListView(
                  children: [
                    const Text('Identificado pela IA:', style: TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    ..._results.map((e) => Card(
                          child: ListTile(
                            title: Text(e.name),
                            subtitle: Text(
                              '${e.grams.toStringAsFixed(0)}g · ${e.calories} kcal · P:${e.proteinG.toStringAsFixed(0)}g C:${e.carbsG.toStringAsFixed(0)}g G:${e.fatG.toStringAsFixed(0)}g',
                            ),
                          ),
                        )),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(_results),
                      child: const Text('Adicionar tudo ao diário'),
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
