import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/router/app_router.dart';
import 'firebase_options.dart';
import 'providers/pairing_provider.dart';
import 'services/background_service.dart';
import 'services/fcm_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // FCM background handler must be registered before runApp.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await NotificationService.instance.init();
  await BackgroundService.instance.init();

  // Foreground FCM listener (renders the alert when app is open).
  FcmService.instance.listenForeground();

  // Tapping the alert notification (any state) jumps to the full-screen AlertScreen.
  AwesomeNotifications().setListeners(
    onActionReceivedMethod: _onNotificationAction,
  );

  // Pre-load the pairing state so MaterialApp.initialRoute (which is consumed
  // once on first build) sees the correct role + pairId — otherwise the user
  // always lands on the onboarding screen even after pairing.
  final initialPairing = await loadPersistedPairingState();

  runApp(ProviderScope(
    overrides: [
      pairingProvider.overrideWith((ref) => PairingNotifier(initialPairing)),
    ],
    child: BabyGuardApp(),
  ));
}

@pragma('vm:entry-point')
Future<void> _onNotificationAction(ReceivedAction action) async {
  if (action.buttonKeyPressed == 'STOP_ALERT') {
    await NotificationService.instance.cancelAlert();
    return;
  }
  if (action.payload?['type'] == 'alert') {
    final nav = BabyGuardApp.navigatorKey.currentState;
    nav?.pushNamed(AppRouter.alert);
  }
}
