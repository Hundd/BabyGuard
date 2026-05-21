import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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

  // ── Critical path: anything an early frame or background-isolate spawn
  //    depends on must complete before runApp.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // FCM background handler registration is a synchronous map insert — keep it
  // here so a push that arrives while the app is being launched is handled
  // correctly. Must happen before runApp.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // initialRoute is computed once from this; if we defer it, the user always
  // lands on onboarding because the provider would still be empty.
  final initialPairing = await loadPersistedPairingState();

  runApp(ProviderScope(
    overrides: [
      pairingProvider.overrideWith((ref) => PairingNotifier(initialPairing)),
    ],
    child: BabyGuardApp(),
  ));

  // ── Everything below was previously awaited before runApp, blocking the
  //    splash for ~300-600 ms. None of it is required for the first frame:
  //      * NotificationService: only matters when an alert renders, and the
  //        first alert can't arrive before pairing (many seconds later).
  //      * BackgroundService:   only needed when Baby taps Start Monitoring;
  //        that action itself awaits when needed.
  //      * FcmService.listenForeground / setListeners: handle inbound pushes;
  //        missing the first ~200 ms is acceptable.
  SchedulerBinding.instance.addPostFrameCallback((_) async {
    await NotificationService.instance.init();
    await BackgroundService.instance.init();
    FcmService.instance.listenForeground();
    AwesomeNotifications().setListeners(
      onActionReceivedMethod: _onNotificationAction,
    );
  });
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
