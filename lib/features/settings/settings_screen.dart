import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../providers/monitoring_provider.dart';
import '../../providers/pairing_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/notification_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/big_button.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monitoring = ref.watch(monitoringProvider);
    final pairing = ref.watch(pairingProvider);
    final settings = ref.watch(settingsProvider);

    return AppScaffold(
      title: AppStrings.settings,
      body: ListView(
        children: [
          if (pairing.role == DeviceRole.baby) ...[
            const SizedBox(height: 8),
            ListTile(
              title: const Text('Sensitivity threshold'),
              subtitle: Text('${monitoring.thresholdDb.toStringAsFixed(0)} dB'),
              trailing: const Icon(Icons.tune),
            ),
            Slider(
              min: 50,
              max: 90,
              divisions: 40,
              value: monitoring.thresholdDb,
              label: '${monitoring.thresholdDb.toStringAsFixed(0)} dB',
              onChanged: (v) => ref.read(monitoringProvider.notifier).setThreshold(v),
            ),
            const Divider(),
            ListTile(
              title: const Text('Alert repeat'),
              subtitle: Text(
                '${settings.alertRepeatCount}× — chime plays back-to-back '
                'on the Parent unit each time the threshold is crossed.',
              ),
              trailing: const Icon(Icons.repeat),
            ),
            Slider(
              min: SettingsNotifier.alertRepeatMin.toDouble(),
              max: SettingsNotifier.alertRepeatMax.toDouble(),
              divisions:
                  SettingsNotifier.alertRepeatMax - SettingsNotifier.alertRepeatMin,
              value: settings.alertRepeatCount.toDouble(),
              label: '${settings.alertRepeatCount}×',
              onChanged: (v) =>
                  ref.read(settingsProvider.notifier).setAlertRepeatCount(v.round()),
            ),
            const Divider(),
          ],
          if (pairing.role == DeviceRole.parent) ...[
            ListTile(
              leading: const Icon(Icons.notifications_active, color: AppColors.danger),
              title: const Text(AppStrings.testAlert),
              subtitle: const Text('Fires a sample alert on this device.'),
              onTap: () => NotificationService.instance.showAlert(
                title: 'Test alert',
                body: 'This is what a real alert looks like.',
              ),
            ),
            const Divider(),
          ],
          const SizedBox(height: 8),
          ListTile(
            title: Text(
              'Role: ${pairing.role.name}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          if (pairing.pairId != null)
            ListTile(
              title: Text(
                'Pair code: ${pairing.pairId}',
                style: const TextStyle(color: AppColors.textSecondary, letterSpacing: 2),
              ),
            ),
          const SizedBox(height: 24),
          BigButton(
            label: AppStrings.unpair,
            icon: Icons.link_off,
            backgroundColor: AppColors.danger,
            onPressed: () async {
              await ref.read(monitoringProvider.notifier).stop();
              await ref.read(pairingProvider.notifier).clear();
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
              }
            },
          ),
        ],
      ),
    );
  }
}
