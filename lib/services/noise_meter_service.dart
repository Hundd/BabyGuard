import 'dart:async';
import 'dart:math' as math;

import 'package:noise_meter/noise_meter.dart';

/// Wraps `noise_meter` into a friendlier API:
///   * single Stream<double> of dB values
///   * `onThresholdExceeded` callback fires when dB stays above
///     [thresholdDb] for [debounce] continuously (prevents single-spike alerts).
class NoiseMeterService {
  NoiseMeterService();

  final NoiseMeter _meter = NoiseMeter();
  StreamSubscription<NoiseReading>? _sub;

  final StreamController<double> _dbController = StreamController<double>.broadcast();
  Stream<double> get dbStream => _dbController.stream;

  double _threshold = 75;
  Duration _debounce = const Duration(milliseconds: 800);
  DateTime? _overSince;
  DateTime? _lastFired;
  void Function(double db)? _onThreshold;

  bool get isRunning => _sub != null;

  Future<void> start({
    required double thresholdDb,
    Duration debounce = const Duration(milliseconds: 800),
    void Function(double db)? onThresholdExceeded,
  }) async {
    if (_sub != null) return;
    _threshold = thresholdDb;
    _debounce = debounce;
    _onThreshold = onThresholdExceeded;

    _sub = _meter.noise.listen(_onReading, onError: (_) {
      // Surface errors to the stream as a sentinel value; UI may show a message.
      _dbController.addError(_);
    });
  }

  void updateThreshold(double db) {
    _threshold = db;
  }

  void updateDebounce(Duration d) {
    _debounce = d;
  }

  void _onReading(NoiseReading reading) {
    // noise_meter reports `meanDecibel` and `maxDecibel`. We use mean for stability.
    final db = reading.meanDecibel.isFinite ? reading.meanDecibel : 0;
    if (db.isNaN) return;
    final dbValue = db.toDouble();
    _dbController.add(dbValue);

    if (dbValue >= _threshold) {
      _overSince ??= DateTime.now();
      final overFor = DateTime.now().difference(_overSince!);
      final cooldownOk = _lastFired == null ||
          DateTime.now().difference(_lastFired!) > const Duration(seconds: 10);
      if (overFor >= _debounce && cooldownOk) {
        _lastFired = DateTime.now();
        _onThreshold?.call(dbValue);
        _overSince = null;
      }
    } else {
      _overSince = null;
    }
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _overSince = null;
  }

  Future<void> dispose() async {
    await stop();
    await _dbController.close();
  }

  /// Helper to clamp dB to a 0-100 progress fraction for UI gauges.
  static double normalize(double db) {
    if (!db.isFinite) return 0;
    return math.min(1, math.max(0, (db - 30) / 70));
  }
}
