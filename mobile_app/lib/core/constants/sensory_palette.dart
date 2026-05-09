import 'package:flutter/material.dart';

/// Standardized Sensory Palette for EMOLOR emotional measurement.
///
/// Each entry maps a color to a zone value (-2 to +3) used to calculate
/// regulation delta between pre and post session emotion checks.
///
/// Zone scale:
///   +3 = Critical Overload (fight/flight)
///   +2 = Elevated / Caution
///    0 = Balanced Baseline (target state)
///   -1 = Low Energy
///   -2 = Withdrawal / Shutdown

class SensoryColor {
  final String id;
  final String label;
  final Color color;
  final String hex;
  final int zoneValue;
  final String zoneLabel;

  const SensoryColor({
    required this.id,
    required this.label,
    required this.color,
    required this.hex,
    required this.zoneValue,
    required this.zoneLabel,
  });
}

class SensoryPalette {
  SensoryPalette._();

  static const List<SensoryColor> colors = [
    // Zone +3 — Critical Overload
    SensoryColor(
      id: 'terracotta',
      label: 'Red',
      color: Color(0xFFE57373),
      hex: '#E57373',
      zoneValue: 3,
      zoneLabel: 'Critical Overload',
    ),
    SensoryColor(
      id: 'burnt_orange',
      label: 'Orange',
      color: Color(0xFFFF8A65),
      hex: '#FF8A65',
      zoneValue: 3,
      zoneLabel: 'Critical Overload',
    ),

    // Zone +2 — Elevated / Caution
    SensoryColor(
      id: 'mustard',
      label: 'Yellow',
      color: Color(0xFFFFD54F),
      hex: '#FFD54F',
      zoneValue: 2,
      zoneLabel: 'Elevated',
    ),
    SensoryColor(
      id: 'pink',
      label: 'Pink',
      color: Color(0xFFF06292),
      hex: '#F06292',
      zoneValue: 2,
      zoneLabel: 'Elevated',
    ),

    // Zone 0 — Balanced Baseline
    SensoryColor(
      id: 'green',
      label: 'Green',
      color: Color(0xFF81C784),
      hex: '#81C784',
      zoneValue: 0,
      zoneLabel: 'Balanced',
    ),

    SensoryColor(
      id: 'brown',
      label: 'Brown',
      color: Color(0xFFA1887F),
      hex: '#A1887F',
      zoneValue: 0,
      zoneLabel: 'Balanced',
    ),

    // Zone -1 — Low Energy
    SensoryColor(
      id: 'sky_blue',
      label: 'Blue',
      color: Color(0xFF64B5F6),
      hex: '#64B5F6',
      zoneValue: -1,
      zoneLabel: 'Low Energy',
    ),

    // Zone -2 — Withdrawal / Shutdown
    SensoryColor(
      id: 'soft_purple',
      label: 'Purple',
      color: Color(0xFF9575CD),
      hex: '#9575CD',
      zoneValue: -2,
      zoneLabel: 'Withdrawal',
    ),
    SensoryColor(
      id: 'stone_grey',
      label: 'Grey',
      color: Color(0xFF90A4AE),
      hex: '#90A4AE',
      zoneValue: -2,
      zoneLabel: 'Withdrawal',
    ),
  ];

  /// Look up a [SensoryColor] by its hex string. Returns null if not found.
  static SensoryColor? fromHex(String hex) {
    final normalized = hex.trim().toUpperCase();
    try {
      return colors.firstWhere(
        (c) => c.hex.toUpperCase() == normalized,
      );
    } catch (_) {
      return null;
    }
  }

  /// Look up zone value directly from hex. Returns null if hex not in palette.
  static int? zoneFromHex(String hex) => fromHex(hex)?.zoneValue;

  /// Determine if an emotion word zone and a color zone are mismatched.
  ///
  /// Mismatch = emotion zone and color zone are more than 1 apart.
  /// E.g. "Happy" (zone 0) + Terracotta (zone +3) = mismatch.
  /// E.g. "Happy" (zone 0) + Mustard (zone +2) = borderline, not flagged.
  static bool isSensoryMismatch({
    required int emotionZone,
    required int colorZone,
  }) {
    return (emotionZone - colorZone).abs() >= 2;
  }

  /// Compute regulation delta: positive = calming, negative = escalating.
  /// Returns null if either value is missing.
  static int? regulationDelta({
    required int? preZone,
    required int? postZone,
  }) {
    if (preZone == null || postZone == null) return null;
    return preZone - postZone;
  }

  /// Human-readable interpretation of a regulation delta.
  static String interpretDelta(int delta) {
    if (delta >= 2) return 'Effective Regulation';
    if (delta == 1) return 'Mild Improvement';
    if (delta == 0) return 'State Maintained';
    if (delta == -1) return 'Mild Escalation';
    return 'Escalation Warning';
  }
}
