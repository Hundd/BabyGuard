import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/permissions.dart';
import '../../providers/monitoring_provider.dart';
import '../../providers/pairing_provider.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/big_button.dart';
import '../../widgets/status_pill.dart';
import 'widgets/db_meter_gauge.dart';
import 'widgets/threshold_slider.dart';

class BabyMonitorScreen extends ConsumerWidget {
  const BabyMonitorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monitoring = ref.watch(monitoringProvider);
    final pairing = ref.watch(pairingProvider);
    final pairId = pairing.pairId;

    return AppScaffold(
      title: AppStrings.babyUnit,
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => Navigator.of(context).pushNamed('/settings'),
        ),
      ],
      body: pairId == null
          ? const Center(child: Text('Not paired yet.'))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: monitoring.isRunning
                      ? StatusPill.success(AppStrings.monitoring)
                      : StatusPill.idle(AppStrings.idle),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text('Pair code: $pairId',
                      style: const TextStyle(
                          color: AppColors.textSecondary, letterSpacing: 2)),
                ),
                const SizedBox(height: 24),
                DbMeterGauge(
                  currentDb: monitoring.currentDb,
                  thresholdDb: monitoring.thresholdDb,
                ),
                const SizedBox(height: 16),
                ThresholdSlider(
                  value: monitoring.thresholdDb,
                  onChanged: (v) =>
                      ref.read(monitoringProvider.notifier).setThreshold(v),
                ),
                if (monitoring.lastError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Last error: ${monitoring.lastError}',
                    style: const TextStyle(color: AppColors.danger, fontSize: 12),
                  ),
                ],
                const Spacer(),
                BigButton(
                  label: monitoring.isRunning
                      ? AppStrings.stopMonitoring
                      : AppStrings.startMonitoring,
                  icon: monitoring.isRunning ? Icons.stop : Icons.play_arrow,
                  backgroundColor: monitoring.isRunning ? AppColors.danger : AppColors.primary,
                  onPressed: () => _toggle(context, ref, pairId),
                ),
                const SizedBox(height: 16),
              ],
            ),
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref, String pairId) async {
    debugPrint('babyguard.ui: toggle pressed');
    final notifier = ref.read(monitoringProvider.notifier);
    final state = ref.read(monitoringProvider);

    if (state.isRunning) {
      debugPrint('babyguard.ui: stopping');
      await notifier.stop();
      return;
    }

    debugPrint('babyguard.ui: requesting permissions');
    final ok = await PermissionHelper.requestBabyUnitPermissions();
    debugPrint('babyguard.ui: permissions granted=$ok');
    if (!ok) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.micPermissionRationale)),
        );
      }
      return;
    }
    await PermissionHelper.requestIgnoreBatteryOptimizations();
    final started = await notifier.start(pairId: pairId);
    if (!started && context.mounted) {
      final reason = ref.read(monitoringProvider).lastError ?? 'unknown';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start monitoring: $reason')),
      );
    }
  }
}
