import 'dart:collection';

/// Data class representing a game session with all tracked heuristics
class GameSession {
  final int latencyMs;
  final int errorCount;
  final double tapFrequency;
  final String?
      behaviorFlag; // "Hesitation", "Frustration", "Overload", or null
  final int score;
  final int durationSeconds;

  const GameSession({
    required this.latencyMs,
    required this.errorCount,
    required this.tapFrequency,
    this.behaviorFlag,
    this.score = 0,
    this.durationSeconds = 0,
  });

  Map<String, dynamic> toJson() => {
        'latency_ms': latencyMs,
        'error_count': errorCount,
        'tap_frequency': tapFrequency,
        'behavior_flag': behaviorFlag,
        'score': score,
        'duration_seconds': durationSeconds,
      };
}

/// Enhanced Adaptive Engine with 3 behavioral heuristics:
/// 1. Latency (t_lat) - Time between prompt and tap (>10s = "Hesitation")
/// 2. Error Rate (E_rate) - Wrong attempts (>3 = "Frustration")
/// 3. Tap Frequency (f_tap) - Rapid tapping (>5/sec = "Overload")
class AdaptiveEngine {
  // === Configuration ===
  final int hesitationThresholdMs;
  final int frustrationThreshold;
  final double overloadTapsPerSecond;

  // === Internal State ===
  int _consecutiveErrors = 0;
  int _totalErrors = 0;
  DateTime? _promptShownTime;
  int _lastMeasuredLatencyMs = 0;

  // Sliding window of recent tap timestamps for frequency calculation
  final Queue<DateTime> _tapTimestamps = Queue<DateTime>();
  static const int _tapWindowDurationMs = 1000; // 1 second window

  // Flags
  bool _isSimplified = false;

  AdaptiveEngine({
    this.hesitationThresholdMs = 10000, // 10 seconds
    this.frustrationThreshold = 3,
    this.overloadTapsPerSecond = 5.0,
  });

  // === Latency Tracking ===

  /// Call when a prompt/question is shown to the child
  void markPromptShown() {
    _promptShownTime = DateTime.now();
  }

  /// Call when the child taps/responds. Returns latency in ms.
  int recordTapLatency() {
    if (_promptShownTime == null) return 0;
    final latency = DateTime.now().difference(_promptShownTime!).inMilliseconds;
    _lastMeasuredLatencyMs = latency;
    _promptShownTime = null; // Reset for next prompt
    return latency;
  }

  /// Check if child is hesitating (>10s to respond)
  bool get isHesitating => _lastMeasuredLatencyMs > hesitationThresholdMs;

  // === Error Rate Tracking ===

  /// Increment error count (on wrong answer)
  void trackError() {
    _consecutiveErrors++;
    _totalErrors++;
  }

  /// Reset consecutive errors (on success)
  void resetErrors() {
    _consecutiveErrors = 0;
  }

  /// Check if child is frustrated (>3 consecutive errors)
  bool get isFrustrated => _consecutiveErrors >= frustrationThreshold;

  int get errorCount => _totalErrors;
  int get consecutiveErrors => _consecutiveErrors;

  // === Tap Frequency Detection ===

  /// Record a tap event for frequency analysis
  void recordTap() {
    final now = DateTime.now();
    _tapTimestamps.add(now);

    // Remove taps older than the window
    final cutoff =
        now.subtract(const Duration(milliseconds: _tapWindowDurationMs));
    while (_tapTimestamps.isNotEmpty && _tapTimestamps.first.isBefore(cutoff)) {
      _tapTimestamps.removeFirst();
    }
  }

  /// Get current tap frequency (taps per second)
  double get tapFrequency {
    if (_tapTimestamps.length < 2) return 0;
    return _tapTimestamps.length.toDouble(); // taps in last 1 second = taps/sec
  }

  /// Check if child is showing overload behavior (rapid tapping >5/sec)
  bool get isOverloaded => tapFrequency > overloadTapsPerSecond;

  // === Adaptive Response ===

  /// Check if any simplification trigger is active
  bool get shouldSimplify => isFrustrated || isOverloaded;

  /// Get the primary detected behavior flag
  String? get behaviorFlag {
    if (isOverloaded) return 'Overload';
    if (isFrustrated) return 'Frustration';
    if (isHesitating) return 'Hesitation';
    return null;
  }

  /// Mark UI as simplified (to prevent repeated simplifications)
  void markSimplified() {
    _isSimplified = true;
  }

  bool get isAlreadySimplified => _isSimplified;

  /// Call this to simplify the UI - returns true if action should be taken
  bool simplifyUI() {
    if (_isSimplified) return false; // Already simplified
    if (!shouldSimplify) return false; // No trigger

    _isSimplified = true;
    _consecutiveErrors = 0; // Reset after helping
    return true;
  }

  // === Session Management ===

  /// Get a snapshot of the current session data
  GameSession getSessionSnapshot({int score = 0, int durationSeconds = 0}) {
    return GameSession(
      latencyMs: _lastMeasuredLatencyMs,
      errorCount: _totalErrors,
      tapFrequency: tapFrequency,
      behaviorFlag: behaviorFlag,
      score: score,
      durationSeconds: durationSeconds,
    );
  }

  /// Reset all state for a new game
  void reset() {
    _consecutiveErrors = 0;
    _totalErrors = 0;
    _promptShownTime = null;
    _lastMeasuredLatencyMs = 0;
    _tapTimestamps.clear();
    _isSimplified = false;
  }
}
