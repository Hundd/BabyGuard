import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// In-memory list of alert timestamps for the current Parent session.
/// Cleared whenever the app process restarts — not persisted.
class AlertHistoryNotifier extends StateNotifier<List<DateTime>> {
  AlertHistoryNotifier() : super(const []);

  static const int _maxEntries = 100;

  void add() {
    state = [DateTime.now(), ...state].take(_maxEntries).toList();
  }
}

final alertHistoryProvider =
    StateNotifierProvider<AlertHistoryNotifier, List<DateTime>>(
        (ref) => AlertHistoryNotifier());

/// Foreground-only stream of alert FCM messages. Mirrors the type filter in
/// [FcmService.listenForeground]; subscribing here is additive — FCM supports
/// multiple `onMessage` listeners.
final foregroundAlertStreamProvider = StreamProvider<RemoteMessage>(
  (ref) =>
      FirebaseMessaging.onMessage.where((m) => m.data['type'] == 'alert'),
);
