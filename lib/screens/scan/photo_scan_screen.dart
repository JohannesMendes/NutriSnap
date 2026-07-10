import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gal/gal.dart';
import '../../theme/app_theme.dart';
import '../../services/gemini_service.dart';
import '../../services/local_storage_service.dart';
import '../settings/settings_screen.dart';
import 'ai_review_widgets.dart';

/// O core do app: tira foto do prato (de uma fruta a um prato completo),
/// a IA (Gemini) identifica os alimentos, estima peso e macros, e o
/// usuário confirma antes de jogar tudo pro diário.
class PhotoScanScreen extends StatefulWidget {
  const PhotoScanScreen({super.key});

  @override
  State<PhotoScanScreen> createState() => _PhotoScanScreenState();
}

class _PhotoScanScreenState extends State<PhotoScanScreen> {
  Uint8List? _photoBytes;
  bool _loading = false;
  String? _error;
  List<EditableEntry> _editable = [];

  @override
  void dispose() {
    for (final e in _editable) {
      e.dispose();
    }
    super.dispose();
  }

  /// Na primeira vez que o usuário for tirar uma foto, pergunta se ele
  /// quer salvar as fotos das refeições na galeria (opt-in). A resposta
  /// fica salva e não pergunta de novo — pode ser trocada depois em
  /// Configurações.
  Future<bool> _resolveGalleryPreference() async {
    if (LocalStorageService.hasAskedGalleryPreference()) {
      return LocalStorageService.loadSavePhotosToGallery();
    }
    if (!mounted) return false;
    final wantsSave = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text('Salvar fotos das refeições?'),
            content: const Text(
              'Deseja salvar as fotos das suas refeições na galeria para '
              'acompanhar sua evolução visual ao longo dos meses? Você pode '
              'mudar isso depois em Configurações.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Não salvar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Salvar na galeria'),
              ),
            ],
          ),
        ) ??
        false;
    await LocalStorageService.setSavePhotosToGallery(wantsSave);
    await LocalStorageService.setAskedGalleryPreference(true);
    return wantsSave;
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

    final saveToGallery = await _resolveGalleryPreference();

    final picked = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 80);
    if (picked == null) return;

    final file = File(picked.path);
    final bytes = await file.readAsBytes();

    setState(() {
      _photoBytes = bytes;
      _loading = true;
      _error = null;
      for (final e in _editable) {
        e.dispose();
      }
      _editable = [];
    });

    // Se o usuário optou por salvar, copia pra galeria (pasta dedicada do
    // app) antes de descartar o arquivo temporário.
    if (saveToGallery) {
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
    }

    // O arquivo temporário criado pela câmera não tem mais utilidade a
    // partir daqui — já lemos os bytes (usados na tela e no envio pra IA)
    // e, se o usuário quis, já copiamos pra galeria. Deleta pra não deixar
    // lixo no armazenamento do aparelho, independente da escolha acima.
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Falha ao deletar não deve travar o fluxo.
    }

    try {
      final base64Image = base64Encode(bytes);
      final raw = await GeminiService.analyzeFoodPhoto(apiKey: apiKey, base64Image: base64Image);
      // Mostra a contagem que a IA usou junto do nome (ex: "Pão de forma
      // (3 fatia)"), pra ficar óbvio de conferir se ela contou certo.
      final parsed = parseGeminiFoodList(raw);
      setState(() {
        _editable = parsed.map((e) => EditableEntry.fromFoodEntry(e)).toList();
      });
    } on GeminiApiException catch (e) {
      setState(() => _error = e.friendlyMessage);
    } catch (e) {
      setState(() => _error = 'Algo deu errado ao analisar a foto. Tente novamente.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _removeRow(EditableEntry entry) {
    setState(() {
      _editable.remove(entry);
      entry.dispose();
    });
  }

  void _addBlankRow() {
    setState(() => _editable.add(EditableEntry.blank()));
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
            if (_photoBytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(_photoBytes!, height: 180, fit: BoxFit.cover),
              ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loading ? null : _takePhoto,
              icon: const Icon(Icons.camera_alt_rounded),
              label: Text(_photoBytes == null ? 'Tirar foto do prato' : 'Tirar outra foto'),
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
                    ..._editable.map((entry) => EditableFoodCard(
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
