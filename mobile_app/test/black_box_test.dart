// Black-box test suite (CSE442) — EmoLor
//
// Techniques: Equivalence Partitioning (EP), Boundary Value Analysis (BVA),
// Decision Table Testing.
//
// IMPORTANT — testability note:
// The app's input validation is implemented INLINE inside widget methods
// (e.g. RegisterScreen._register, LoginScreen._login) and goal values come
// from CLAMPED scroll wheels, not from extracted pure validator functions.
// To test without changing app logic, the rules below are faithfully MIRRORED
// from the cited source lines. The goal-enforcement table tests the REAL app
// getter `PerformanceGoal.isComplete`. "Expected" reflects ACTUAL app spec
// (verified against source), per the agreed baseline.

import 'package:flutter_test/flutter_test.dart';
import 'package:emolor_flutter/features/caregiver/services/goal_service.dart';

// ─────────────────────────────────────────────────────────────────────────
// Mirrored validation rules (cited to source)
// ─────────────────────────────────────────────────────────────────────────

/// Mirrors register_screen.dart:56 — the registration email regex.
final RegExp _registerEmailRegex = RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w]{2,}$');
bool isValidRegisterEmail(String email) =>
    _registerEmailRegex.hasMatch(email.trim());

/// Mirrors register_screen.dart:48 (empty) + :64 (length < 8).
/// NOTE: the app enforces NO maximum length (Supabase enforces 72 server-side).
bool isValidRegisterPassword(String pw) {
  if (pw.isEmpty) return false; // register_screen.dart:48
  if (pw.length < 8) return false; // register_screen.dart:64
  return true; // no upper bound in app
}

/// Mirrors set_goals_screen.dart:35-36 / new_goal_dialog.dart:44-45.
/// Star target is chosen from a wheel clamped to [1, 100]; values outside
/// this range cannot be entered through the UI.
const int kStarMin = 1;
const int kStarMax = 100;
bool isSelectableStarTarget(num value) {
  if (value is! int) return false; // non-numeric / non-int cannot be selected
  return value >= kStarMin && value <= kStarMax;
}

/// Mirrors set_goals_screen.dart:75-77, hours wheel itemCount 24 (0-23),
/// minutes wheel itemCount 60 (0-59); valid when totalMinutes > 0.
/// Max selectable = 23*60 + 59 = 1439.
const int kSessionMinMinutes = 1;
const int kSessionMaxMinutes = 23 * 60 + 59; // 1439
bool isValidSessionMinutes(int totalMinutes) =>
    totalMinutes >= kSessionMinMinutes && totalMinutes <= kSessionMaxMinutes;

/// Mirrors create_child_profile_screen.dart:325-336.
/// empty -> rejected; length < 2 -> rejected; duplicate -> rejected.
/// NOTE: the app enforces NO maximum length.
String? validateChildName(String raw, {Set<String> existingLower = const {}}) {
  final n = raw.trim();
  if (n.isEmpty) return 'Please enter a name';
  if (n.length < 2) return 'Name must be at least 2 characters';
  if (existingLower.contains(n.toLowerCase())) return 'That name is already used';
  return null; // valid (no max length)
}

/// Mirrors login_screen.dart:54-90 outcome mapping given Supabase responses.
/// Supabase returns 'Invalid login credentials' for BOTH an unknown email and
/// a wrong password, so the app shows the same message for both.
String loginOutcome({
  required bool registered,
  required bool passwordCorrect,
  required bool emailVerified,
}) {
  if (!registered || !passwordCorrect) {
    return 'Invalid email or password!'; // login_screen.dart:76-77
  }
  if (!emailVerified) {
    return 'Please verify your email!'; // login_screen.dart:78-79
  }
  return 'SUCCESS';
}

