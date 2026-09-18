import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/local_storage_service.dart';
import '../diary/diary_screen.dart';

const _weekdayNames = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
const _monthNames = [
  'jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'
];

/// Lista os dias anteriores já registrados. Cada dia é salvo com sua
/// própria chave desde o momento em que é criado, então a "virada de dia"
/// não apaga nada — só o dashboard de hoje que reseta visualmente pra
/// zero. Aqui é onde o histórico completo fica disponível pra consulta,
/// e também onde o usuário pode excluir um dia específico se quiser.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late List<DateTime> _dates;

  @override
  void initState() {
    super.initState();
    _dates = LocalStorageService.loadDiaryDatesWithEntries();
  }

  String _label(DateTime date) {
    final weekday = _weekdayNames[date.weekday - 1];
    return '$weekday, ${date.day} de ${_monthNames[date.month - 1]}';
  }

  Future<void> _confirmDelete(DateTime date) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Excluir este dia?'),
        content: Text(
          'Isso vai apagar permanentemente todas as refeições, a água e a '
          'foto registradas em ${_label(date)}. Essa ação não pode ser desfeita.',
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
      await LocalStorageService.deleteDay(date);
      if (!mounted) return;
      setState(() => _dates.remove(date));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_label(date)} foi excluído do histórico.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Histórico')),
      body: _dates.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Ainda não há dias registrados no histórico.\n'
                  'Assim que você virar o dia com alimentos no diário, ele aparece aqui.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: _dates.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final date = _dates[i];
                final meals = LocalStorageService.loadMealsForDate(date);
                final totalCalories = meals.fold(0, (sum, m) => sum + m.totalCalories);
                final label = _label(date);

                return Dismissible(
                  key: ValueKey(date.toIso8601String()),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (_) async {
                    await _confirmDelete(date);
                    // Sempre retorna false: quando a exclusão é confirmada,
                    // já removemos o item via setState acima (a lista some
                    // suavemente pelo AnimatedList interno do
                    // ListView.separated); deixar o Dismissible também
                    // remover causaria remoção duplicada/erro de chave.
                    return false;
                  },
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                  ),
                  child: Card(
                    child: ListTile(
                      title: Text(label),
                      subtitle: Text('$totalCalories kcal registradas'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                            tooltip: 'Excluir dia',
                            onPressed: () => _confirmDelete(date),
                          ),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => DiaryScreen(date: date)),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
