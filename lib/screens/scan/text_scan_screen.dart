import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/gemini_service.dart';
import '../../services/local_storage_service.dart';
import '../settings/settings_screen.dart';
import 'ai_review_widgets.dart';

/// Entrada manual "inteligente": o usuário digita livremente o que comeu
/// (ex: "4 fatias de pão de forma", "3 ovos mexidos e uma fatia de pão"),
/// o texto é interpretado pela IA (Gemini, texto puro) e cai na mesma tela
/// de conferência usada pelo scanner de foto — sem exigir que o usuário
/// preencha macros na mão nem que o alimento exista em uma lista fixa.
class TextScanScreen extends StatefulWidget {
  const TextScanScreen({super.key});

  @override
  State<TextScanScreen> createState() => _TextScanScreenState();
}

class _TextScanScreenState extends State<TextScanScreen> {
  final _descriptionCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  List<EditableEntry> _editable = [];

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    for (final e in _editable) {
      e.dispose();
    }
    super.dispose();
  }

  Future<void> _analyze() async {
    final description = _descriptionCtrl.text.trim();
    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Descreva o que você comeu, ex: "4 fatias de pão de forma".')),
      );
      return;
    }

    final apiKey = LocalStorageService.loadGeminiApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      if (!mounted) return;
      final go = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Configure sua chave do Gemini'),
          content: const Text(
            'Pra usar a interpretação inteligente de texto, você precisa cadastrar '
            'uma chave gratuita da API do Gemini nas Configurações.',
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

    setState(() {
      _loading = true;
      _error = null;
      for (final e in _editable) {
        e.dispose();
      }
      _editable = [];
    });

    try {
      final raw = await GeminiService.analyzeFoodText(apiKey: apiKey, description: description);
      // Mostra a quantidade/unidade que a IA detectou junto do nome (ex:
      // "Pão de forma (4 fatia)"), pra ficar fácil de conferir.
      final parsed = parseGeminiFoodList(raw);
      setState(() {
        _editable = parsed.map((e) => EditableEntry.fromFoodEntry(e)).toList();
      });
    } catch (e) {
      setState(() => _error = 'Não consegui interpretar o texto: $e');
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
      appBar: AppBar(title: const Text('Adicionar por texto (IA)')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _descriptionCtrl,
              maxLines: 3,
              minLines: 1,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                hintText: 'Ex: "4 fatias de pão de forma", "3 ovos mexidos e '
                    'uma fatia de pão", "café com leite e 2 colheres de açúcar"...',
              ),
              onSubmitted: (_) => _loading ? null : _analyze(),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loading ? null : _analyze,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: Text(_editable.isEmpty ? 'Interpretar com IA' : 'Interpretar novamente'),
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
                      Text('Interpretando o texto...', style: TextStyle(color: AppColors.textSecondary)),
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
