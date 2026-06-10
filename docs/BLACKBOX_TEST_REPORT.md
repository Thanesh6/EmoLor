# EmoLor — Black-Box Test Report (CSE442)

**Techniques:** Equivalence Partitioning (EP), Boundary Value Analysis (BVA), Decision Table Testing.
**Suite:** `mobile_app/test/black_box_test.dart` · **Runner:** `flutter test` · **Raw output:** `mobile_app/test_results.txt`
**Result:** 48 / 48 passed (`EXIT=0`).

> Testability note: input validation is implemented inline inside widget methods, and goal inputs come from clamped scroll wheels (no extracted validators). To test without altering app logic, validation rules are faithfully mirrored from the cited source lines; the goal-enforcement table runs against the **real** `PerformanceGoal.isComplete` getter, and the F5 mismatch tests call the **real** `ChildSessionService.valenceToZone` + `SensoryPalette.isSensoryMismatch`. "Expected" = the verified actual app spec (after the corrective fixes below).

---

## Verified constraints (with source)

| Rule | Actual app behavior | Source |
|------|--------------------|--------|
| Email — Register | Regex `^[\w\-\.]+@([\w\-]+\.)+[\w]{2,}$` | `register_screen.dart:56` |
| Email — Login | No format check; non-empty only | `login_screen.dart:38` |
| Password | **8–72** chars (min 8, **max 72 added — F1**) | `register_screen.dart:64-65` |
| Star goal | **1–100** | `set_goals_screen.dart:35-36`, `new_goal_dialog.dart:44-45` |
| Session/time goal | **1–1439** min (hours 0–23, mins 0–59) | `set_goals_screen.dart:75-77,237,256` |
| Child name | empty rejected; **min 2**; **max 30 added — F3** | `create_child_profile_screen.dart:326-339` |

Discrepancies vs original Test Plan assumptions: password max (assumed 72 — now enforced), star goal (assumed 1–10, actual **1–100**), session (assumed 1–60, actual **1–1439**).

---

## EP — Equivalence Partitioning

| TC ID | Expected Output | Actual Output | Status |
|-------|-----------------|---------------|--------|
| EP-E1 | `a@b.com` → valid | valid | Pass |
| EP-E2 | `ab.com` (no @) → invalid | invalid | Pass |
| EP-E3 | `a@` (no domain) → invalid | invalid | Pass |
| EP-E4 | empty → invalid | invalid | Pass |
| EP-P1 | 8 chars → valid | valid | Pass |
| EP-P2 | <8 chars → invalid | invalid | Pass |
| EP-P3 | 73 chars → invalid (max 72) | invalid | Pass |
| EP-P4 | empty → invalid | invalid | Pass |
| EP-S1 | star 5 → valid | valid | Pass |
| EP-S2 | star 0 → invalid | invalid | Pass |
| EP-S3 | star −1 → invalid | invalid | Pass |
| EP-S4 | non-numeric → invalid | invalid | Pass |
| EP-N1 | "Sam" → accepted | accepted | Pass |
| EP-N2 | empty → rejected | rejected | Pass |
| EP-N3 | 60 chars → rejected (max 30) | rejected | Pass |
| EP-N4 | duplicate name → rejected | rejected | Pass |

## BVA — Boundary Value Analysis

| TC ID | Expected Output | Actual Output | Status |
|-------|-----------------|---------------|--------|
| BVA-P-7 | invalid | invalid | Pass |
| BVA-P-8 | valid (lower boundary) | valid | Pass |
| BVA-P-9 | valid | valid | Pass |
| BVA-P-71 | valid | valid | Pass |
| BVA-P-72 | valid (upper boundary) | valid | Pass |
| BVA-P-73 | invalid (> 72) | invalid | Pass |
| BVA-S-0 | invalid (lower boundary) | invalid | Pass |
| BVA-S-1 | valid (lower boundary) | valid | Pass |
| BVA-S-2 | valid | valid | Pass |
| BVA-S-99 | valid | valid | Pass |
| BVA-S-100 | valid (upper boundary) | valid | Pass |
| BVA-S-101 | invalid (> 100) | invalid | Pass |
| BVA-T-0 | invalid (lower boundary) | invalid | Pass |
| BVA-T-1 | valid (lower boundary) | valid | Pass |
| BVA-T-2 | valid | valid | Pass |
| BVA-T-1438 | valid | valid | Pass |
| BVA-T-1439 | valid (upper boundary) | valid | Pass |
| BVA-T-1440 | invalid (> 1439) | invalid | Pass |
| BVA-N-1 | invalid (below min) | invalid | Pass |
| BVA-N-2 | valid (lower boundary) | valid | Pass |
| BVA-N-30 | valid (upper boundary) | valid | Pass |
| BVA-N-31 | invalid (> 30) | invalid | Pass |

