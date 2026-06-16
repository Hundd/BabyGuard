import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  final double thresholdDb;

  /// How many times the alert chime should play on the Parent each time
  /// the Baby unit crosses the threshold. Implemented by writing N alert
  /// events to Firestore with a short stagger.
  final int alertRepeatCount;

  /// How long dB must stay above [thresholdDb] continuously before an
  /// alert fires. Suppresses single spikes (door slams, coughs).
  final int triggerDurationMs;

  const AppSettings({
    this.thresholdDb = 75,
    this.alertRepeatCount = 1,
    this.triggerDurationMs = 800,
  });

  AppSettings copyWith({
    double? thresholdDb,
    int? alertRepeatCount,
    int? triggerDurationMs,
  }) =>
      AppSettings(
        thresholdDb: thresholdDb ?? this.thresholdDb,
        alertRepeatCount: alertRepeatCount ?? this.alertRepeatCount,
        triggerDurationMs: triggerDurationMs ?? this.triggerDurationMs,
      );
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings()) {
    _load();
  }

  static const _kThreshold = 'threshold_db';
  static const _kAlertRepeat = 'alert_repeat_count';
  static const _kTriggerDuration = 'trigger_duration_ms';
  static const int alertRepeatMin = 1;
  static const int alertRepeatMax = 5;
  static const int triggerDurationMinMs = 200;
  static const int triggerDurationMaxMs = 3000;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final t = prefs.getDouble(_kThreshold);
    final r = prefs.getInt(_kAlertRepeat);
    final d = prefs.getInt(_kTriggerDuration);
    state = state.copyWith(
      thresholdDb: t,
      alertRepeatCount: r?.clamp(alertRepeatMin, alertRepeatMax),
      triggerDurationMs: d?.clamp(triggerDurationMinMs, triggerDurationMaxMs),
    );
  }

  Future<void> setThreshold(double db) async {
    state = state.copyWith(thresholdDb: db);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kThreshold, db);
  }

  Future<void> setAlertRepeatCount(int count) async {
    final clamped = count.clamp(alertRepeatMin, alertRepeatMax);
    state = state.copyWith(alertRepeatCount: clamped);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kAlertRepeat, clamped);
  }

  Future<void> setTriggerDurationMs(int ms) async {
    final clamped = ms.clamp(triggerDurationMinMs, triggerDurationMaxMs);
    state = state.copyWith(triggerDurationMs: clamped);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kTriggerDuration, clamped);
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) => SettingsNotifier());
