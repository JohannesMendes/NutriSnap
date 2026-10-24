import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../services/pix_payment_service.dart';

/// Tela do Pix: mostra o QR code e o "copia e cola", e acompanha o
/// pagamento em tempo real. Quando o servidor confirma, o plano já está
/// liberado — aqui só avisamos e a pessoa volta pro app.
class PixCheckoutScreen extends StatefulWidget {
  final PixCharge charge;
  final String planTitle;
  const PixCheckoutScreen({super.key, required this.charge, required this.planTitle});

  @override
  State<PixCheckoutScreen> createState() => _PixCheckoutScreenState();
}

class _PixCheckoutScreenState extends State<PixCheckoutScreen> {
  StreamSubscription<String>? _sub;
  Timer? _timer;
  String _status = 'pendente';
  Duration _remaining = Duration.zero;
  Uint8List? _qrBytes;

  bool get _approved => _status == 'aprovado';
  bool get _failed => const ['rejeitado', 'cancelado', 'expirado'].contains(_status);
  bool get _timeUp => !_approved && _remaining <= Duration.zero;

  @override
  void initState() {
    super.initState();
    try {
      if (widget.charge.qrCodeBase64.isNotEmpty) _qrBytes = base64Decode(widget.charge.qrCodeBase64);
    } catch (_) {}
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _sub = PixPaymentService.watchStatus(widget.charge.paymentDocId).listen((s) {
      if (mounted) setState(() => _status = s);
    });
  }

  void _tick() {
    final left = widget.charge.expiresAt.difference(DateTime.now());
    if (mounted) setState(() => _remaining = left.isNegative ? Duration.zero : left);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  String get _countdown {
    final m = _remaining.inMinutes.toString().padLeft(2, '0');
    final s = (_remaining.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get _amountLabel => 'R\$ ${widget.charge.amount.toStringAsFixed(2).replaceAll('.', ',')}';

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.charge.qrCode));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Código Pix copiado! Cole no app do seu banco.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pagamento via Pix')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: _approved ? _successContent() : _payContent(),
        ),
      ),
    );
  }

  List<Widget> _successContent() => [
        const SizedBox(height: 40),
        const Icon(Icons.check_circle_rounded, size: 80, color: AppColors.primary),
        const SizedBox(height: 16),
        const Center(
          child: Text('Pagamento confirmado!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Seu plano ${widget.planTitle} já está ativo. Obrigado!',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Continuar'),
        ),
      ];

  List<Widget> _payContent() => [
        Center(
          child: Text('Plano ${widget.planTitle}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(_amountLabel,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        ),
        const SizedBox(height: 20),
        if (_qrBytes != null)
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Image.memory(_qrBytes!, width: 220, height: 220),
            ),
          ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _timeUp ? null : _copy,
          icon: const Icon(Icons.copy_rounded),
          label: const Text('Copiar código Pix (copia e cola)'),
        ),
        const SizedBox(height: 20),
        if (_failed || _timeUp)
          Column(
            children: [
              const Text(
                'Este Pix expirou ou não foi concluído.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.danger, fontSize: 13),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Gerar novo Pix'),
              ),
            ],
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 10),
              Text('Aguardando o pagamento... expira em $_countdown',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ],
          ),
        const SizedBox(height: 16),
        const Text(
          'Abra o app do seu banco, escolha Pix e leia o QR code ou cole o código. '
          'Assim que o pagamento for confirmado, esta tela avisa e seu plano é liberado sozinho — '
          'não precisa fazer mais nada.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.4),
        ),
      ];
}
