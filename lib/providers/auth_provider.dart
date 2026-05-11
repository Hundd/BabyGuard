import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/firebase_service.dart';

/// Exposes the current anonymous uid. Auto-signs-in on first read.
final authUidProvider = FutureProvider<String>((ref) async {
  return FirebaseService.instance.ensureSignedIn();
});
