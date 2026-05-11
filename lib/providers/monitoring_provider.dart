import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/background_service.dart';

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
  MonitoringNotifier() : super(const MonitoringState()) {
    FlutterForegroundTask.addTaskDataCallback(_onTaskData);
  }

  void _onTaskData(Object data) {
    if (data is Map) {
      if (data['db'] is num) {
        state = state.copyWith(currentDb: (data['db'] as num).toDouble());
      }
      if (data['error'] is String) {
        state = state.copyWith(lastError: data['error'] as String);
      }
    }
  }

  Future<bool> start({required String pairId}) async {
    final ok = await BackgroundService.instance.start(
      config: MonitoringConfig(pairId: pairId, thresholdDb: state.thresholdDb),
    );
    if (ok) state = state.copyWith(isRunning: true, lastError: null);
    return ok;
  }

  Future<bool> stop() async {
    final ok = await BackgroundService.instance.stop();
    if (ok) state = state.copyWith(isRunning: false, currentDb: 0);
    return ok;
  }

  Future<void> setThreshold(double db) async {
    state = state.copyWith(thresholdDb: db);
    if (state.isRunning) {
      await BackgroundService.instance.updateThreshold(db);
    }
  }

  @override
  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_onTaskData);
    super.dispose();
  }
}

final monitoringProvider =
    StateNotifierProvider<MonitoringNotifier, MonitoringState>(
        (ref) => MonitoringNotifier());
