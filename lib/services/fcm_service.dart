import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../firebase_options.dart';
import 'notification_service.dart';

/// Top-level FCM background handler. Must be a top-level (not class) function
/// per firebase_messaging requirements - registered from main.dart.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.instance.init();

  if (message.data['type'] == 'alert') {
    await NotificationService.instance.showAlert(
      title: message.notification?.title ?? 'Baby needs you!',
      body: message.notification?.body ?? 'Loud sound detected in the nursery',
    );
  }
}

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final FirebaseMessaging _fm = FirebaseMessaging.instance;

  /// Requests permission and returns the current FCM token (null on failure).
  Future<String?> requestAndGetToken() async {
    await _fm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      criticalAlert: true,
    );
    return _fm.getToken();
  }

  /// Listen for token refreshes; pass them to a sink so we can update Firestore.
  Stream<String> get onTokenRefresh => _fm.onTokenRefresh;

  /// Foreground messages still come through here - we render the alert ourselves
  /// since the system does not show a banner for foreground notifications by default.
  void listenForeground() {
    FirebaseMessaging.onMessage.listen((message) async {
      if (message.data['type'] == 'alert') {
        await NotificationService.instance.showAlert(
          title: message.notification?.title ?? 'Baby needs you!',
          body: message.notification?.body ?? 'Loud sound detected in the nursery',
        );
      }
    });
  }
}
