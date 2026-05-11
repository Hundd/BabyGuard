import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';

/// Centralized permission helper for both Baby and Parent units.
class PermissionHelper {
  PermissionHelper._();

  /// Request mic + notification permissions in sequence.
  /// Returns true only if all granted.
  static Future<bool> requestBabyUnitPermissions() async {
    final mic = await Permission.microphone.request();
    final notif = await Permission.notification.request();
    return mic.isGranted && notif.isGranted;
  }

  /// Parent only needs notifications (and camera if scanning QR).
  static Future<bool> requestParentUnitPermissions() async {
    final notif = await Permission.notification.request();
    return notif.isGranted;
  }

  static Future<bool> requestCamera() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  /// Ask the OS to ignore battery optimizations so the foreground service
  /// is not killed by Doze. This pops a system dialog on Android.
  static Future<void> requestIgnoreBatteryOptimizations() async {
    final isIgnored = await FlutterForegroundTask.isIgnoringBatteryOptimizations;
    if (!isIgnored) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }
  }
}
