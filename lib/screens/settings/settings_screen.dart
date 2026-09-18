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
  late Map<String, String> _reminders;
  late bool _savePhotosToGallery;

  @override
  void initState() {
    super.initState();
    _reminders = LocalStorageService.loadReminderSettings();
    _savePhotosToGallery = LocalStorageService.loadSavePhotosToGallery();
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
    await LocalStorageService.saveReminderSettings(_reminders);
    await LocalStorageService.setSavePhotosToGallery(_savePhotosToGallery);
    await LocalStorageService.setAskedGalleryPreference(true);
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
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'O reconhecimento de alimentos por foto e por texto roda em um '
                    'servidor seguro — nenhuma chave de API fica guardada ou '
                    'exposta no aparelho.',
                    style: TextStyle(color: AppColors.primary, fontSize: 12),
                  ),
                ),
              ],
            ),
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
          Text('Fotos das refeições', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Salvar fotos na galeria'),
            subtitle: const Text(
              'Guarda uma cópia de cada foto de prato na galeria do aparelho, '
              'pra acompanhar sua evolução visual ao longo do tempo. Se '
              'desligado, a foto é usada só na hora e descartada em seguida.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            value: _savePhotosToGallery,
            onChanged: (v) => setState(() => _savePhotosToGallery = v),
          ),
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
