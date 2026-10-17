import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/local_storage_service.dart';
import '../diary/diary_screen.dart';

const _weekdayInitials = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];
const _monthNames = [
  'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
  'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
];

/// Calendário dos dias em que o app foi usado (teve comida ou água
/// registrada). Toque num dia marcado pra rever o diário daquele dia;
/// segure o dedo pra excluí-lo. Dias com mais de 30 dias são apagados
/// automaticamente (ver LocalStorageService.purgeOldDays).
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Set<DateTime> _used;
  late DateTime _month; // sempre o dia 1 do mês exibido
  late final DateTime _today;
  late final DateTime _oldestMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    _month = DateTime(_today.year, _today.month);
    final oldest = _today.subtract(const Duration(days: LocalStorageService.retentionDays));
    _oldestMonth = DateTime(oldest.year, oldest.month);
    _used = LocalStorageService.loadUsedDates();
    // Garante que nada além do limite de 30 dias fique guardado.
    LocalStorageService.purgeOldDays().then((_) {
      if (mounted) setState(() => _used = LocalStorageService.loadUsedDates());
    });
  }

  bool get _canGoBack => _month.isAfter(_oldestMonth);
  bool get _canGoForward => _month.isBefore(DateTime(_today.year, _today.month));

  void _changeMonth(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  bool _inRetentionWindow(DateTime d) {
    final oldest = _today.subtract(const Duration(days: LocalStorageService.retentionDays));
    return !d.isBefore(oldest) && !d.isAfter(_today);
  }

  String _label(DateTime d) => '${d.day} de ${_monthNames[d.month - 1].toLowerCase()}';

  Future<void> _openDay(DateTime day) async {
    if (!_used.contains(day)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum registro neste dia.')),
      );
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => DiaryScreen(date: day)));
    if (mounted) setState(() => _used = LocalStorageService.loadUsedDates());
  }

  Future<void> _confirmDelete(DateTime day) async {
    if (!_used.contains(day)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Excluir este dia?'),
        content: Text(
          'Isso vai apagar permanentemente as refeições, a água e a foto '
          'registradas em ${_label(day)}. Essa ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await LocalStorageService.deleteDay(day);
      if (!mounted) return;
      setState(() => _used = LocalStorageService.loadUsedDates());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_label(day)} foi excluído.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leading = DateTime(_month.year, _month.month, 1).weekday % 7; // domingo = 0
    final cellCount = leading + daysInMonth;
    final usedInWindow = _used.where(_inRetentionWindow).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Calendário')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: _canGoBack ? () => _changeMonth(-1) : null,
              ),
              Text('${_monthNames[_month.month - 1]} ${_month.year}',
                  style: Theme.of(context).textTheme.titleMedium),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: _canGoForward ? () => _changeMonth(1) : null,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final w in _weekdayInitials)
                Expanded(
                  child: Center(
                    child: Text(w, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemCount: cellCount,
            itemBuilder: (context, i) {
              if (i < leading) return const SizedBox.shrink();
              final day = DateTime(_month.year, _month.month, i - leading + 1);
              final used = _used.contains(day);
              final isToday = day == _today;
              final outOfRange = !_inRetentionWindow(day);
              return GestureDetector(
                onTap: outOfRange ? null : () => _openDay(day),
                onLongPress: outOfRange ? null : () => _confirmDelete(day),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: used ? AppColors.primary : Colors.transparent,
                    border: isToday ? Border.all(color: AppColors.primary, width: 2) : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${day.day}',
                    style: TextStyle(
                      color: used
                          ? Colors.black
                          : (outOfRange ? AppColors.textSecondary.withOpacity(0.35) : null),
                      fontWeight: used || isToday ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    usedInWindow == 1
                        ? '1 dia usado nos últimos 30 dias'
                        : '$usedInWindow dias usados nos últimos 30 dias',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Toque num dia marcado pra rever. Segure o dedo num dia pra excluí-lo. '
                    'Pra manter o app leve, os registros são guardados por 30 dias e depois '
                    'apagados automaticamente.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
