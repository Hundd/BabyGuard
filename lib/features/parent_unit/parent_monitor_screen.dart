import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../providers/pairing_provider.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/status_pill.dart';

class ParentMonitorScreen extends ConsumerWidget {
  const ParentMonitorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pairing = ref.watch(pairingProvider);
    final pairDoc = ref.watch(pairDocProvider);
    final isPaired = pairDoc.value?.data()?['status'] == 'paired';

    return AppScaffold(
      title: AppStrings.parentUnit,
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => Navigator.of(context).pushNamed('/settings'),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Center(
            child: isPaired
                ? StatusPill.success(AppStrings.connected)
                : StatusPill.warning(AppStrings.notConnected),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    isPaired ? Icons.shield_moon_outlined : Icons.link_off,
                    size: 96,
                    color: isPaired ? AppColors.primary : AppColors.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isPaired ? AppStrings.waitingForAlerts : 'Pair with a baby unit to begin.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  if (pairing.pairId != null)
                    Text(
                      'Pair code: ${pairing.pairId}',
                      style: const TextStyle(
                          color: AppColors.textSecondary, letterSpacing: 2),
                    ),
                  const SizedBox(height: 20),
                  const Text(
                    'Keep this app installed and notifications enabled — '
                    'alerts will wake your phone with a loud sound and full-screen prompt.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
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
