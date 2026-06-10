// White-box test suite (CSE442) — EmoLor
//
// Techniques: Statement, Branch, and Path coverage.
//
// The three target validators are implemented INLINE inside widget methods
// (RegisterScreen._register, LoginScreen._login catch-block, and the
// CreateChildProfileScreen name FormField validator). Two of those screens
// touch Supabase on build/initState, so they cannot be pumped in a plain unit
// test without a mocked Supabase singleton. To exercise the control flow
// without changing app logic, the functions below are EXTRACTED VERBATIM from
// the cited source lines. The suite also exercises the REAL
// `ChildSessionService.valenceToZone` for genuine app-file coverage.

import 'package:flutter_test/flutter_test.dart';
import 'package:emolor_flutter/features/child/services/child_session_service.dart';

// ─────────────────────────────────────────────────────────────────────────
// Extracted-verbatim logic (cited)
// ─────────────────────────────────────────────────────────────────────────

/// register_screen.dart:45-70 (password-relevant guards within _register).
/// Returns the error string the app would set, or null if the password passes.
String? validatePassword(String pw) {
  if (pw.isEmpty) {
    return '⚠️ Please fill in all required fields!'; // :45-49 (combined check)
  }
  if (pw.length < 8 || pw.length > 72) {
    return '⚠️ Password must be 8–72 characters!'; // :64-67
  }
  return null; // valid
}

/// login_screen.dart:76-85 (error-message mapping within _login catch).
String mapLoginError(String raw) {
  if (raw.contains('Invalid login credentials')) {
    return 'Invalid email or password!'; // :76-77
  } else if (raw.contains('Email not confirmed')) {
    return 'Please verify your email!'; // :78-79
  } else {
    return raw
        .replaceAll('Exception:', '')
        .replaceAll('AuthException:', '')
        .trim(); // :80-85
  }
}

/// create_child_profile_screen.dart:325-339 (name FormField validator).
String? validateChildName(String? v, {Set<String> existing = const {}}) {
  if (v == null || v.trim().isEmpty) {
    return 'Please enter a name'; // :326-327
  }
  if (v.trim().length < 2) {
    return 'Name must be at least 2 characters'; // :329-330
  }
  if (v.trim().length > 30) {
    return 'Name is too long (max 30 characters)'; // :332-333
  }
  if (existing.contains(v.trim().toLowerCase())) {
    return 'That name is already used'; // :335-337
  }
  return null; // :339 valid
}

void main() {
  // ═══════════════════════════════════════════════════════════════════════
  // STATEMENT COVERAGE — password validator (one input per return path)
  // ═══════════════════════════════════════════════════════════════════════
  group('Statement coverage — validatePassword', () {
    test('WB-PW-S1 empty -> all-fields error', () {
      expect(validatePassword(''), '⚠️ Please fill in all required fields!');
    });
    test('WB-PW-S2 < 8 -> length error', () {
      expect(validatePassword('abc'), '⚠️ Password must be 8–72 characters!');
    });
    test('WB-PW-S3 valid (8..72) -> null', () {
      expect(validatePassword('abcd1234'), isNull);
    });
    test('WB-PW-S4 > 72 -> length error', () {
      expect(validatePassword('a' * 73), '⚠️ Password must be 8–72 characters!');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // BRANCH COVERAGE — login outcome (each condition true AND false)
  // ═══════════════════════════════════════════════════════════════════════
  group('Branch coverage — mapLoginError', () {
    test('WB-LG-B1 D1 true (Invalid login credentials)', () {
      expect(mapLoginError('AuthException: Invalid login credentials'),
          'Invalid email or password!');
    });
    test('WB-LG-B2 D1 false, D2 true (Email not confirmed)', () {
      expect(mapLoginError('AuthException: Email not confirmed'),
          'Please verify your email!');
    });
    test('WB-LG-B3 D1 false, D2 false (else branch strips prefixes)', () {
      expect(mapLoginError('Exception: Network error'), 'Network error');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // PATH COVERAGE — child-name validator (all independent paths)
  // ═══════════════════════════════════════════════════════════════════════
  group('Path coverage — validateChildName', () {
    test('WB-CN-P1 null -> "Please enter a name"', () {
      expect(validateChildName(null), 'Please enter a name');
    });
    test('WB-CN-P2 empty/whitespace -> "Please enter a name"', () {
      expect(validateChildName('   '), 'Please enter a name');
    });
    test('WB-CN-P3 length < 2 -> min error', () {
      expect(validateChildName('a'), 'Name must be at least 2 characters');
    });
    test('WB-CN-P4 length > 30 -> max error', () {
      expect(validateChildName('a' * 31), 'Name is too long (max 30 characters)');
    });
    test('WB-CN-P5 duplicate -> already used', () {
      expect(validateChildName('Sam', existing: {'sam'}),
          'That name is already used');
    });
    test('WB-CN-P6 valid -> null', () {
      expect(validateChildName('Sam', existing: {'bob'}), isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // REAL app code — ChildSessionService.valenceToZone (full branch coverage)
  // ═══════════════════════════════════════════════════════════════════════
  group('Real-code branch coverage — valenceToZone', () {
    test('WB-VZ-1 positive -> 0', () => expect(ChildSessionService.valenceToZone('positive'), 0));
    test('WB-VZ-2 negative -> 3 (F5 fix)', () => expect(ChildSessionService.valenceToZone('negative'), 3));
    test('WB-VZ-3 negative_high -> 3', () => expect(ChildSessionService.valenceToZone('negative_high'), 3));
    test('WB-VZ-4 negative_low -> -1', () => expect(ChildSessionService.valenceToZone('negative_low'), -1));
    test('WB-VZ-5 neutral -> 0', () => expect(ChildSessionService.valenceToZone('neutral'), 0));
    test('WB-VZ-6 unknown -> null (default branch)', () => expect(ChildSessionService.valenceToZone('xyz'), isNull));
  });
}
