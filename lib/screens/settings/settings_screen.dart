import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/local_storage_service.dart';
import '../../services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _apiKeyCtrl;
  late Map<String, String> _reminders;

  @override
  void initState() {
    super.initState();
    _apiKeyCtrl = TextEditingController(text: LocalStorageService.loadGeminiApiKey() ?? '');
    _reminders = LocalStorageService.loadReminderSettings();
  }

  Future<void> _pickTime(String key) async {
    final parts = _reminders[key]!.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
    );
    if (picked == null) return;
    setState(() {
      _reminders[key] =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _save() async {
    await LocalStorageService.saveGeminiApiKey(_apiKeyCtrl.text.trim());
    await LocalStorageService.saveReminderSettings(_reminders);
    await NotificationService.requestPermission();
    await NotificationService.rescheduleAll();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Configurações salvas!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Scanner de foto (IA)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text(
            'Cole aqui sua chave gratuita da API do Gemini (Google AI Studio) '
            'pra usar o reconhecimento de alimentos por foto.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _apiKeyCtrl,
            obscureText: true,
            decoration: const InputDecoration(hintText: 'Chave da API do Gemini'),
          ),
          const SizedBox(height: 28),
          Text('Lembretes de refeição', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          _TimeRow(label: 'Café da manhã', value: _reminders['breakfast']!, onTap: () => _pickTime('breakfast')),
          _TimeRow(label: 'Almoço', value: _reminders['lunch']!, onTap: () => _pickTime('lunch')),
          _TimeRow(label: 'Jantar', value: _reminders['dinner']!, onTap: () => _pickTime('dinner')),
          const SizedBox(height: 28),
          Text('Lembretes de água', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          _TimeRow(label: 'Início', value: _reminders['water_start']!, onTap: () => _pickTime('water_start')),
          _TimeRow(label: 'Fim', value: _reminders['water_end']!, onTap: () => _pickTime('water_end')),
          const SizedBox(height: 28),
          ElevatedButton(onPressed: _save, child: const Text('Salvar configurações')),
        ],
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  const _TimeRow({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: OutlinedButton(onPressed: onTap, child: Text(value)),
    );
  }
}
