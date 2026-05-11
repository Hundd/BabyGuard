import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Thin wrapper around FirebaseAuth + Firestore for app-wide use.
class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  FirebaseAuth get auth => FirebaseAuth.instance;
  FirebaseFirestore get db => FirebaseFirestore.instance;

  /// Ensures the user is signed in anonymously and returns the uid.
  Future<String> ensureSignedIn() async {
    final current = auth.currentUser;
    if (current != null) return current.uid;
    final cred = await auth.signInAnonymously();
    return cred.user!.uid;
  }

  CollectionReference<Map<String, dynamic>> get pairs => db.collection('pairs');

  DocumentReference<Map<String, dynamic>> pair(String pairId) => pairs.doc(pairId);

  CollectionReference<Map<String, dynamic>> events(String pairId) =>
      pair(pairId).collection('events');
}