## Decision Table

| TC ID | Conditions | Expected Output | Actual Output | Status |
|-------|-----------|-----------------|---------------|--------|
| DT-L1 | unregistered + any pw | "Invalid email or password!" | same | Pass |
| DT-L2 | registered + wrong pw | "Invalid email or password!" | same | Pass |
| DT-L3 | correct creds + unverified | "Please verify your email!" | same | Pass |
| DT-L4 | correct creds + verified | SUCCESS | SUCCESS | Pass |
| DT-G1 | time ✗ + star ✗ | both incomplete | both incomplete | Pass |
| DT-G2 | time ✗ + star ✓ | time ✗, star ✓ | match | Pass |
| DT-G3 | time ✓ + star ✗ | time ✓, star ✗ | match | Pass |
| DT-G4 | time ✓ + star ✓ | both complete | both complete | Pass |

Note: DT-L1 and DT-L2 intentionally share one message — Supabase returns `Invalid login credentials` for both an unknown email and a wrong password, so the UI cannot (and does not) distinguish them.

---

## Task 4 — Failures, defects & corrective actions

### F5 — Sensory-mismatch flag was inert (DEFECT — fixed via TDD)
- **Root cause:** emotions store valence as plain `'positive'`/`'negative'`, but `valenceToZone` only matched `'negative_high'`/`'negative_low'`/`'positive'`/`'neutral'`, so `'negative'` fell through to `return null`. With a null emotion zone, `recordPostEmotion` set `sensory_mismatch = false` for **every** negative emotion.
- **Responsible file/function:** `child_session_service.dart` → `valenceToZone()` (was `_valenceToZone`), used at `recordPostEmotion` line 139.
- **TDD evidence:**
  - RED (before fix): `F5-1 Expected: true, Actual: <false>` · `F5-2 Expected: not null, Actual: <null>`.
  - GREEN (after fix): both pass.
- **Before:**
  ```dart
  case 'positive': return 0;
  case 'negative_high': return 3;
  case 'negative_low': return -1;
  case 'neutral': return 0;
  default: return null;   // 'negative' fell through to here
  ```
- **After:**
  ```dart
  case 'positive': return 0;
  case 'negative':            // model stores plain 'negative'
    return 3;                 // elevated/distress → flags vs calm colours
  case 'negative_high': return 3;
  case 'negative_low': return -1;
  case 'neutral': return 0;
  default: return null;
  ```
- **Limitation noted:** with only positive/negative valence available, `'negative'` maps to a single distress zone (+3). Distinguishing high- vs low-arousal negatives (e.g. sad/tired) would require per-emotion mapping — recommended post-demo. The flag is not displayed in any UI, so this change has no visual impact.

### F1 — Password maximum length not enforced (requirement gap — fixed)
- **Gap vs Test Plan:** plan specified 8–72; app enforced only `< 8`, so a 73-char password was accepted client-side.
- **Responsible file/function:** `register_screen.dart` → `_register()` (line 64).
- **Corrective action:** added `|| length > 72` with message "Password must be 8–72 characters!". Covered by `EP-P3`, `BVA-P-72`, `BVA-P-73` (all pass).

### F3 — Child-name maximum length not enforced (requirement gap — fixed)
- **Gap vs Test Plan:** no upper bound on child name; an arbitrarily long name was accepted.
- **Responsible file/function:** `create_child_profile_screen.dart` → name `validator` (line ~331).
- **Corrective action:** added `length > 30 → "Name is too long (max 30 characters)"`. Covered by `EP-N3`, `BVA-N-30`, `BVA-N-31` (all pass).
- **Residual note:** the inline add/edit path in `orgz_child_dashboard.dart` `_validateName` still lacks the max-length (and min-2) checks — recommend aligning post-demo.

### F2 — Login performs no email-format/length validation (documented, not changed)
- **Observation:** `login_screen.dart:38` checks only `isEmpty`; malformed emails are forwarded to Supabase, which rejects them as invalid credentials. Not a crash; acceptable behavior. Left unchanged to avoid altering the auth flow before the demo.

---

## Code changes made (this run)
1. `child_session_service.dart` — exposed `valenceToZone` (`@visibleForTesting`) and added a `'negative'` case (F5 fix).
2. `register_screen.dart` — added password max-length 72 (F1 fix).
3. `create_child_profile_screen.dart` — added child-name max-length 30 (F3 fix).
4. `test/black_box_test.dart` — added F5 mismatch tests, real-limit BVA boundaries (star 99/100/101, session 1438/1439/1440, name 30/31), duplicate-name EP case; updated EP-P3/EP-N3/BVA-P-73 to the fixed behavior.
