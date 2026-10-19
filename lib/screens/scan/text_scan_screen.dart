import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
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

  // Ditado por voz (reconhecimento do próprio Android) -> cálculo automático.
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechReady = false;
  bool _listening = false;
  String _baseText = '';
  DateTime? _sessionEnd;
  static const _maxChars = 5000;
  static const _maxSession = Duration(seconds: 60);

  @override
  void dispose() {
    _speech.cancel();
    _descriptionCtrl.dispose();
    for (final e in _editable) {
      e.dispose();
    }
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (_listening) {
      _listening = false; // parada manual: não reinicia sozinho
      await _speech.stop();
      await Future.delayed(const Duration(milliseconds: 500)); // espera a última palavra chegar
      _finishDictation();
      return;
    }
    FocusScope.of(context).unfocus();
    if (!_speechReady) {
      _speechReady = await _speech.initialize(
        onStatus: _onSpeechStatus,
        onError: _onSpeechError,
      );
      if (!_speechReady) {
        if (!mounted) return;
        setState(() => _error =
            'Não consegui acessar o microfone ou o reconhecimento de voz. '
            'Confira a permissão do microfone nas configurações do app e se o '
            'celular tem o "Google" / "Serviços de fala do Google" ativo.');
        return;
      }
    }
    _baseText = _descriptionCtrl.text.trim();
    _sessionEnd = DateTime.now().add(_maxSession);
    setState(() {
      _listening = true;
      _error = null;
    });
    await _startListenChunk();
  }

  /// O Android encerra o reconhecimento sozinho depois de uns segundos de
  /// silêncio. Aqui a gente religa em seguida (guardando o que já foi dito)
  /// até a pessoa tocar em parar ou completar 1 minuto.
  Future<void> _startListenChunk() async {
    final remaining = _sessionEnd!.difference(DateTime.now());
    if (remaining <= const Duration(seconds: 1)) {
      _listening = false;
      _finishDictation();
      return;
    }
    await _speech.listen(
      localeId: 'pt_BR',
      listenFor: remaining,
      pauseFor: const Duration(seconds: 10),
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: false,
        listenMode: stt.ListenMode.dictation,
      ),
      onResult: (r) {
        if (!mounted) return;
        final joined = _baseText.isEmpty ? r.recognizedWords : '$_baseText ${r.recognizedWords}';
        setState(() => _descriptionCtrl.text =
            joined.length > _maxChars ? joined.substring(0, _maxChars) : joined);
        if (r.finalResult) _baseText = _descriptionCtrl.text.trim();
      },
    );
  }

  void _onSpeechStatus(String status) {
    if (!_listening || !mounted) return;
    if (status == 'done' || status == 'notListening') {
      // Terminou um trecho sozinho (silêncio): continua ouvindo.
      _baseText = _descriptionCtrl.text.trim();
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted && _listening) _startListenChunk();
      });
    }
  }

  void _finishDictation() {
    if (!mounted) return;
    setState(() => _listening = false);
    final spoken = _descriptionCtrl.text.trim();
    if (spoken.isNotEmpty && !_loading) {
      _analyze(); // manda direto pro cálculo nutricional
    }
  }

  void _onSpeechError(dynamic error) {
    if (!mounted) return;
    final code = (error.errorMsg ?? '').toString();
    String msg;
    if (_listening && (code.contains('no_match') || code.contains('speech_timeout'))) {
      // Silêncio num trecho: segue ouvindo até o fim da sessão.
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted && _listening) _startListenChunk();
      });
      return;
    }
    if (code.contains('no_match') || code.contains('speech_timeout')) {
      msg = 'Não ouvi nada. Toque no microfone e fale perto do celular.';
    } else if (code.contains('permission')) {
      msg = 'Sem permissão do microfone. Libere em Configurações > Apps > NutriSnap > Permissões.';
    } else if (code.contains('network')) {
      msg = 'Sem internet para o reconhecimento de voz. Verifique sua conexão.';
    } else {
      msg = 'Erro no reconhecimento de voz ($code). Tente de novo.';
    }
    setState(() {
      _listening = false;
      _error = msg;
    });
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
              maxLength: _maxChars,
              decoration: InputDecoration(
                hintText: 'Ex: "4 fatias de pão de forma", "3 ovos mexidos e '
                    'uma fatia de pão", "café com leite e 2 colheres de açúcar"...',
                suffixIcon: IconButton(
                  tooltip: _listening ? 'Parar' : 'Falar o que comeu',
                  onPressed: _loading ? null : _toggleListening,
                  icon: Icon(
                    _listening ? Icons.stop_circle_rounded : Icons.mic_rounded,
                    color: _listening ? AppColors.danger : AppColors.primary,
                  ),
                ),
              ),
              onSubmitted: (_) => _loading ? null : _analyze(),
            ),
            if (_listening)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Ouvindo (até 1 minuto)... fale o que você comeu e toque no botão pra terminar.',
                    style: TextStyle(color: AppColors.danger, fontSize: 12)),
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
