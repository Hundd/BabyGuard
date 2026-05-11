import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../firebase_options.dart';
import 'noise_meter_service.dart';
import 'notification_service.dart';

/// Configuration passed into the foreground task on start.
class MonitoringConfig {
  final String pairId;
  final double thresholdDb;

  MonitoringConfig({required this.pairId, required this.thresholdDb});

  Map<String, dynamic> toMap() => {'pairId': pairId, 'thresholdDb': thresholdDb};

  static MonitoringConfig fromMap(Map<String, dynamic> m) => MonitoringConfig(
        pairId: m['pairId'] as String,
        thresholdDb: (m['thresholdDb'] as num).toDouble(),
      );
}

/// Top-level entry point for the foreground task isolate.
/// Must be a free function (no captured state) for the plugin to register.
@pragma('vm:entry-point')
void startMonitoringCallback() {
  FlutterForegroundTask.setTaskHandler(_NoiseTaskHandler());
}

class _NoiseTaskHandler extends TaskHandler {
  final NoiseMeterService _meter = NoiseMeterService();
  String? _pairId;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // The foreground isolate is brand-new; reinit Firebase here.
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    _pairId = await FlutterForegroundTask.getData<String>(key: 'pairId');
    final threshold =
        await FlutterForegroundTask.getData<double>(key: 'threshold') ?? 75.0;

    await _meter.start(
      thresholdDb: threshold,
      onThresholdExceeded: _onThresholdExceeded,
    );

    _meter.dbStream.listen((db) {
      // Forward to UI via the plugin's send port.
      FlutterForegroundTask.sendDataToMain({'db': db});
    });
  }

  Future<void> _onThresholdExceeded(double db) async {
    final pairId = _pairId;
    if (pairId == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('pairs')
          .doc(pairId)
          .collection('events')
          .add({'at': FieldValue.serverTimestamp(), 'db': db});
    } catch (_) {
      // Network might be down. Surface to UI - if available - so user knows.
      FlutterForegroundTask.sendDataToMain({'error': 'firestore_write_failed'});
    }
  }

  @override
  void onReceiveData(Object data) {
    // UI can push threshold updates without restarting the service.
    if (data is Map && data['threshold'] is num) {
      _meter.updateThreshold((data['threshold'] as num).toDouble());
    }
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    // No-op; we run continuously via the noise stream.
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    await _meter.dispose();
  }
}

/// Public API used by the UI layer.
class BackgroundService {
  BackgroundService._();
  static final BackgroundService instance = BackgroundService._();

  Future<void> init() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: NotificationService.foregroundChannelKey,
        channelName: 'Monitoring service',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        playSound: false,
        showWhen: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  Future<bool> start({required MonitoringConfig config}) async {
    if (await FlutterForegroundTask.isRunningService) return true;

    await FlutterForegroundTask.saveData(key: 'pairId', value: config.pairId);
    await FlutterForegroundTask.saveData(key: 'threshold', value: config.thresholdDb);

    final result = await FlutterForegroundTask.startService(
      notificationTitle: 'BabyGuard is monitoring',
      notificationText: 'Listening for sounds. Tap to open.',
      callback: startMonitoringCallback,
    );
    return result is ServiceRequestSuccess;
  }

  Future<bool> stop() async {
    final result = await FlutterForegroundTask.stopService();
    return result is ServiceRequestSuccess;
  }

  Future<void> updateThreshold(double db) async {
    await FlutterForegroundTask.saveData(key: 'threshold', value: db);
    FlutterForegroundTask.sendDataToTask({'threshold': db});
  }
}