PerformanceGoal _goal(GoalCategory cat, int target, int progress) =>
    PerformanceGoal(
      id: 't',
      category: cat,
      target: target,
      duration: GoalDuration.today,
      currentProgress: progress,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  // ═══════════════════════════════════════════════════════════════════════
  // EQUIVALENCE PARTITIONING
  // ═══════════════════════════════════════════════════════════════════════
  group('EP — Email (Register)', () {
    test('EP-E1 valid a@b.com -> valid', () {
      expect(isValidRegisterEmail('a@b.com'), isTrue);
    });
    test('EP-E2 missing @ (ab.com) -> invalid', () {
      expect(isValidRegisterEmail('ab.com'), isFalse);
    });
    test('EP-E3 missing domain (a@) -> invalid', () {
      expect(isValidRegisterEmail('a@'), isFalse);
    });
    test('EP-E4 empty -> invalid', () {
      expect(isValidRegisterEmail(''), isFalse);
    });
  });

  group('EP — Password (Register)', () {
    test('EP-P1 8 chars -> valid', () {
      expect(isValidRegisterPassword('abcd1234'), isTrue);
    });
    test('EP-P2 < 8 chars -> invalid', () {
      expect(isValidRegisterPassword('abc'), isFalse);
    });
    test('EP-P3 > 72 chars -> VALID (app has no max; gap vs 72 assumption)', () {
      expect(isValidRegisterPassword('a' * 73), isTrue);
    });
    test('EP-P4 empty -> invalid', () {
      expect(isValidRegisterPassword(''), isFalse);
    });
  });

  group('EP — Star goal', () {
    test('EP-S1 positive int (5) -> valid', () {
      expect(isSelectableStarTarget(5), isTrue);
    });
    test('EP-S2 0 -> invalid (below min)', () {
      expect(isSelectableStarTarget(0), isFalse);
    });
    test('EP-S3 negative (-1) -> invalid', () {
      expect(isSelectableStarTarget(-1), isFalse);
    });
    test('EP-S4 non-numeric -> invalid (cannot be selected)', () {
      expect(isSelectableStarTarget(double.nan), isFalse);
    });
  });

  group('EP — Child name', () {
    test('EP-N1 valid (Sam) -> accepted', () {
      expect(validateChildName('Sam'), isNull);
    });
    test('EP-N2 empty -> rejected', () {
      expect(validateChildName('   '), 'Please enter a name');
    });
    test('EP-N3 60 chars -> ACCEPTED (app has no max; gap vs max assumption)',
        () {
      expect(validateChildName('a' * 60), isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // BOUNDARY VALUE ANALYSIS
  // ═══════════════════════════════════════════════════════════════════════
  group('BVA — Password length (min 8, no max)', () {
    test('BVA-P-7 -> invalid', () => expect(isValidRegisterPassword('a' * 7), isFalse));
    test('BVA-P-8 -> valid', () => expect(isValidRegisterPassword('a' * 8), isTrue));
    test('BVA-P-9 -> valid', () => expect(isValidRegisterPassword('a' * 9), isTrue));
    test('BVA-P-71 -> valid', () => expect(isValidRegisterPassword('a' * 71), isTrue));
    test('BVA-P-72 -> valid', () => expect(isValidRegisterPassword('a' * 72), isTrue));
    test('BVA-P-73 -> VALID (no max enforced; gap vs 72 assumption)',
        () => expect(isValidRegisterPassword('a' * 73), isTrue));
  });

  group('BVA — Star goal (range 1..100)', () {
    test('BVA-S-0 -> invalid', () => expect(isSelectableStarTarget(0), isFalse));
    test('BVA-S-1 -> valid', () => expect(isSelectableStarTarget(1), isTrue));
    test('BVA-S-2 -> valid', () => expect(isSelectableStarTarget(2), isTrue));
    test('BVA-S-9 -> valid', () => expect(isSelectableStarTarget(9), isTrue));
    test('BVA-S-10 -> valid', () => expect(isSelectableStarTarget(10), isTrue));
    test('BVA-S-11 -> VALID (max is 100, not 10; gap vs 1..10 assumption)',
        () => expect(isSelectableStarTarget(11), isTrue));
  });

  group('BVA — Session minutes (range 1..1439)', () {
    test('BVA-T-0 -> invalid', () => expect(isValidSessionMinutes(0), isFalse));
    test('BVA-T-1 -> valid', () => expect(isValidSessionMinutes(1), isTrue));
    test('BVA-T-2 -> valid', () => expect(isValidSessionMinutes(2), isTrue));
    test('BVA-T-59 -> valid', () => expect(isValidSessionMinutes(59), isTrue));
    test('BVA-T-60 -> valid', () => expect(isValidSessionMinutes(60), isTrue));
    test('BVA-T-61 -> VALID (max is 1439, not 60; gap vs 1..60 assumption)',
        () => expect(isValidSessionMinutes(61), isTrue));
  });

  // ═══════════════════════════════════════════════════════════════════════
  // DECISION TABLE TESTING
  // ═══════════════════════════════════════════════════════════════════════
  group('DT — Login', () {
    test('DT-L1 unregistered + any pw -> "Invalid email or password!"', () {
      expect(
          loginOutcome(registered: false, passwordCorrect: false, emailVerified: false),
          'Invalid email or password!');
    });
    test('DT-L2 registered + wrong pw -> "Invalid email or password!"', () {
      expect(
          loginOutcome(registered: true, passwordCorrect: false, emailVerified: true),
          'Invalid email or password!');
    });
    test('DT-L3 correct creds + unverified -> "Please verify your email!"', () {
      expect(
          loginOutcome(registered: true, passwordCorrect: true, emailVerified: false),
          'Please verify your email!');
    });
    test('DT-L4 correct creds + verified -> SUCCESS', () {
      expect(
          loginOutcome(registered: true, passwordCorrect: true, emailVerified: true),
          'SUCCESS');
    });
  });

  group('DT — Goal enforcement (real PerformanceGoal.isComplete)', () {
    test('DT-G1 time NOT reached + star NOT reached -> both incomplete', () {
      final time = _goal(GoalCategory.timeSpent, 30, 10);
      final star = _goal(GoalCategory.starCollection, 10, 3);
      expect(time.isComplete, isFalse);
      expect(star.isComplete, isFalse);
    });
    test('DT-G2 time NOT reached + star reached -> time incomplete, star complete', () {
      final time = _goal(GoalCategory.timeSpent, 30, 10);
      final star = _goal(GoalCategory.starCollection, 10, 10);
      expect(time.isComplete, isFalse);
      expect(star.isComplete, isTrue);
    });
    test('DT-G3 time reached + star NOT reached -> time complete, star incomplete', () {
      final time = _goal(GoalCategory.timeSpent, 30, 30);
      final star = _goal(GoalCategory.starCollection, 10, 3);
      expect(time.isComplete, isTrue);
      expect(star.isComplete, isFalse);
    });
    test('DT-G4 time reached + star reached -> both complete', () {
      final time = _goal(GoalCategory.timeSpent, 30, 45);
      final star = _goal(GoalCategory.starCollection, 10, 10);
      expect(time.isComplete, isTrue);
      expect(star.isComplete, isTrue);
    });
  });
}
