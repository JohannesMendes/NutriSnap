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
/// zero. Aqui é onde o histórico completo fica disponível pra consulta.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dates = LocalStorageService.loadDiaryDatesWithEntries();

    return Scaffold(
      appBar: AppBar(title: const Text('Histórico')),
      body: dates.isEmpty
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
              itemCount: dates.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final date = dates[i];
                final meals = LocalStorageService.loadMealsForDate(date);
                final totalCalories = meals.fold(0, (sum, m) => sum + m.totalCalories);
                final weekday = _weekdayNames[date.weekday - 1];
                final label = '$weekday, ${date.day} de ${_monthNames[date.month - 1]}';

                return Card(
                  child: ListTile(
                    title: Text(label),
                    subtitle: Text('$totalCalories kcal registradas'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => DiaryScreen(date: date)),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
