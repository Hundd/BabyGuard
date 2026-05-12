import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/background_service.dart';
import '../services/noise_meter_service.dart';
import '../services/pairing_service.dart';

class MonitoringState {
  final bool isRunning;
  final double currentDb;
  final double thresholdDb;
  final String? lastError;

  const MonitoringState({
    this.isRunning = false,
    this.currentDb = 0,
    this.thresholdDb = 75,
    this.lastError,
  });

  MonitoringState copyWith({
    bool? isRunning,
    double? currentDb,
    double? thresholdDb,
    String? lastError,
  }) =>
      MonitoringState(
        isRunning: isRunning ?? this.isRunning,
        currentDb: currentDb ?? this.currentDb,
        thresholdDb: thresholdDb ?? this.thresholdDb,
        lastError: lastError,
      );
}

class MonitoringNotifier extends StateNotifier<MonitoringState> {
  MonitoringNotifier() : super(const MonitoringState());

  final NoiseMeterService _meter = NoiseMeterService();
  StreamSubscription<double>? _dbSub;
  StreamSubscription<Object>? _errSub;
  String? _activePairId;

  Future<bool> start({required String pairId}) async {
    debugPrint('babyguard.mon: start() called, pairId=$pairId, threshold=${state.thresholdDb}');
    if (state.isRunning) return true;
    _activePairId = pairId;

    final fgOk = await BackgroundService.instance.start();
    debugPrint('babyguard.mon: foreground service start ok=$fgOk');
    if (!fgOk) {
      debugPrint("babyguard.mon: " + 'foreground service failed to start');
      state = state.copyWith(lastError: 'service_start_failed');
      return false;
    }

    try {
      await _meter.start(
        thresholdDb: state.thresholdDb,
        onThresholdExceeded: _onThresholdExceeded,
      );
    } catch (e, st) {
      debugPrint('babyguard.mon: noise_meter start error: $e\n$st');
      state = state.copyWith(lastError: 'mic_start_failed: $e');
      await BackgroundService.instance.stop();
      return false;
    }

    _dbSub = _meter.dbStream.listen((db) {
      state = state.copyWith(currentDb: db);
    }, onError: (e) {
      debugPrint('babyguard.mon: noise_meter stream error: $e');
      state = state.copyWith(lastError: 'mic_stream_error: $e');
    });

    debugPrint("babyguard.mon: " + 'monitoring started, pairId=$pairId');
    state = state.copyWith(isRunning: true, lastError: null);

    // Tell the Parent we're listening. Fire-and-forget — failure shouldn't
    // block the Baby unit from actually monitoring.
    unawaited(PairingService.instance
        .setBabyMonitoring(pairId: pairId, on: true)
        .catchError((e) {
      debugPrint('babyguard.mon: setBabyMonitoring(true) failed: $e');
    }));

    return true;
  }

  Future<void> _onThresholdExceeded(double db) async {
    final pairId = _activePairId;
    if (pairId == null) return;
    debugPrint("babyguard.mon: " + 'threshold exceeded: $db dB');
    try {
      await PairingService.instance.emitAlertEvent(pairId: pairId, db: db);
    } catch (e) {
      debugPrint('babyguard.mon: emit alert failed: $e');
      state = state.copyWith(lastError: 'alert_write_failed');
    }
  }

  Future<bool> stop() async {
    final pairId = _activePairId;
    // Clear the Parent-facing "listening" flag first so the Parent UI flips
    // even if the local mic stop takes a beat.
    if (pairId != null) {
      unawaited(PairingService.instance
          .setBabyMonitoring(pairId: pairId, on: false)
          .catchError((e) {
        debugPrint('babyguard.mon: setBabyMonitoring(false) failed: $e');
      }));
    }
    await _dbSub?.cancel();
    await _errSub?.cancel();
    await _meter.stop();
    final ok = await BackgroundService.instance.stop();
    debugPrint("babyguard.mon: " + 'monitoring stopped');
    state = state.copyWith(isRunning: false, currentDb: 0);
    return ok;
  }

  Future<void> setThreshold(double db) async {
    state = state.copyWith(thresholdDb: db);
    if (state.isRunning) {
      _meter.updateThreshold(db);
    }
  }

  @override
  void dispose() {
    _dbSub?.cancel();
    _errSub?.cancel();
    _meter.dispose();
    super.dispose();
  }
}

final monitoringProvider =
    StateNotifierProvider<MonitoringNotifier, MonitoringState>(
        (ref) => MonitoringNotifier());
