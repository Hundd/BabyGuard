import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../providers/pairing_provider.dart';
import '../../services/pairing_service.dart';
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
    final data = pairDoc.value?.data();
    final babyState = _deriveBabyState(data);
    final muted = data?['parentMuted'] == true;
    final pairId = pairing.pairId;

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
            child: muted
                ? StatusPill.warning('Alerts paused')
                : _statusPillFor(babyState),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _StatusIcon(state: muted ? _BabyState.notConnected : babyState),
                  const SizedBox(height: 16),
                  Text(
                    muted ? 'Alerts are paused on this device.' : _headlineFor(babyState),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  if (pairId != null)
                    Text(
                      'Pair code: $pairId',
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
          const SizedBox(height: 16),
          if (pairId != null) _PauseCard(pairId: pairId, muted: muted),
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

/// Toggle card that mutes / unmutes alerts on this Parent device.
/// Off by default — the Parent is listening for alerts as soon as it pairs.
class _PauseCard extends ConsumerStatefulWidget {
  final String pairId;
  final bool muted;

  const _PauseCard({required this.pairId, required this.muted});

  @override
  ConsumerState<_PauseCard> createState() => _PauseCardState();
}

class _PauseCardState extends ConsumerState<_PauseCard> {
  bool _busy = false;

  Future<void> _toggle() async {
    if (_busy) return;
    setState(() => _busy = true);
    final next = !widget.muted;
    try {
      await PairingService.instance.setParentMuted(
        pairId: widget.pairId,
        muted: next,
      );
    } catch (e) {
      debugPrint('babyguard.parent: setParentMuted failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update pause state: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(
              widget.muted ? Icons.notifications_off_outlined : Icons.notifications_active_outlined,
              color: widget.muted ? AppColors.warning : AppColors.primary,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pause listening',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.muted
                        ? 'Alerts from the Baby unit are silenced.'
                        : 'Receive loud alerts when the Baby unit detects sound.',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: widget.muted,
              onChanged: _busy ? null : (_) => _toggle(),
            ),
          ],
        ),
      ),
    );
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
