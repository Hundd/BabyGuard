import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/pairing_service.dart';

enum DeviceRole { unknown, baby, parent }

class PairingState {
  final DeviceRole role;
  final String? pairId;
  final bool isPaired;

  const PairingState({
    this.role = DeviceRole.unknown,
    this.pairId,
    this.isPaired = false,
  });

  PairingState copyWith({DeviceRole? role, String? pairId, bool? isPaired}) =>
      PairingState(
        role: role ?? this.role,
        pairId: pairId ?? this.pairId,
        isPaired: isPaired ?? this.isPaired,
      );
}

/// Persistence keys used by both [PairingNotifier] and
/// [loadPersistedPairingState].
const _kRole = 'pairing_role';
const _kPairId = 'pairing_id';

/// Read pairing state from SharedPreferences. Call this from `main()` before
/// `runApp` so the initial route can be computed synchronously on first build.
Future<PairingState> loadPersistedPairingState() async {
  final prefs = await SharedPreferences.getInstance();
  final roleStr = prefs.getString(_kRole);
  final pairId = prefs.getString(_kPairId);
  return PairingState(
    role: DeviceRole.values.firstWhere(
      (r) => r.name == roleStr,
      orElse: () => DeviceRole.unknown,
    ),
    pairId: pairId,
    isPaired: pairId != null,
  );
}

class PairingNotifier extends StateNotifier<PairingState> {
  /// Pass the value returned by [loadPersistedPairingState] so the notifier
  /// starts with the persisted state already loaded — no async hydration race.
  PairingNotifier([PairingState? initial]) : super(initial ?? const PairingState());

  Future<void> setRole(DeviceRole role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRole, role.name);
    state = state.copyWith(role: role);
  }

  Future<void> setPairId(String pairId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPairId, pairId);
    state = state.copyWith(pairId: pairId, isPaired: true);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRole);
    await prefs.remove(_kPairId);
    state = const PairingState();
  }
}

final pairingProvider =
    StateNotifierProvider<PairingNotifier, PairingState>((ref) => PairingNotifier());

/// Live document stream for the active pair.
final pairDocProvider =
    StreamProvider.autoDispose<DocumentSnapshot<Map<String, dynamic>>?>((ref) {
  final pairing = ref.watch(pairingProvider);
  final pairId = pairing.pairId;
  if (pairId == null) return Stream.value(null);
  return PairingService.instance.watch(pairId);
});
