class AppStrings {
  AppStrings._();

  static const String appName = 'BabyGuard';
  static const String tagline = 'Peace of mind, one room away.';

  // Modes
  static const String chooseMode = 'Choose this device\'s role';
  static const String babyUnit = 'Baby Unit';
  static const String babyUnitSubtitle = 'Place near the baby. Listens for sound.';
  static const String parentUnit = 'Parent Unit';
  static const String parentUnitSubtitle = 'Keep with you. Receives alerts.';

  // Pairing
  static const String pairingTitle = 'Pair your devices';
  static const String pairingCodeHint = 'Enter 6-character code';
  static const String scanQr = 'Scan QR';
  static const String enterCode = 'Enter code';
  static const String waitingForParent = 'Waiting for Parent Unit to connect...';

  // Monitoring
  static const String startMonitoring = 'Start Monitoring';
  static const String stopMonitoring = 'Stop Monitoring';
  static const String monitoring = 'Monitoring';
  static const String idle = 'Idle';
  static const String threshold = 'Sensitivity Threshold';

  // Parent
  static const String waitingForAlerts = 'Listening for alerts';
  static const String connected = 'Connected';
  static const String notConnected = 'Not connected';
  static const String stopAlert = 'STOP ALERT';
  static const String alertTitle = 'Baby needs you!';
  static const String alertBody = 'Loud sound detected in the nursery';

  // Settings
  static const String settings = 'Settings';
  static const String testAlert = 'Send Test Alert';
  static const String unpair = 'Unpair this device';

  // Permissions
  static const String micPermissionRationale =
      'BabyGuard needs microphone access to listen for sounds and alert you.';
  static const String notificationPermissionRationale =
      'Notifications are required so the Parent Unit can wake you with alerts.';
  static const String batteryOptRationale =
      'For reliable background monitoring, please disable battery optimization for BabyGuard.';
}
