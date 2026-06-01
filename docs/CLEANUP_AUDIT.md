# EMOLOR — Repository Cleanup Audit (Phase 1: Report Only)

**Generated:** 2026-06-01
**Scope:** Finalized Android tablet FYP application (admin / therapist / chat / messaging / request-session / web portal already removed from scope).
**Status:** AUDIT ONLY — no files were edited, deleted, moved, or created during this run except this report.

> ⚠️ **Do not execute Phase 2 until the working tree is committed and a `repo-cleanup` branch is created.** See Section J for exact commands. Every recommendation below is reversible if performed on a dedicated branch.

---

## ⓿ Pre-flight: Working Tree Is NOT Clean

A clean, committed baseline is a hard prerequisite before any cleanup.

Current state of `git status`:

- **Branch:** `claude-elegant-leavitt` (ahead of `origin/claude/elegant-leavitt` by 9 commits — **not pushed**).
- **Uncommitted modifications (M):** 20+ source/doc files, including this session's bug fixes (`analytics_dashboard.dart`, `instructions_service.dart`, `main.dart`, `auth_service.dart`, `update_password_screen.dart`, the two game screens, etc.).
- **Uncommitted deletions (D) already staged in the working tree but not committed:**
  - `docs/` — 10 files (`ARCHITECTURE_REFINEMENT.md`, `DATABASE_MIGRATION_GUIDE.md`, `DEVELOPMENT_GUIDE.md`, `FIGMA_DESIGN_GUIDE.md`, `FLOW_DIAGRAMS.md`, `FLUTTER_NEXT_STEPS.md`, `IMPLEMENTATION_STATUS.md`, `README.md`, `REFINEMENT_COMPLETE.md`, `USER_TESTING_PLAN.md`)
  - `mobile_app/lib/screens/express_cards_screen.dart`
  - `supabase/functions/generate-insight/index.ts`

**Action required first:** commit (or stash) the current changes so the audit/cleanup starts from a known baseline. Without this, a reviewer cannot tell intentional cleanup from unfinished work.

---

## A. Repository Structure Assessment

```
EMOLOR/
├── .claude/                      ⚠ AI tooling artifacts TRACKED in git (should be local-only)
│   ├── settings.local.json       ⚠ tracked
│   └── worktrees/elegant-leavitt ⚠ tracked
├── .gitignore                    ✅ good (ignores build/, .dart_tool/, .env, .claude, .vscode/*)
├── .vscode/settings.json         (ignored by .gitignore — local only)
├── README.md                     ✅ accurate to final scope (minor polish only)
├── setup_flutter.ps1             ❌ STALE & BROKEN — references deleted paths/files & out-of-scope platforms
├── database/
│   ├── README.md                 ⚠ minor markdown bug (unclosed code fence)
│   ├── final_schema/             ✅ KEEP — 7 ordered, well-named schema files
│   └── archive/                  ✅ KEEP (archived migrations — clearly labelled history)
├── docs/                         ⏳ contents deleted in working tree (pending commit) — replaced by this report
├── supabase/
│   └── functions/generate-insight/index.ts  🗑 UNUSED (app calls Claude directly) — deletion pending
└── mobile_app/
    ├── .env.example              ✅ KEEP (placeholders only, no real secret)
    ├── .metadata                 ✅ KEEP (standard Flutter file)
    ├── analysis_options.yaml     ✅ KEEP (standard flutter_lints config)
    ├── devtools_options.yaml     ✅ KEEP (standard)
    ├── pubspec.yaml / .lock       ✅ KEEP (lock committed = reproducible)
    ├── android/                  ✅ healthy (local.properties correctly gitignored)
    ├── assets/                   ✅ used (audio + images declared in pubspec)
    ├── test/widget_test.dart     ⚠ verify it still compiles (default template test)
    └── lib/                      mostly healthy; orphan cluster noted in Section H
```

