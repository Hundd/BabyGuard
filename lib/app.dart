import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_strings.dart';
import 'core/constants/app_theme.dart';
import 'core/router/app_router.dart';
import 'providers/pairing_provider.dart';

/// Root of the app. Wraps MaterialApp with a navigator key and the
/// FlutterForegroundTask `withForegroundTask` helper, which keeps the
/// service alive across UI rebuilds.
class BabyGuardApp extends ConsumerWidget {
  BabyGuardApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pairing = ref.watch(pairingProvider);

    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      navigatorKey: navigatorKey,
      initialRoute: AppRouter.initialRouteFor(pairing),
      routes: AppRouter.routes(),
      builder: (context, child) => WithForegroundTask(child: child ?? const SizedBox.shrink()),
    );
  }
}
