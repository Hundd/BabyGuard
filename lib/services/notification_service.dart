import 'dart:ui';

import 'package:awesome_notifications/awesome_notifications.dart';

/// Centralized notification setup. Two channels:
///   * foreground_channel - low priority, used by the baby unit's foreground service.
///   * alert_channel       - max priority + full-screen + alarm ringtone, parent unit alerts.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  // Bumped from 'alert_channel' to pick up the new custom sound — Android
  // notification channels are immutable once created, so changing
  // soundSource on the existing channel is a no-op on already-installed
  // devices unless we use a new key.
  static const String alertChannelKey = 'alert_channel_v2';
  static const String foregroundChannelKey = 'foreground_channel';
  static const int alertNotificationId = 4242;

  Future<void> init() async {
    await AwesomeNotifications().initialize(
      'resource://mipmap/ic_launcher',
      [
        NotificationChannel(
          channelKey: alertChannelKey,
          channelName: 'Baby Alerts',
          channelDescription: 'Loud alerts when the baby unit detects sound.',
          importance: NotificationImportance.Max,
          defaultColor: const Color(0xFFE76F6F),
          ledColor: const Color(0xFFE76F6F),
          playSound: true,
          soundSource: 'resource://raw/baby_alert',
          enableVibration: true,
          enableLights: true,
          criticalAlerts: true,
          defaultPrivacy: NotificationPrivacy.Public,
        ),
        NotificationChannel(
          channelKey: foregroundChannelKey,
          channelName: 'Monitoring service',
          channelDescription: 'Keeps the microphone running while the app is in the background.',
          importance: NotificationImportance.Low,
          playSound: false,
          enableVibration: false,
        ),
      ],
      debug: false,
    );

    final allowed = await AwesomeNotifications().isNotificationAllowed();
    if (!allowed) {
      await AwesomeNotifications().requestPermissionToSendNotifications(
        permissions: [
          NotificationPermission.Alert,
          NotificationPermission.Sound,
          NotificationPermission.Vibration,
          NotificationPermission.Light,
          NotificationPermission.FullScreenIntent,
          NotificationPermission.CriticalAlert,
        ],
      );
    }
  }

  /// Fires a full-screen alert with system alarm ringtone + vibration.
  /// Used by the FCM background handler on the Parent Unit.
  Future<void> showAlert({
    String title = 'Baby needs you!',
    String body = 'Loud sound detected in the nursery',
  }) async {
    // Each call fires a fresh notification; the channel sound plays exactly
    // once per call (no looping). Repeat behaviour is controlled by writing
    // multiple Firestore events on the Baby side (alert_repeat_count setting).
    //
    // A unique id per call is critical — using a fixed id would coalesce
    // back-to-back alerts into a single notification with no sound replay.
    // NotificationCategory.Alarm is intentionally NOT set: it would make
    // Android loop the sound until dismissed, which removes our slider's
    // effect.
    final id = DateTime.now().millisecondsSinceEpoch.remainder(2147483647);
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: id,
        channelKey: alertChannelKey,
        title: title,
        body: body,
        notificationLayout: NotificationLayout.BigText,
        wakeUpScreen: true,
        fullScreenIntent: true,
        criticalAlert: true,
        autoDismissible: true,
        displayOnForeground: true,
        displayOnBackground: true,
        payload: {'type': 'alert'},
      ),
      actionButtons: [
        NotificationActionButton(
          key: 'STOP_ALERT',
          label: 'STOP ALERT',
          actionType: ActionType.Default,
          autoDismissible: true,
        ),
      ],
    );
  }

  Future<void> cancelAlert() async {
    await AwesomeNotifications().cancel(alertNotificationId);
  }
}
