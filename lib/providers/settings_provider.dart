import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  final double thresholdDb;

  const AppSettings({this.thresholdDb = 75});

  AppSettings copyWith({double? thresholdDb}) =>
      AppSettings(thresholdDb: thresholdDb ?? this.thresholdDb);
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings()) {
    _load();
  }

  static const _kThreshold = 'threshold_db';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final t = prefs.getDouble(_kThreshold);
    if (t != null) state = state.copyWith(thresholdDb: t);
  }

  Future<void> setThreshold(double db) async {
    state = state.copyWith(thresholdDb: db);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kThreshold, db);
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) => SettingsNotifier());
