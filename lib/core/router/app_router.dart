import 'package:flutter/material.dart';

import '../../features/baby_unit/baby_monitor_screen.dart';
import '../../features/onboarding/mode_selection_screen.dart';
import '../../features/pairing/baby_pairing_screen.dart';
import '../../features/pairing/parent_pairing_screen.dart';
import '../../features/parent_unit/alert_screen.dart';
import '../../features/parent_unit/parent_monitor_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../providers/pairing_provider.dart';

class AppRouter {
  AppRouter._();

  static const String onboarding = '/';
  static const String babyPair = '/baby/pair';
  static const String babyMonitor = '/baby/monitor';
  static const String parentPair = '/parent/pair';
  static const String parentMonitor = '/parent/monitor';
  static const String alert = '/alert';
  static const String settings = '/settings';

  static Map<String, WidgetBuilder> routes() => {
        onboarding: (_) => const ModeSelectionScreen(),
        babyPair: (_) => const BabyPairingScreen(),
        babyMonitor: (_) => const BabyMonitorScreen(),
        parentPair: (_) => const ParentPairingScreen(),
        parentMonitor: (_) => const ParentMonitorScreen(),
        alert: (_) => const AlertScreen(),
        settings: (_) => const SettingsScreen(),
      };

  /// Picks the initial route from persisted pairing state.
  static String initialRouteFor(PairingState state) {
    if (state.role == DeviceRole.baby && state.pairId != null) return babyMonitor;
    if (state.role == DeviceRole.parent && state.pairId != null) return parentMonitor;
    if (state.role == DeviceRole.baby) return babyPair;
    if (state.role == DeviceRole.parent) return parentPair;
    return onboarding;
  }
}
