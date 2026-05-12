import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/utils/pair_code.dart';
import 'firebase_service.dart';

/// Manages the lifecycle of a pairing document in Firestore.
class PairingService {
  PairingService._();
  static final PairingService instance = PairingService._();

  final FirebaseService _fb = FirebaseService.instance;

  /// Baby unit creates a new pair doc with a fresh 6-char code as its ID.
  /// Returns the generated code.
  Future<String> createPair({
    required String babyUid,
    required String babyToken,
  }) async {
    // retry on the (extremely unlikely) collision
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = PairCode.generate();
      final doc = _fb.pair(code);
      final snap = await doc.get();
      if (snap.exists) continue;
      await doc.set({
        'createdAt': FieldValue.serverTimestamp(),
        'babyUid': babyUid,
        'babyToken': babyToken,
        'parentUid': null,
        'parentToken': null,
        'status': 'waiting',
      });
      return code;
    }
    throw StateError('Could not allocate a unique pair code after retries.');
  }

  /// Parent unit joins an existing pair using the code.
  Future<bool> joinPair({
    required String code,
    required String parentUid,
    required String parentToken,
  }) async {
    final doc = _fb.pair(code.toUpperCase());
    final snap = await doc.get();
    if (!snap.exists) return false;
    await doc.update({
      'parentUid': parentUid,
      'parentToken': parentToken,
      'status': 'paired',
    });
    return true;
  }

  /// Live stream of a pair doc (status, tokens).
  Stream<DocumentSnapshot<Map<String, dynamic>>> watch(String pairId) {
    return _fb.pair(pairId).snapshots();
  }

  /// Baby unit logs a sound event - Cloud Function fans this out to FCM.
  Future<void> emitAlertEvent({
    required String pairId,
    required double db,
  }) async {
    await _fb.events(pairId).add({
      'at': FieldValue.serverTimestamp(),
      'db': db,
    });
  }

  /// Update the Parent FCM token on the pair doc (e.g. when it rotates).
  Future<void> updateParentToken({
    required String pairId,
    required String token,
  }) async {
    await _fb.pair(pairId).update({'parentToken': token});
  }

  /// Baby unit signals its monitoring state to the Parent via the pair doc.
  /// On `true` we also write a server-side timestamp so the Parent can use it
  /// as a staleness floor (e.g. ignore "monitoring" older than 24 h).
  Future<void> setBabyMonitoring({
    required String pairId,
    required bool on,
  }) async {
    await _fb.pair(pairId).update({
      'babyMonitoring': on,
      if (on) 'babyMonitoringStartedAt': FieldValue.serverTimestamp(),
    });
  }
}