Overall: the repo is in **good shape**. The READMEs already reflect the reduced scope. The main issues are (1) an uncommitted tree, (2) a broken setup script, (3) AI tooling files tracked in git, (4) a small orphaned-code cluster, and (5) several unused dependencies from removed-scope features.

---

## B. Files Safe to Remove

> All "safe" classifications were verified by searching for references/imports across `lib/`. Still perform on the `repo-cleanup` branch and run `flutter analyze` after.

| File / Path | Evidence | Reason |
|---|---|---|
| `mobile_app/lib/screens/express_cards_screen.dart` | `grep express_cards/ExpressCards` → **0 references** | Already deleted in working tree; confirm + commit. No imports anywhere. |
| `supabase/functions/generate-insight/index.ts` | `ai_insight_service.dart` calls `https://api.anthropic.com` **directly via `dio`** — the edge function is never invoked | Already deleted in working tree; confirm + commit. Out of final scope and unused. |
| `mobile_app/lib/features/caregiver/presentation/screens/progress_dashboard_screen.dart` | `grep ProgressDashboardScreen` → **0 external references** | Orphaned old caregiver dashboard, superseded by `analytics_dashboard.dart`. |
| `mobile_app/lib/features/caregiver/presentation/screens/progress_tab.dart` | `grep ProgressTab` → only matches the unrelated `_buildProgressTab()` method in `analytics_dashboard.dart` | Orphaned; the live Progress tab lives inside `analytics_dashboard.dart`. |
| `mobile_app/lib/features/caregiver/services/progress_dashboard_service.dart` | Imported **only** by the orphaned `progress_dashboard_screen.dart` | Orphaned transitively once the screen above is removed. |
| `setup_flutter.ps1` | References `flutter_app\lib` (doesn't exist), `--platforms=android,ios,web` (out of scope), and `FLUTTER_NEXT_STEPS.md` (deleted) | Broken & misleading. Remove, or replace with the minimal accurate version in Section F. |

**Untrack (remove from git, keep on disk) — not delete:**

| Path | Action | Reason |
|---|---|---|
| `.claude/settings.local.json` | `git rm --cached` | `.claude` is in `.gitignore` but these were committed before the rule. AI-tooling artifact; should be local-only. |
| `.claude/worktrees/elegant-leavitt` | `git rm --cached` | Same — internal worktree pointer, not project source. |

> Note: untracking `.claude/` is repo-hygiene only. **Do not remove any FYP-required AI-usage disclosure** (that belongs in your report/thesis, not in `.claude/`).

---

## C. Files Safe to Archive

| File / Path | Recommendation | Reason |
|---|---|---|
| `database/archive/*` | **Keep as-is** (already archived) | Clearly labelled historical migrations; good for traceability under examiner review. No action needed. |
| `docs/` historical guides (already deleted) | Optionally preserve in git history / a `docs/archive/` tag rather than hard-loss | They are removed from the working tree; they remain recoverable via git history. If any (e.g. architecture/flow diagrams) are useful for the FYP report, consider restoring a curated subset instead of deleting all 10. |

If you want to retain design/flow documentation for examiners, **archive a curated subset** (e.g. `FLOW_DIAGRAMS.md`, `ARCHITECTURE_REFINEMENT.md`) under `docs/` rather than deleting everything. The other 8 (status logs, "next steps", "refinement complete", testing plans) read as in-progress dev notes and are fine to drop.

---

## D. Files to Keep

| File / Path | Reason |
|---|---|
| `README.md` (root) | Accurate, scoped, professional. Minor polish only (Section F). |
| `mobile_app/README.md` | Accurate feature list + folder map. |
| `database/README.md` | Accurate active-scope documentation. One markdown fix (Section F). |
| `database/final_schema/01–07_*.sql` | The authoritative schema. Well-ordered and named. |
| `mobile_app/pubspec.lock` | Committed lockfile = reproducible builds (correct for an app). |
| `mobile_app/.metadata` | Standard Flutter project metadata — conventional to commit. |
| `mobile_app/analysis_options.yaml`, `devtools_options.yaml` | Standard tooling config. |
| `mobile_app/.env.example` | Safe placeholder template; documents required env vars. |
| `assets/` (audio + images) | All declared in `pubspec.yaml` and used by the app. |

---

## E. Security Findings

### E1. Supabase URL + anon key hardcoded in source (MEDIUM, with nuance)

**File:** `mobile_app/lib/core/constants/app_constants.dart` (lines 9–18)

```dart
static const String supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://chcevgwoyfffiqeqwbde.supabase.co');
static const String supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'eyJhbGciOiJIUzI1NiI...role":"anon"...');  // committed
```

- **Nuance:** the committed key is the **`anon` (publishable) key** (its JWT payload decodes to `"role":"anon"`). Supabase anon keys are *designed* to ship in client apps and are protected by Row-Level Security — this is **not** a `service_role` key leak. Severity is therefore **medium, not critical**.
- **Why it still matters for an FYP repo:** hardcoding any key as a `defaultValue` is poor practice and contradicts your own `// TODO: Move these to environment variables` (line 8) and the `.env.example` you already provide.
- **Recommendation:**
  1. Remove the `defaultValue` literals; require `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...` (or a `--dart-define-from-file`). Document in README.
  2. **Rotate the anon key** in the Supabase dashboard if you want a clean slate (optional given RLS, but trivial and tidy before submission).
  3. If you rotate and want the old key gone from history, scrub it (Section J) — **optional** for an anon key, recommended only if examiners will clone full history.
  4. **Confirm RLS is enabled** on every table the anon key can reach (this is the real protection, not key secrecy).

### E2. Claude API key handling (GOOD — no committed secret, but APK exposure note)

**File:** `mobile_app/lib/core/services/ai_insight_service.dart`

- ✅ The Anthropic key is read from `--dart-define=ANTHROPIC_API_KEY` with `defaultValue: ''` — **no key is committed.** Good.
- ⚠ **Architectural note:** the app calls `api.anthropic.com` **directly from the client**, so whatever key is passed at build time is **compiled into the APK** and is extractable by decompiling. For a production posture the documented fix is the Supabase Edge Function proxy (ironically the `generate-insight` function we're removing). For an FYP demo this is acceptable, but **document it as a known limitation**.
- 🔸 **Minor:** lines 39–41 `debugPrint` the API-key presence and a 10-char prefix. Remove these debug lines (Section comment-cleanup) — don't log key material, even prefixes.

### E3. No real `.env` committed (GOOD)

- `git ls-files` shows only `mobile_app/.env.example` (placeholders). `.env`/`*.env` are correctly gitignored at both root and `mobile_app/`. ✅

---

## F. Documentation Improvements

### F1. `database/README.md` — unclosed code fence (markdown bug)
The ```` ```text ```` fence opened under "Folder Structure" is never closed before the next `##` heading, which breaks rendering. Add a closing ```` ``` ````.

### F2. `setup_flutter.ps1` is referenced/obsolete — replace or remove
It points to `FLUTTER_NEXT_STEPS.md` (deleted), a `flutter_app/` layout (doesn't exist), and web/Windows run targets (out of scope). Either delete it (Section B) or replace with an accurate minimal version, e.g.:

```powershell
# EMOLOR — Flutter setup (Android tablet)
cd mobile_app
flutter pub get
# Provide secrets at run time (never commit them):
flutter run -d <android-device-id> `
  --dart-define=SUPABASE_URL=https://<project>.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=<anon-key> `
  --dart-define=ANTHROPIC_API_KEY=<claude-key>
```

### F3. Root `README.md` — add minimal build/run + env instructions
The README describes scope and flow well but has **no setup/run section**. Add a short "Getting Started" covering: Flutter SDK version, `flutter pub get`, the three `--dart-define` values, and "Android tablet only." Optionally add a one-paragraph architecture overview (Flutter + Riverpod + GoRouter front end; Supabase Postgres/Auth/RPC back end; Claude API for insights; local PDF generation).

### F4. Cross-reference cleanup
After deleting `docs/`, grep the READMEs for any links to the removed guides and remove dangling references (the root README currently does not link them — verify after commit).

---

## G. Dependency Audit

Method: `grep -rl "package:<name>/" lib/` for every dependency, plus targeted checks for indirect usages (e.g. `Printing.sharePdf`, `DateFormat`).

| Package | Import hits | Verdict | Notes |
|---|---|---|---|
| `flutter_riverpod` | 14 | **Keep** | Core state management. |
| `go_router` | 17 | **Keep** | Navigation. |
| `supabase_flutter` | 15 | **Keep** | Backend/auth. |
| `shared_preferences` | 16 | **Keep** | Local-first storage. |
| `google_fonts` | 39 | **Keep** | UI typography. |
| `fl_chart` | 4 | **Keep** | Analytics charts. |
| `audioplayers` | 4 | **Keep** | Game/bg audio. |
| `flutter_tts` | 2 | **Keep** | Instructions read-aloud (UCD015). |
| `uuid` | 2 | **Keep** | ID generation. |
| `crypto` | 2 | **Keep** | PIN/hash. |
| `confetti` | 2 | **Keep** | Reward effects. |
| `dio` | 1 | **Keep** | Claude API client (`ai_insight_service.dart`). |
| `pdf` | 1 | **Keep** | PDF report. |
| `printing` | 1 | **Keep** | PDF render + `Printing.sharePdf` (also covers sharing). |
| `cupertino_icons` | 0 | **Keep** | Standard Flutter template dep; bundled icon font, not imported directly. |
| `intl` | 0 | **Review → likely Remove** | No `package:intl` import; date formatting is done manually. Confirm with `flutter pub deps` it isn't a needed transitive pin. |
| `share_plus` | 0 | **Safe to Remove** | Sharing is handled by `Printing.sharePdf`, not `share_plus`. |
| `path_provider` | 0 | **Safe to Remove** | No imports; PDF flow uses in-memory bytes via `printing`. |
| `flutter_svg` | 0 | **Safe to Remove** | All assets are `.png`; no SVG usage. |
| `file_picker` | 0 | **Safe to Remove** | UCD019 (upload media) — removed scope. |
| `url_launcher` | 0 | **Safe to Remove** | UCD030 (open media) — removed scope. |
| `permission_handler` | 0 | **Safe to Remove** | UCD032 (download media) — removed scope. |
| `gal` | 0 | **Safe to Remove** | UCD032 (save to gallery) — removed scope. |
| `csv` | 0 | **Safe to Remove** | UCD045 CSV export — report is PDF-only now. |

**Recommended removals (8):** `share_plus`, `path_provider`, `flutter_svg`, `file_picker`, `url_launcher`, `permission_handler`, `gal`, `csv`.
**Review (1):** `intl`.
**After editing `pubspec.yaml`:** run `flutter pub get` then `flutter analyze` and a full build to confirm nothing transitive broke. Removing these also lets you drop the now-unneeded Android permissions (`WRITE/READ_EXTERNAL_STORAGE`, `READ_MEDIA_IMAGES`) in `AndroidManifest.xml` — **verify** no kept dependency still needs them before doing so.

---

## H. Architecture Findings

### H1. Orphaned code cluster — old caregiver dashboard (high confidence)
Superseded by `mobile_app/lib/screens/analytics_dashboard.dart`. Zero external references:
- `lib/features/caregiver/presentation/screens/progress_dashboard_screen.dart`
- `lib/features/caregiver/presentation/screens/progress_tab.dart`
- `lib/features/caregiver/services/progress_dashboard_service.dart`

→ Remove together (Section B), then `flutter analyze`.

### H2. Dead route/constants in `app_constants.dart` (low risk, recommend review)
`AppConstants` still declares constants for removed-scope features:
`routeModerationQueue`, `routeCommConfig`, `routeSessionOversight`, `routeClientRecord`, `routeSessionResponse`, `routeScheduleSession`, plus possibly-unused `routeAbout`, `routeProfileSelect`, `routeCaregiver`, and `supportedLanguages`/`defaultLanguage` (no i18n in the app). These compile but are misleading dead constants.
→ **Review and trim** the removed-scope ones. Conservative: leave the active route strings; remove only the clearly removed-scope constants. Verify each with a `grep` before deleting.

### H3. `link_account_screen.dart` (manual review)
`LinkAccountScreen` is still referenced/routed (1–2 files). "Link client account" was associated with removed scope in earlier phases — **confirm with the team** whether account-linking is still part of the final flow. If not, it (and its route) are removal candidates; if yes, keep. Do not auto-remove.

### H4. Removed-scope comment tags (cosmetic)
45 `UCD0xx` tags remain in code comments, several referencing removed features (e.g. UCD019/030/032). They're harmless but can read as leftover scaffolding to an examiner. Optional: trim tags tied to removed features during comment cleanup (Section below).

### H5. Dead "REMOVED" code in `analytics_dashboard.dart`
- Line ~3201: `// REMOVED — replaced by 4-chart Progress tab layout.`
- Line ~4883–4886: `_buildMyChildTab_REMOVED()` — a dead method with a non-standard name (also flagged by `flutter analyze` as `unused_element`).
→ Delete the dead method and stale "REMOVED" markers.

---

## Comment / Debug Cleanup (Objective 2)

Verified counts in `lib/`:
- **`debugPrint`/`print`: ~60 occurrences.** Many are development tracing (e.g. `ai_insight_service.dart` logging API-key prefix; `_loadChildProfile`, `recordPreEmotion`, PDF debug lines). **Recommendation:** remove debug-only prints, **especially the API-key-prefix logs (E2)**. Keep none that log secrets; keep error logging only where it aids support.
- **`TODO/FIXME`: 3 occurrences.** Resolve or remove (the `app_constants.dart` env-var TODO is addressed by Section E1).
- **Dead-code markers:** `_buildMyChildTab_REMOVED`, `// REMOVED …` (Section H5).
- **Keep:** doc comments (`///`), business-logic explanations (e.g. the regulation-zone math, the email-change/userUpdated suppression note, the deep-link callback rationale), and security notes. These are valuable for examiners.

Do **not** mass-strip comments — target only obsolete/commented-out/debug lines.

---

## I. Recommended Final Repository Structure

```
EMOLOR/
├── README.md                     # scope + flow + Getting Started (new section)
├── .gitignore
├── database/
│   ├── README.md                 # fenced-code fix
│   ├── final_schema/01–07_*.sql
│   └── archive/                  # labelled history (kept)
├── docs/
│   ├── CLEANUP_AUDIT.md          # this report
│   └── (optional curated subset: FLOW_DIAGRAMS.md, ARCHITECTURE_REFINEMENT.md)
└── mobile_app/
    ├── README.md
    ├── .env.example
    ├── analysis_options.yaml
    ├── devtools_options.yaml
    ├── pubspec.yaml              # 8 unused deps removed
    ├── pubspec.lock
    ├── android/                  # permissions trimmed to what's used
    ├── assets/{audio,images}/
    ├── test/widget_test.dart
    └── lib/
        ├── main.dart
        ├── core/{constants,data,logic,router,services,theme,widgets}
        ├── features/{auth,caregiver,child,child_profile,profile}
        └── screens/              # express_cards & orphan dashboard files removed
```

Removed from tracking (local-only): `.claude/`.
Removed entirely: `supabase/functions/` (unused edge function), `setup_flutter.ps1` (or replaced).

---

## J. Exact Commands To Execute (DO NOT RUN YET — await approval)

### Step 0 — Commit current work + create safety branch
```bash
cd "C:/Users/User/EMOLOR"
git add -A
git commit -m "chore: checkpoint before repo cleanup audit"
git checkout -b repo-cleanup
```

### Step 1 — Untrack AI tooling artifacts (keep on disk)
```bash
git rm -r --cached .claude
git commit -m "chore: stop tracking .claude tooling artifacts (already in .gitignore)"
```

### Step 2 — Confirm already-pending deletions (docs/, express_cards, edge function)
```bash
# These are already deleted in the working tree from Step 0's commit.
# Verify nothing references them:
grep -rn "express_cards\|ExpressCards" mobile_app/lib   # expect: no output
grep -rn "generate-insight" mobile_app/lib              # expect: no output
```

### Step 3 — Remove orphaned old-dashboard cluster
```bash
git rm mobile_app/lib/features/caregiver/presentation/screens/progress_dashboard_screen.dart
git rm mobile_app/lib/features/caregiver/presentation/screens/progress_tab.dart
git rm mobile_app/lib/features/caregiver/services/progress_dashboard_service.dart
```

### Step 4 — Remove / replace the stale setup script
```bash
git rm setup_flutter.ps1
# (or) replace with the minimal version from Section F2, then: git add setup_flutter.ps1
```

### Step 5 — Remove unused dependencies (edit pubspec.yaml), then verify
Remove these lines from `mobile_app/pubspec.yaml`:
`flutter_svg`, `file_picker`, `url_launcher`, `permission_handler`, `gal`, `csv`, `share_plus`, `path_provider` (and `intl` only after confirming it's unused).
```bash
cd mobile_app
flutter pub get
flutter analyze
flutter build apk --debug   # full build to catch transitive breakage
cd ..
```

### Step 6 — Security: stop committing the anon key + rotate (optional history scrub)
1. Edit `mobile_app/lib/core/constants/app_constants.dart`: remove the `defaultValue` literals for `supabaseUrl`/`supabaseAnonKey`; require `--dart-define`.
2. (Optional) Rotate the anon key in Supabase → Project Settings → API.
3. (Optional, only if scrubbing history) — **destructive, coordinate with team:**
```bash
# Using git-filter-repo (preferred):
git filter-repo --replace-text <(echo 'eyJhbGciOiJIUzI1NiIs...==>REDACTED')
# Then force-push the rewritten history:
git push --force-with-lease origin repo-cleanup
```

### Step 7 — Docs fixes
- Fix the unclosed code fence in `database/README.md`.
- Add a "Getting Started" section to root `README.md` (Section F3).

### Step 8 — Comment/debug cleanup
- Remove the API-key `debugPrint` lines in `ai_insight_service.dart`.
- Remove `_buildMyChildTab_REMOVED()` and stale `// REMOVED` markers in `analytics_dashboard.dart`.
- Trim development-only `debugPrint`s and resolve the 3 TODOs.

### Step 9 — Final verification before merge
```bash
cd mobile_app
flutter analyze
flutter test
flutter build apk --debug
cd ..
git add -A && git commit -m "chore: repo cleanup (deps, orphans, docs, secrets handling)"
# Review the full diff, then merge repo-cleanup back when satisfied.
```

---

## Summary of Recommendations (priority order)

1. **Commit the working tree + branch `repo-cleanup`** before anything else.
2. **Stop tracking `.claude/`** (`git rm --cached`).
3. **Stop committing the Supabase anon key** (remove `defaultValue`s; rotate optional); confirm RLS.
4. **Remove the API-key `debugPrint`** lines.
5. **Remove 8 unused dependencies** + trim now-unused Android permissions (after a clean build).
6. **Remove the orphaned old-dashboard cluster** (3 files).
7. **Delete/replace `setup_flutter.ps1`**; confirm the pending `docs/`, `express_cards`, and `supabase/functions/` deletions.
8. **Fix `database/README.md` fence + add a Getting Started section** to the root README.
9. **Manual review:** `link_account_screen.dart`, `intl`, dead route constants, and whether to retain a curated `docs/` subset for examiners.

*End of Phase 1 report. No changes were made beyond writing this file. Awaiting approval to proceed with Phase 2.*
