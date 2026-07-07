import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Tela inicial: por enquanto mostra um placeholder de resumo do dia.
/// Nas próximas entregas entram aqui: diário de refeições, contador de água,
/// registro por foto (IA) e notificações.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hoje')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Resumo do dia',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  const Text(
                    'Diário de refeições, contador de água e registro por foto '
                    'com IA chegam na próxima atualização.',
                    style: TextStyle(color: AppColors.textSecondary),
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
