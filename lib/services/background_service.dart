import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'notification_service.dart';

/// Foreground service plumbing.
///
/// On older OEM Androids (notably Samsung One UI on Android 11) the
/// `noise_meter` / `audio_streamer` MethodChannels don't reliably work inside
/// the `flutter_foreground_task` isolate. So the task handler here intentionally
/// does *nothing* with the mic — it exists only to keep the OS from killing
/// the app while the user has Monitoring on. The actual mic reading lives in
/// [MonitoringNotifier] on the main UI isolate.
@pragma('vm:entry-point')
void startMonitoringCallback() {
  developer.log('foreground task callback', name: 'babyguard.bg');
  FlutterForegroundTask.setTaskHandler(_KeepAliveTaskHandler());
}

class _KeepAliveTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    developer.log('keep-alive task started', name: 'babyguard.bg');
  }

  @override
  void onReceiveData(Object data) {}

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {}

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    developer.log('keep-alive task stopped', name: 'babyguard.bg');
  }
}

class BackgroundService {
  BackgroundService._();
  static final BackgroundService instance = BackgroundService._();

  /// Memoize so callers can `await init()` from anywhere — re-entry is a no-op
  /// and we avoid the race where `start()` is invoked before the post-`runApp`
  /// deferred init in main.dart has finished.
  Future<void>? _initFuture;
  String? lastFailureReason;

  Future<void> init() {
    return _initFuture ??= _runInit();
  }

  Future<void> _runInit() async {
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
    developer.log('foreground task init complete', name: 'babyguard.bg');
  }

  Future<bool> start() async {
    await init();
    if (await FlutterForegroundTask.isRunningService) return true;
    final result = await FlutterForegroundTask.startService(
      notificationTitle: 'BabyGuard is monitoring',
      notificationText: 'Listening for sounds. Tap to open.',
      callback: startMonitoringCallback,
    );
    developer.log('startService result=$result', name: 'babyguard.bg');
    if (result is ServiceRequestSuccess) {
      lastFailureReason = null;
      return true;
    }
    lastFailureReason = result.toString();
    return false;
  }

  Future<bool> stop() async {
    final result = await FlutterForegroundTask.stopService();
    return result is ServiceRequestSuccess;
  }
}
