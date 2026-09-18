import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/local_storage_service.dart';
import '../../services/notification_service.dart';
import '../../services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Map<String, String> _reminders;
  late bool _savePhotosToGallery;
  late bool _mealsEnabled;
  late bool _waterEnabled;

  @override
  void initState() {
    super.initState();
    _reminders = LocalStorageService.loadReminderSettings();
    _savePhotosToGallery = LocalStorageService.loadSavePhotosToGallery();
    _mealsEnabled = _reminders['meals_enabled'] != 'false';
    _waterEnabled = _reminders['water_enabled'] != 'false';
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
    _reminders['meals_enabled'] = _mealsEnabled.toString();
    _reminders['water_enabled'] = _waterEnabled.toString();
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
          Text('Lembretes de refeição', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ativar lembretes de refeição'),
            value: _mealsEnabled,
            onChanged: (v) => setState(() => _mealsEnabled = v),
          ),
          Opacity(
            opacity: _mealsEnabled ? 1 : 0.4,
            child: IgnorePointer(
              ignoring: !_mealsEnabled,
              child: Column(
                children: [
                  _TimeRow(label: 'Café da manhã', value: _reminders['breakfast']!, onTap: () => _pickTime('breakfast')),
                  _TimeRow(label: 'Almoço', value: _reminders['lunch']!, onTap: () => _pickTime('lunch')),
                  _TimeRow(label: 'Jantar', value: _reminders['dinner']!, onTap: () => _pickTime('dinner')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text('Lembretes de água', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ativar lembretes de água'),
            value: _waterEnabled,
            onChanged: (v) => setState(() => _waterEnabled = v),
          ),
          Opacity(
            opacity: _waterEnabled ? 1 : 0.4,
            child: IgnorePointer(
              ignoring: !_waterEnabled,
              child: Column(
                children: [
                  _TimeRow(label: 'Início', value: _reminders['water_start']!, onTap: () => _pickTime('water_start')),
                  _TimeRow(label: 'Fim', value: _reminders['water_end']!, onTap: () => _pickTime('water_end')),
                ],
              ),
            ),
          ),
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
          const SizedBox(height: 28),
          Text('Conta', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger)),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: AppColors.surface,
                  title: const Text('Sair da conta?'),
                  content: const Text('Você vai precisar entrar de novo pra usar o app.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
                    ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Sair')),
                  ],
                ),
              );
              if (confirmed == true) {
                // Não navega manualmente — o AuthGate detecta o logout e
                // troca pra tela de login sozinho.
                await AuthService.signOut();
              }
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sair da conta'),
          ),
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
