import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../providers/pairing_provider.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/status_pill.dart';

/// Sessions older than this are treated as stale (Baby was force-killed
/// without calling stop). UI falls back to "idle" in that case.
const Duration _kBabyMonitoringStaleAfter = Duration(hours: 24);

enum _BabyState { notConnected, idle, listening }

class ParentMonitorScreen extends ConsumerWidget {
  const ParentMonitorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pairing = ref.watch(pairingProvider);
    final pairDoc = ref.watch(pairDocProvider);
    final babyState = _deriveBabyState(pairDoc.value?.data());

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
          Center(child: _statusPillFor(babyState)),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _StatusIcon(state: babyState),
                  const SizedBox(height: 16),
                  Text(
                    _headlineFor(babyState),
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

  _BabyState _deriveBabyState(Map<String, dynamic>? data) {
    if (data == null || data['status'] != 'paired') return _BabyState.notConnected;
    final monitoring = data['babyMonitoring'] == true;
    if (!monitoring) return _BabyState.idle;

    // Staleness guard: if Baby was force-killed mid-session, the flag stays
    // true forever. Treat very old sessions as idle.
    final startedAt = data['babyMonitoringStartedAt'];
    if (startedAt is Timestamp) {
      final age = DateTime.now().difference(startedAt.toDate());
      if (age > _kBabyMonitoringStaleAfter) return _BabyState.idle;
    }
    return _BabyState.listening;
  }

  Widget _statusPillFor(_BabyState state) {
    switch (state) {
      case _BabyState.listening:
        return StatusPill.success('Baby is listening');
      case _BabyState.idle:
        return StatusPill.warning('Baby is paired but idle');
      case _BabyState.notConnected:
        return StatusPill.warning(AppStrings.notConnected);
    }
  }

  String _headlineFor(_BabyState state) {
    switch (state) {
      case _BabyState.listening:
        return AppStrings.waitingForAlerts;
      case _BabyState.idle:
        return 'Connected. Ask the Baby unit to start monitoring.';
      case _BabyState.notConnected:
        return 'Pair with a baby unit to begin.';
    }
  }
}

/// Hero icon that gently pulses while the Baby is actively listening.
class _StatusIcon extends StatefulWidget {
  final _BabyState state;
  const _StatusIcon({required this.state});

  @override
  State<_StatusIcon> createState() => _StatusIconState();
}

class _StatusIconState extends State<_StatusIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(_StatusIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) _syncAnimation();
  }

  void _syncAnimation() {
    if (widget.state == _BabyState.listening) {
      _ctrl.repeat(reverse: true);
    } else {
      _ctrl.stop();
      _ctrl.value = 0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  IconData _iconFor(_BabyState state) {
    switch (state) {
      case _BabyState.listening:
        return Icons.hearing;
      case _BabyState.idle:
        return Icons.shield_moon_outlined;
      case _BabyState.notConnected:
        return Icons.link_off;
    }
  }

  Color _colorFor(_BabyState state) {
    switch (state) {
      case _BabyState.listening:
        return AppColors.success;
      case _BabyState.idle:
        return AppColors.primary;
      case _BabyState.notConnected:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      _iconFor(widget.state),
      size: 96,
      color: _colorFor(widget.state),
    );
    if (widget.state != _BabyState.listening) return icon;
    return ScaleTransition(
      scale: Tween<double>(begin: 1.0, end: 1.12).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
      ),
      child: icon,
    );
  }
}
