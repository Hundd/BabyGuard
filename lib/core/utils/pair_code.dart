import 'dart:math';

/// Generates short, human-friendly pairing codes.
/// Excludes ambiguous characters (0/O, 1/I/L).
class PairCode {
  PairCode._();

  static const String _alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  static final Random _rng = Random.secure();

  static String generate({int length = 6}) {
    return List.generate(
      length,
      (_) => _alphabet[_rng.nextInt(_alphabet.length)],
    ).join();
  }

  static bool isValid(String code) {
    if (code.length != 6) return false;
    return code.toUpperCase().split('').every(_alphabet.contains);
  }
}
