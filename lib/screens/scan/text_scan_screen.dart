import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../theme/app_theme.dart';
import '../../services/gemini_service.dart';
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

  // Gravação de áudio -> transcrição -> cálculo automático.
  final _recorder = AudioRecorder();
  Timer? _autoStop;
  bool _recording = false;
  bool _transcribing = false;

  @override
  void dispose() {
    _autoStop?.cancel();
    _recorder.dispose();
    _descriptionCtrl.dispose();
    for (final e in _editable) {
      e.dispose();
    }
    super.dispose();
  }

  Future<void> _toggleRecording() => _recording ? _stopAndTranscribe() : _startRecording();

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permita o uso do microfone para gravar.')),
      );
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/refeicao_${DateTime.now().millisecondsSinceEpoch}.wav';
    // WAV 16 kHz mono: 60 s ≈ 2 MB, bem abaixo do limite da Netlify Function.
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1),
      path: path,
    );
    if (!mounted) return;
    setState(() => _recording = true);
    _autoStop = Timer(const Duration(seconds: 60), _stopAndTranscribe);
  }

  Future<void> _stopAndTranscribe() async {
    _autoStop?.cancel();
    final path = await _recorder.stop();
    if (!mounted) return;
    setState(() {
      _recording = false;
      _transcribing = true;
      _error = null;
    });
    if (path == null) {
      setState(() => _transcribing = false);
      return;
    }
    try {
      final bytes = await File(path).readAsBytes();
      final text = await GeminiService.transcribeAudio(base64Audio: base64Encode(bytes));
      File(path).delete().ignore();
      // O usuário vê (e pode editar) o que foi dito; o cálculo roda direto.
      _descriptionCtrl.text = text;
      if (mounted) setState(() => _transcribing = false);
      await _analyze();
    } on GeminiApiException catch (e) {
      if (mounted) setState(() { _error = e.friendlyMessage; _transcribing = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Falha ao gravar o áudio. Tente de novo.'; _transcribing = false; });
    }
  }

  Future<void> _analyze() async {
    final description = _descriptionCtrl.text.trim();
    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Descreva o que você comeu, ex: "4 fatias de pão de forma".')),
      );
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
      final raw = await GeminiService.analyzeFoodText(description: description);
      // Mostra a quantidade/unidade que a IA detectou junto do nome (ex:
      // "Pão de forma (4 fatia)"), pra ficar fácil de conferir.
      final parsed = parseGeminiFoodList(raw);
      setState(() {
        _editable = parsed.map((e) => EditableEntry.fromFoodEntry(e)).toList();
      });
    } on GeminiApiException catch (e) {
      setState(() => _error = e.friendlyMessage);
    } catch (e) {
      setState(() => _error = 'Algo deu errado ao interpretar o texto. Tente novamente.');
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
              decoration: InputDecoration(
                hintText: 'Ex: "4 fatias de pão de forma", "3 ovos mexidos e '
                    'uma fatia de pão", "café com leite e 2 colheres de açúcar"...',
                suffixIcon: IconButton(
                  tooltip: _recording ? 'Parar e transcrever' : 'Gravar áudio',
                  onPressed: (_loading || _transcribing) ? null : _toggleRecording,
                  icon: _transcribing
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(
                          _recording ? Icons.stop_circle_rounded : Icons.mic_rounded,
                          color: _recording ? AppColors.danger : AppColors.primary,
                        ),
                ),
              ),
              onSubmitted: (_) => _loading ? null : _analyze(),
            ),
            if (_recording)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Gravando... toque no botão para parar (máx. 60 s).',
                    style: TextStyle(color: AppColors.danger, fontSize: 12)),
              ),
            if (_transcribing)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Transcrevendo o áudio...',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
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
                    EditableTotalsCard(entries: _editable),
                    const SizedBox(height: 12),
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
