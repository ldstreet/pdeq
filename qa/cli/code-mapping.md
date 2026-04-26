---
product-hash: ed6db9bb10905f9d40e8570d9d3ca7fceb6422dccb9c62c9ff294c196ad45b53
product-slugs: [AC-code-mapping-acknowledged-unimplemented, AC-code-mapping-audit-speed, AC-code-mapping-deterministic-output, AC-code-mapping-escape-hatch, AC-code-mapping-index-drops-removed, AC-code-mapping-index-reflects-markers, AC-code-mapping-marker-scope-enforced, AC-code-mapping-marker-syntax-per-type, AC-code-mapping-multi-slug-counted, AC-code-mapping-near-match-rejected, AC-code-mapping-orphan-marker-rejected, AC-code-mapping-planned-paths-living, AC-code-mapping-retirement-blocks, AC-code-mapping-stale-planned-path-rejected, AC-code-mapping-uncovered-blocks, AC-code-mapping-uncovered-warns, FR-code-mapping-acknowledged-unimplemented, FR-code-mapping-audit-coverage, FR-code-mapping-audit-coverage-blocks, FR-code-mapping-audit-coverage-grace, FR-code-mapping-audit-escape-hatch, FR-code-mapping-audit-scan, FR-code-mapping-audit-validates-path, FR-code-mapping-audit-validates-slug, FR-code-mapping-index-code-locations, FR-code-mapping-index-populated, FR-code-mapping-index-removes-stale, FR-code-mapping-marker-language, FR-code-mapping-marker-multi, FR-code-mapping-marker-presence, FR-code-mapping-marker-retirement-blocks, FR-code-mapping-marker-scope, FR-code-mapping-marker-slug-reference, FR-code-mapping-planned-paths, FR-code-mapping-planned-paths-living, FR-code-mapping-planned-paths-per-platform, NFR-code-mapping-audit-speed, NFR-code-mapping-determinism, NFR-code-mapping-precision, NFR-code-mapping-review-cost]
---
# Requirement ↔ Code Mapping — CLI Test Plan

> Based on requirements in `../../product/code-mapping.md`
> Based on engineering in `../../engineering/cli/code-mapping.md`
> (No design spec — feature has no UI surface.)

## What We're Testing

This plan verifies the extended `scripts/audit-traceability.sh` end-to-end: the marker scan across every file kind in the syntax table, the Code Map parser, coverage reconciliation with grace-period handling, retirement-blocking, index Code-column rewrite in both default (pre-commit) and `--check` (CI) modes, the `PDEQ_ALLOW_DRIFT` escape hatch, and the performance/determinism NFRs. Everything is shell-testable — no live agent required. Fixtures are temporary directories seeded with a minimal spec tree + synthetic source files, exercised through the audit script with env overrides to isolate each run from the real repository.

## Test Strategy

### Tooling

- **Primary harness**: plain POSIX shell test scripts under `engineering/apps/cli/tests/code-mapping/`. Matches the migrations harness style (`qa/cli/migrations.md` §Tooling) — `mktemp -d` fixture roots, `trap` cleanup, `assert_*` helpers from `tests/lib/assert.sh`.
- **New assertion helpers**: `assert_audit_exits <code>`, `assert_stderr_contains <substr>`, `assert_index_code_column <slug> <expected>` (diffs the `Code` cell of the index row for `slug`), `assert_marker_count <slug> <n>`.
- **Git fixture builder**: `make_git_fixture <template>` wraps `make_fixture` with a `git init` + seeded commit history. Used for grace-period tests that need real `git log` output.
- **Perf harness**: `bench.sh` wraps the audit with `/usr/bin/time -f '%e'` (GNU) or `gtime` (macOS Homebrew) to measure wall-clock seconds. Runs three times, reports median.

### Env overrides used

- `PDEQ_CONFIG_PATH` — path to the fixture's `pdeq.json`.
- `PDEQ_ALLOW_DRIFT=1` — enables escape-hatch tests.
- `PDEQ_CODE_MAPPING_GRACE=<n>` — overrides grace period for tests.
- `PDEQ_CODE_MAPPING_SKIP_INDEX_REWRITE=1` — tests that need to assert the un-rewritten state.
- `PDEQ_AUDIT_PROFILE=1` — enables phase-level timing output, used by perf tests.
- `NO_COLOR=1` — disables ANSI escapes for clean stderr comparison.

### Automation split

All test cases in this plan are `[auto]` — the feature has no judgment-based branches. The `[manual]` tag does not appear.

---

## Fixture Catalogue

| Template | Purpose | Contents |
|---|---|---|
| `clean-no-markers/` | Baseline: product spec with one FR, no code, no markers. | `pdeq.json`, `product/x.md` defining `FR-ex-one`, empty `engineering/apps/cli/`. |
| `one-marker-one-fr/` | Minimal success case. | As above plus `engineering/apps/cli/src/main.ts` with `// Implements: FR-ex-one`. |
| `multi-slug-marker/` | One marker cites two slugs. | `FR-ex-one` and `FR-ex-two` defined; one `// Implements: FR-ex-one, FR-ex-two` marker. |
| `orphan-marker/` | Marker cites undefined slug. | Product defines `FR-ex-one`; code has `// Implements: FR-ex-bogus`. |
| `retired-slug/` | Product spec previously defined `FR-ex-old` but current version doesn't. Code still has `// Implements: FR-ex-old`. Built via `make_git_fixture` — git-backed is required so the audit can distinguish retirement from a never-defined slug. | Git history: commit A added `FR-ex-old`; commit B removed it; HEAD is commit B. |
| `stale-code-map-path/` | Engineering Code Map references a missing file. | `engineering/cli/x.md` Code Map row points to `src/deleted.ts` which does not exist. |
| `uncovered-within-grace/` | FR defined recently, no marker yet. | Git history shows `FR-ex-one` introduced 2 commits ago; `PDEQ_CODE_MAPPING_GRACE=5`. |
| `uncovered-past-grace/` | FR defined long ago, no marker. | Git history shows `FR-ex-old-idea` introduced 8 commits ago; grace = 5. |
| `unimplemented-acknowledged/` | FR present in product, marked `unimplemented` in Code Map. | No marker in code; Code Map row has Status `unimplemented`. |
| `near-match-prose/` | File contains `FR-` prefix-only text and full slugs inside prose, not comments. | Comment `// discussing FR-ex-one here` should not count; narrative `The FR- prefix means…` ignored. |
| `nested-comment/` | `// Implements: FR-ex-one` inside `/* ... */` block comment. | Known-limitation test: expected to still count (documented behavior). |
| `missing-close-token/` | Markdown file with `<!-- Implements: FR-ex-one` but no `-->` on the same line. | Should be ignored. |
| `file-top-marker/` | Function-capable file with only a file-top marker, no inside-function markers. | Should warn (phase 5b). |
| `every-syntax-kind/` | One file per file-kind family, each with a valid marker. | `.ts`, `.py`, `.sh`, `.sql`, `.md`, `.css` — all cite the same FR. |
| `per-platform/` | Same FR implemented in two platform roots. | `engineering/apps/cli/src/a.ts:// Implements: FR-ex-one` + `engineering/apps/web/src/b.ts:// Implements: FR-ex-one`. |
| `index-drift-missing-rewrite/` | `index.md` exists with `Code` column header but empty cell for `FR-ex-one`, while `src/main.ts` has a valid marker at line 12. Drift is deterministic: audit should fill `engineering/apps/cli/src/main.ts:12` into the cell. | Used for default-mode auto-rewrite, `--check`-mode block, and skip-rewrite. |
| `index-stale-after-marker-removal/` | `index.md` lists a code location that no longer has a marker. | Used for `AC-code-mapping-index-drops-removed`. |
| `large-repo/` | 10,000-file synthetic tree for perf testing. Built by deterministic generator script (see `TC-code-mapping-audit-under-2s`). | 100 dirs × 100 files, round-robin `.ts/.py/.sh/.md`, exactly 50 markers at deterministic positions, product spec defines `FR-ex-large-0..49`. |
| `pdeq-self-host/` | `pdeq.json` with `selfHost: true`. Fixture mimics the pdeq repo's own layout. | Audit should scan into `scripts/` and `.claude/commands/`. |
| `consumer-excludes-pdeq/` | `pdeq.json` with `selfHost: false` (default). Fixture has a `.pdeq/` submodule-like dir with markers. | Audit must NOT scan `.pdeq/`. |
| `shallow-clone/` | Git fixture with `git clone --depth 1`. | Used to verify shallow-clone warning + full grace behavior. |
| `extension-exclude/` | `pdeq.json:codeMappingExclude` lists `legacy/**`. | `legacy/` contains an orphan marker that should be ignored. |
| `single-line-marker/` | Marker with a very long slug list split across two `//` comment lines. | Two separate `// Implements:` comments on consecutive lines, neither of which is a complete multi-slug marker on its own. Used by `TC-code-mapping-single-line-marker`. |
| `scope-on-function/` | Marker placed immediately above a function declaration (happy-path scope). | `.ts` file with `// Implements: FR-ex-one` on line 11, `export function doThing() {…}` on line 12. No other markers. |
| `scope-inside-short-body/` | Function declaration starts on line 1 (file has no preceding imports), marker sits inside the body on line 3. | `.tsx` file: line 1 `export function DiffLoadingState() {`, line 2 blank, line 3 `  // Implements: FR-ex-one`, line 4 `  return <div/>;`, line 5 `}`. No other markers. Verifies the audit does not warn just because the marker has a low absolute line number — it sits at or below `first_decl_line`, so position is correct. |
| `scope-no-decl-warns/` | Function-capable file with marker but no named-unit declaration anywhere. | `.ts` file: line 1 `// Implements: FR-ex-one`, line 2 `console.log("hello");` — top-level statement only, no `function`/`class`/component declaration. The scope rule does not apply (no declaration found = exempt). Used to pin the "no declaration → no warn" branch. |
| `scope-above-first-decl-warns/` | Marker on line 1, first declaration on line 5 — gap > 1, classic file-top antipattern. | `.ts` file: line 1 `// Implements: FR-ex-one`, lines 2–4 `import …` statements, line 5 `export function foo() { return 1; }`. Marker is more than one line above the first declaration → warn. |
| `implemented-status-no-marker/` | Code Map row marks `FR-ex-one` as `implemented` at `src/main.ts`, but the file has no marker. | Tests the implemented-without-marker drift case. |
| `grace-at-4/`, `grace-at-6/` | Git fixtures for `TC-code-mapping-grace-default-5`. | Identical setup except the product spec file has 4 vs 6 commits since `FR-ex-one` was added. |

---

## Coverage Matrix

| Requirement | Test Cases | Status |
|---|---|---|
| `FR-code-mapping-marker-presence` | `TC-code-mapping-marker-matches`, `TC-code-mapping-scan-finds-markers` | Not started |
| `FR-code-mapping-marker-multi` | `TC-code-mapping-multi-slug` | Not started |
| `FR-code-mapping-marker-scope` | `TC-code-mapping-scope-flagged`, `TC-code-mapping-scope-on-function-passes`, `TC-code-mapping-scope-inside-short-body`, `TC-code-mapping-scope-above-first-decl-warns`, `TC-code-mapping-scope-no-decl-no-warn` | Not started |
| `FR-code-mapping-marker-language` | `TC-code-mapping-syntax-table`, `TC-code-mapping-close-token-required` | Not started |
| `FR-code-mapping-marker-slug-reference` | `TC-code-mapping-orphan-blocks` | Not started |
| `FR-code-mapping-marker-retirement-blocks` | `TC-code-mapping-retirement-blocks` | Not started |
| `FR-code-mapping-planned-paths` | `TC-code-mapping-code-map-parses`, `TC-code-mapping-code-map-malformed`, `TC-code-mapping-implemented-status-no-marker` | Not started |
| `FR-code-mapping-planned-paths-living` | `TC-code-mapping-stale-path-blocks` | Not started |
| `FR-code-mapping-planned-paths-per-platform` | `TC-code-mapping-per-platform-index` | Not started |
| `FR-code-mapping-acknowledged-unimplemented` | `TC-code-mapping-unimplemented-exempt` | Not started |
| `FR-code-mapping-audit-scan` | `TC-code-mapping-scan-finds-markers`, `TC-code-mapping-grep-fallback-correctness` | Not started |
| `FR-code-mapping-audit-validates-slug` | `TC-code-mapping-orphan-blocks` | Not started |
| `FR-code-mapping-audit-validates-path` | `TC-code-mapping-stale-path-blocks` | Not started |
| `FR-code-mapping-audit-coverage` | `TC-code-mapping-coverage-reported` | Not started |
| `FR-code-mapping-audit-coverage-blocks` | `TC-code-mapping-grace-expires`, `TC-code-mapping-grace-default-5` | Not started |
| `FR-code-mapping-audit-coverage-grace` | `TC-code-mapping-grace-warns`, `TC-code-mapping-grace-expires`, `TC-code-mapping-shallow-clone-warns` | Not started |
| `FR-code-mapping-audit-escape-hatch` | `TC-code-mapping-override-demotes` | Not started |
| `FR-code-mapping-index-code-locations` | `TC-code-mapping-index-populated`, `TC-code-mapping-per-platform-index` | Not started |
| `FR-code-mapping-index-populated` | `TC-code-mapping-index-auto-stage`, `TC-code-mapping-skip-index-rewrite` | Not started |
| `FR-code-mapping-index-removes-stale` | `TC-code-mapping-index-removes-stale` | Not started |
| `NFR-code-mapping-audit-speed` | `TC-code-mapping-audit-under-2s` | Not started |
| `NFR-code-mapping-precision` | `TC-code-mapping-near-match-ignored`, `TC-code-mapping-nested-comment-known-limit` | Not started |
| `NFR-code-mapping-review-cost` | `TC-code-mapping-single-line-marker` | Not started |
| `NFR-code-mapping-determinism` | `TC-code-mapping-deterministic-two-runs` | Not started |
| `AC-code-mapping-orphan-marker-rejected` | `TC-code-mapping-orphan-blocks` | Not started |
| `AC-code-mapping-stale-planned-path-rejected` | `TC-code-mapping-stale-path-blocks` | Not started |
| `AC-code-mapping-uncovered-warns` | `TC-code-mapping-grace-warns` | Not started |
| `AC-code-mapping-uncovered-blocks` | `TC-code-mapping-grace-expires` | Not started |
| `AC-code-mapping-acknowledged-unimplemented` | `TC-code-mapping-unimplemented-exempt` | Not started |
| `AC-code-mapping-multi-slug-counted` | `TC-code-mapping-multi-slug` | Not started |
| `AC-code-mapping-marker-scope-enforced` | `TC-code-mapping-scope-flagged`, `TC-code-mapping-scope-inside-short-body`, `TC-code-mapping-scope-above-first-decl-warns`, `TC-code-mapping-scope-no-decl-no-warn` | Not started |
| `AC-code-mapping-marker-syntax-per-type` | `TC-code-mapping-syntax-table`, `TC-code-mapping-close-token-required` | Not started |
| `AC-code-mapping-planned-paths-living` | `TC-code-mapping-stale-path-blocks` | Not started |
| `AC-code-mapping-index-reflects-markers` | `TC-code-mapping-index-populated` | Not started |
| `AC-code-mapping-index-drops-removed` | `TC-code-mapping-index-removes-stale` | Not started |
| `AC-code-mapping-escape-hatch` | `TC-code-mapping-override-demotes`, `TC-code-mapping-override-reports-suppressed` | Not started |
| `AC-code-mapping-near-match-rejected` | `TC-code-mapping-near-match-ignored` | Not started |
| `AC-code-mapping-audit-speed` | `TC-code-mapping-audit-under-2s` | Not started |
| `AC-code-mapping-deterministic-output` | `TC-code-mapping-deterministic-two-runs` | Not started |
| `AC-code-mapping-retirement-blocks` | `TC-code-mapping-retirement-blocks` | Not started |

Additional infrastructure tests (not tied to a single requirement):

| Purpose | Test Case |
|---|---|
| Exclusion list respected | `TC-code-mapping-exclusion-respected` |
| `selfHost` flag scans framework files | `TC-code-mapping-selfhost-includes` |
| `selfHost: false` skips `.pdeq/` | `TC-code-mapping-consumer-excludes-pdeq` |

---

## Test Cases

### Marker Scan (phase 5)

Probes the core marker-detection logic in isolation from the rest of the audit.

#### Simple marker matches `TC-code-mapping-marker-matches`
- **Type**: Integration
- **Covers**: `FR-code-mapping-marker-presence`, `FR-code-mapping-audit-scan`
- **Fixture**: `one-marker-one-fr/` (marker placed at line 12 of `main.ts`, deterministic)
- **Steps**:
  1. Run `./scripts/audit-traceability.sh`.
  2. Call `assert_index_code_column FR-ex-one "engineering/apps/cli/src/main.ts:12"`.
- **Expected Result**: Exit 0. `assert_index_code_column` passes. (The helper does exact-match on the Code cell after trimming surrounding whitespace — no substring semantics.)

#### Multi-slug marker counts for all cited `TC-code-mapping-multi-slug`
- **Type**: Integration
- **Covers**: `FR-code-mapping-marker-multi`, `AC-code-mapping-multi-slug-counted`
- **Fixture**: `multi-slug-marker/`
- **Steps**:
  1. Run the audit.
- **Expected Result**: Exit 0. Both `FR-ex-one` and `FR-ex-two` have the same code location listed in `index.md`.

#### All syntax-table kinds matched `TC-code-mapping-syntax-table`
- **Type**: Integration
- **Covers**: `FR-code-mapping-marker-language`, `AC-code-mapping-marker-syntax-per-type`
- **Fixture**: `every-syntax-kind/` — contains exactly one file per documented file-kind family (one `.ts` for C-family, one `.py` for shell/scripting, one `.sh` also for shell/scripting, one `.sql` for SQL, one `.md` for HTML/Markdown, one `.css` for block-only).
- **Steps**:
  1. Run the audit.
- **Expected Result**: Exit 0. `FR-ex-one` Code column contains one `path:line` entry per file in the fixture, sorted by path (lexicographic). The test asserts count and sort order — not a literal "6" so that adding an extension to the fixture does not require this TC to change.

#### HTML/Markdown requires close token on same line `TC-code-mapping-close-token-required`
- **Type**: Unit (on `scan_markers`)
- **Covers**: `FR-code-mapping-marker-language`, `AC-code-mapping-marker-syntax-per-type`
- **Fixture**: `missing-close-token/` — git-backed via `make_git_fixture`, `FR-ex-one` introduced in HEAD so grace delta = 0 (full grace). Ensures grace state is deterministic for the expected result.
- **Steps**:
  1. Run `scan_markers`, assert zero matches for the incomplete marker.
  2. Run the audit end-to-end.
- **Expected Result**: Exit 0. `FR-ex-one` is reported as uncovered-within-grace (warning, not block).

#### Scan discovers markers across file types `TC-code-mapping-scan-finds-markers`
- **Type**: Unit (on `scan_markers`)
- **Covers**: `FR-code-mapping-audit-scan`, `FR-code-mapping-marker-presence`
- **Fixture**: `every-syntax-kind/`
- **Steps**:
  1. Run `scan_markers` directly.
  2. Capture stdout.
- **Expected Result**: Stdout has 6 tab-separated `slug<TAB>file<TAB>line` rows, sorted by file path.

#### Near-match prose ignored `TC-code-mapping-near-match-ignored`
- **Type**: Unit (on `scan_markers`)
- **Covers**: `NFR-code-mapping-precision`, `AC-code-mapping-near-match-rejected`
- **Fixture**: `near-match-prose/`
- **Steps**:
  1. Run `scan_markers`.
- **Expected Result**: Zero matches. Audit treats the FR as uncovered (warn within grace).

#### Nested comment is a known limitation `TC-code-mapping-nested-comment-known-limit`
- **Type**: Unit
- **Covers**: `NFR-code-mapping-precision` (documenting limitation)
- **Fixture**: `nested-comment/`
- **Steps**:
  1. Run `scan_markers`.
- **Expected Result**: The inner `// Implements:` IS counted. This test pins the documented limitation so future "fixes" don't accidentally regress the regex. A comment in the test notes: "This case is a known limitation documented in engineering spec §Known precision limitations."

#### Single-line grammar enforced `TC-code-mapping-single-line-marker`
- **Type**: Unit
- **Covers**: `NFR-code-mapping-review-cost`
- **Steps**:
  1. Construct a file with a marker that wraps to a second line (e.g., extremely long slug list split across two `//` comments).
  2. Run `scan_markers`.
- **Expected Result**: Each line matched independently; no marker spans two lines. If one line has no complete marker, no phantom matches are produced.

### Orphan and Retirement (phases 5–6)

#### Orphan marker blocks commit `TC-code-mapping-orphan-blocks`
- **Type**: Integration
- **Covers**: `FR-code-mapping-audit-validates-slug`, `FR-code-mapping-marker-slug-reference`, `AC-code-mapping-orphan-marker-rejected`
- **Fixture**: `orphan-marker/`
- **Steps**:
  1. Run the audit.
- **Expected Result**: Exit 1. Stderr contains `orphan marker at <file>:<line>: FR-ex-bogus not defined`.

#### Retired slug blocks, no grace `TC-code-mapping-retirement-blocks`
- **Type**: Integration
- **Covers**: `FR-code-mapping-marker-retirement-blocks`, `AC-code-mapping-retirement-blocks`
- **Fixture**: `retired-slug/`
- **Steps**:
  1. Run the audit.
- **Expected Result**: Exit 1. Stderr contains `retired slug FR-ex-old still cited at <file>:<line>`. Grace period is irrelevant — block is immediate.

### Scope Rule (phase 5b)

#### File-top marker in function-capable file warns `TC-code-mapping-scope-flagged`
- **Type**: Integration
- **Covers**: `FR-code-mapping-marker-scope`, `AC-code-mapping-marker-scope-enforced`
- **Fixture**: `file-top-marker/` — git-backed, FR recent (grace = full).
- **Steps**:
  1. Run the audit.
- **Expected Result**: Exit 0 (warn only). Stderr contains the substring `marker at file top`. The flagged marker is not counted toward coverage — the corresponding FR is treated as uncovered-within-grace.

#### Marker above a function counts (scope happy path) `TC-code-mapping-scope-on-function-passes`
- **Type**: Integration
- **Covers**: `FR-code-mapping-marker-scope`
- **Fixture**: new `scope-on-function/` — `.ts` file with a `// Implements: FR-ex-one` on the line immediately above `export function doThing() {…}`, no other markers.
- **Steps**:
  1. Run the audit.
- **Expected Result**: Exit 0. No scope warning. `FR-ex-one` Code column is populated.

#### Marker inside short function body does not warn `TC-code-mapping-scope-inside-short-body`
- **Type**: Integration
- **Covers**: `FR-code-mapping-marker-scope`, `AC-code-mapping-marker-scope-enforced`
- **Fixture**: new `scope-inside-short-body/` — `.tsx` file with `export function DiffLoadingState() {` on line 1 and `// Implements: FR-ex-one` on line 3 (inside the function body). No other markers. Pins the false-positive class fixed by the first-declaration-line algorithm: a marker on a low absolute line number that sits inside an implementing unit must not be flagged.
- **Steps**:
  1. Run the audit.
- **Expected Result**: Exit 0. Stderr does NOT contain `marker above first named unit` or any equivalent scope-warning substring. `FR-ex-one` Code column is populated with the marker's line.

#### Marker above first declaration warns `TC-code-mapping-scope-above-first-decl-warns`
- **Type**: Integration
- **Covers**: `FR-code-mapping-marker-scope`, `AC-code-mapping-marker-scope-enforced`
- **Fixture**: new `scope-above-first-decl-warns/` — `.ts` file with `// Implements: FR-ex-one` on line 1, three `import` lines on 2–4, and the first named-unit declaration on line 5. Gap from marker to first declaration is 4 (>1), so the marker precedes every named unit and is not paired with the first one.
- **Steps**:
  1. Run the audit (git fixture so grace covers the FR — failure here must come from scope, not coverage).
- **Expected Result**: Exit 0 (warn only). Stderr contains a scope-warning line citing `<file>:1` and the discovered first declaration line. The flagged marker is not counted toward coverage; `FR-ex-one` is treated as uncovered-within-grace.

#### Function-capable file with no declaration does not warn `TC-code-mapping-scope-no-decl-no-warn`
- **Type**: Integration
- **Covers**: `FR-code-mapping-marker-scope`, `AC-code-mapping-marker-scope-enforced`
- **Fixture**: new `scope-no-decl-warns/` — `.ts` file with `// Implements: FR-ex-one` on line 1 and only top-level statements (no `function`, `class`, or component declaration anywhere in the file). Verifies the "no declaration found = exempt" branch.
- **Steps**:
  1. Run the audit.
- **Expected Result**: Exit 0. Stderr does NOT contain a scope warning. `FR-ex-one` Code column is populated.

### Code Map (phase 7)

#### Code Map parses happy path `TC-code-mapping-code-map-parses`
- **Type**: Unit (on `parse_code_map`)
- **Covers**: `FR-code-mapping-planned-paths`
- **Fixture**: `one-marker-one-fr/` with a Code Map row marking `FR-ex-one` as `implemented`.
- **Steps**:
  1. Run `parse_code_map engineering/cli/x.md`.
- **Expected Result**: Stdout has one tab-separated row: `FR-ex-one<TAB>src/main.ts<TAB>implemented`.

#### Malformed Code Map row blocks `TC-code-mapping-code-map-malformed`
- **Type**: Unit
- **Covers**: `FR-code-mapping-planned-paths`
- **Fixture**: as above but Code Map has a row with `Status: foo` (not in vocabulary).
- **Steps**:
  1. Run the audit.
- **Expected Result**: Exit 1. Stderr cites the row number and `foo` as invalid Status vocabulary.

#### Implemented status with no marker is a code-map drift `TC-code-mapping-implemented-status-no-marker`
- **Type**: Integration
- **Covers**: `FR-code-mapping-planned-paths`, `FR-code-mapping-planned-paths-living`
- **Fixture**: new `implemented-status-no-marker/` — Code Map row marks `FR-ex-one` as `implemented` pointing at `src/main.ts`, but `src/main.ts` has no marker. File exists, so path check passes.
- **Steps**:
  1. Run the audit.
- **Expected Result**: Exit 1. Stderr contains `Code Map lists FR-ex-one as implemented but no marker cites it at src/main.ts`. Blocks unless `PDEQ_ALLOW_DRIFT=1`.

#### Stale Code Map path blocks `TC-code-mapping-stale-path-blocks`
- **Type**: Integration
- **Covers**: `FR-code-mapping-audit-validates-path`, `FR-code-mapping-planned-paths-living`, `AC-code-mapping-stale-planned-path-rejected`, `AC-code-mapping-planned-paths-living`
- **Fixture**: `stale-code-map-path/`
- **Steps**:
  1. Run the audit.
- **Expected Result**: Exit 1. Stderr cites `src/deleted.ts` as missing.

#### Unimplemented status exempts from coverage `TC-code-mapping-unimplemented-exempt`
- **Type**: Integration
- **Covers**: `FR-code-mapping-acknowledged-unimplemented`, `AC-code-mapping-acknowledged-unimplemented`
- **Fixture**: `unimplemented-acknowledged/`
- **Steps**:
  1. Run the audit. The FR is ancient (delta > grace) and has no markers.
- **Expected Result**: Exit 0. No warn, no block. The `FR-ex-one` row in `index.md` Code column is empty.

### Coverage and Grace (phase 8)

#### Coverage reported in stderr `TC-code-mapping-coverage-reported`
- **Type**: Integration
- **Covers**: `FR-code-mapping-audit-coverage`
- **Fixture**: `one-marker-one-fr/`
- **Steps**:
  1. Run the audit with `PDEQ_AUDIT_PROFILE=1` (which additionally enables per-FR coverage lines on stderr; open technical question: if engineering chooses a dedicated `--verbose` flag instead, update this TC to use it).
- **Expected Result**: Stderr contains the substring `FR-ex-one covered` for each covered FR. Uncovered FRs appear with `⚠` or `✗` markers already asserted by grace tests — this TC specifically asserts the positive coverage path.

#### Uncovered FR within grace warns `TC-code-mapping-grace-warns`
- **Type**: Integration (requires git fixture)
- **Covers**: `FR-code-mapping-audit-coverage-grace`, `AC-code-mapping-uncovered-warns`
- **Fixture**: `uncovered-within-grace/`
- **Steps**:
  1. Run the audit with `PDEQ_CODE_MAPPING_GRACE=5`.
- **Expected Result**: Exit 0. Stderr contains `⚠ FR-ex-one defined but has no marker (grace: 2/5 commits)`.

#### Uncovered FR past grace blocks `TC-code-mapping-grace-expires`
- **Type**: Integration (requires git fixture)
- **Covers**: `FR-code-mapping-audit-coverage-blocks`, `FR-code-mapping-audit-coverage-grace`, `AC-code-mapping-uncovered-blocks`
- **Fixture**: `uncovered-past-grace/`
- **Steps**:
  1. Run the audit with `PDEQ_CODE_MAPPING_GRACE=5`.
- **Expected Result**: Exit 1. Stderr contains the substrings `FR-ex-old-idea` and `grace expired`.

#### Grace default is 5 when env unset `TC-code-mapping-grace-default-5`
- **Type**: Integration (git fixture)
- **Covers**: `FR-code-mapping-audit-coverage-blocks`, `FR-code-mapping-audit-coverage-grace`
- **Fixture**: two variants — `grace-at-4/` (delta=4, no marker) and `grace-at-6/` (delta=6, no marker), both with `PDEQ_CODE_MAPPING_GRACE` unset.
- **Steps**:
  1. Run the audit in each fixture. Env var is unset.
- **Expected Result**: `grace-at-4/` exits 0 with warn. `grace-at-6/` exits 1 with block. Confirms the unconfigured default matches the engineering-spec commitment of 5.

#### Shallow clone warns and grants full grace `TC-code-mapping-shallow-clone-warns`
- **Type**: Integration (requires git fixture)
- **Covers**: `FR-code-mapping-audit-coverage-grace` (edge case)
- **Fixture**: `shallow-clone/`
- **Steps**:
  1. Run the audit in the shallow-clone fixture. The FR's intro commit is outside the shallow window.
- **Expected Result**: Exit 0. Stderr contains the substring `shallow clone`. FR is treated as `delta = 0`.

### Index Rewrite (phase 9)

#### Index Code column populated on audit run `TC-code-mapping-index-populated`
- **Type**: Integration
- **Covers**: `FR-code-mapping-index-code-locations`, `AC-code-mapping-index-reflects-markers`
- **Fixture**: `one-marker-one-fr/`
- **Steps**:
  1. Run the audit.
  2. Inspect `index.md`.
- **Expected Result**: `FR-ex-one` row has Code column `engineering/apps/cli/src/main.ts:N` where N is the marker's line.

#### Default mode auto-stages rewritten index `TC-code-mapping-index-auto-stage`
- **Type**: Integration (git fixture)
- **Covers**: `FR-code-mapping-index-populated`
- **Fixture**: `index-drift-missing-rewrite/` — starting `index.md` has the `Code` column present but empty for `FR-ex-one`, while `src/main.ts` contains a valid marker. Drift is deterministic: audit should write `engineering/apps/cli/src/main.ts:12` into the cell.
- **Steps**:
  1. Run the audit in default (pre-commit) mode.
  2. Run `git status` and assert `index.md` is both modified and staged.
  3. Run `git commit -m "test" --allow-empty-message` (or equivalent) to trigger trailer append.
  4. Run `git log -1 --format=%b`.
- **Expected Result**: After step 2, `git status` shows `index.md` staged. After step 4, trailer contains `pdeq-audit: index-code-column-updated`.

#### Skip-index-rewrite env bypasses phase 9 `TC-code-mapping-skip-index-rewrite`
- **Type**: Integration
- **Covers**: `FR-code-mapping-index-populated` (short-circuit path)
- **Fixture**: `index-drift-missing-rewrite/`
- **Steps**:
  1. Capture `index.md` before.
  2. Run the audit with `PDEQ_CODE_MAPPING_SKIP_INDEX_REWRITE=1`.
  3. Diff `index.md` before vs after.
- **Expected Result**: Exit 0. `index.md` is byte-identical to before — phase 9 is skipped entirely.

#### `--check` mode fails on index drift `TC-code-mapping-index-check-mode-fails`
- **Type**: Integration
- **Covers**: `FR-code-mapping-index-populated` (CI variant)
- **Fixture**: `index-drift-missing-rewrite/`
- **Steps**:
  1. Run the audit with `--check`.
- **Expected Result**: Exit 1. Stderr contains `index.md Code column out of date — run ./scripts/audit-traceability.sh`. `index.md` is NOT modified.

#### Removing a marker removes its index entry `TC-code-mapping-index-removes-stale`
- **Type**: Integration
- **Covers**: `FR-code-mapping-index-removes-stale`, `AC-code-mapping-index-drops-removed`
- **Fixture**: `index-stale-after-marker-removal/`
- **Steps**:
  1. Run the audit.
  2. Inspect `index.md`.
- **Expected Result**: The previously-listed code location no longer appears in `FR-ex-one`'s Code column.

#### Per-platform code locations listed in same row `TC-code-mapping-per-platform-index`
- **Type**: Integration
- **Covers**: `FR-code-mapping-planned-paths-per-platform`, `FR-code-mapping-index-code-locations`
- **Fixture**: `per-platform/`
- **Steps**:
  1. Run the audit.
  2. Inspect `FR-ex-one` Code column.
- **Expected Result**: Both `engineering/apps/cli/src/a.ts:N` and `engineering/apps/web/src/b.ts:M` appear comma-separated, sorted by path — platform is encoded in the path prefix, not a separate column.

### Escape Hatch

#### Override demotes all blocks to warnings `TC-code-mapping-override-demotes`
- **Type**: Integration
- **Covers**: `FR-code-mapping-audit-escape-hatch`, `AC-code-mapping-escape-hatch`
- **Fixture**: `orphan-marker/` with an additional stale-planned-path condition layered on.
- **Steps**:
  1. Run the audit with `PDEQ_ALLOW_DRIFT=1`.
- **Expected Result**: Exit 0. Both conditions are printed as warnings (not blocks). Index is rewritten in place.

#### Override report names suppressed conditions `TC-code-mapping-override-reports-suppressed`
- **Type**: Integration
- **Covers**: `AC-code-mapping-escape-hatch`
- **Fixture**: as above.
- **Steps**:
  1. Run the audit with `PDEQ_ALLOW_DRIFT=1`, capture stderr.
- **Expected Result**: Stderr contains the substring `PDEQ_ALLOW_DRIFT=1` and at least one per-condition line naming the suppressed class (orphan / stale path / retirement / uncovered). Exact wording is engineering's call; assertions use substring matching on class tokens rather than full-line exact match to avoid brittleness.

### Performance and Determinism

#### Audit completes in under 2 seconds `TC-code-mapping-audit-under-2s`
- **Type**: Performance
- **Covers**: `NFR-code-mapping-audit-speed`, `AC-code-mapping-audit-speed`
- **Fixture**: `large-repo/` — 10k-file synthetic tree built by `tests/fixtures/gen-large-repo.sh`: creates 100 directories × 100 files each, mix of `.ts/.py/.sh/.md` in round-robin to exercise all syntax-table kinds, seeds exactly 50 `// Implements: FR-ex-large-<n>` markers at deterministic locations (every 200th file gets a marker). Product spec in the fixture defines `FR-ex-large-0` through `FR-ex-large-49`. Fixture is fully deterministic across runs (no randomness; file content is the file's index-derived string).
- **Steps**:
  1. Run `bench.sh ./scripts/audit-traceability.sh` in the fixture. Repeat 3 times.
- **Expected Result**: Median wall-clock time ≤ 2.0 seconds. `rg` is required for this test — in environments without `rg`, the test logs an informational skip line and does not count as a pass. The grep-fallback correctness test (below) covers correctness separately; perf with the grep fallback is not an enforced target.

#### Grep fallback produces identical results `TC-code-mapping-grep-fallback-correctness`
- **Type**: Integration
- **Covers**: `FR-code-mapping-audit-scan` (grep-fallback path)
- **Fixture**: `every-syntax-kind/` — run twice: once with `rg` on `PATH`, once with `rg` shadowed (`PATH=/tmp/empty` or `alias rg=false`).
- **Steps**:
  1. Run the audit with `rg` available, capture `index.md` and stderr.
  2. Run the audit with `rg` unavailable, capture same.
- **Expected Result**: Both runs produce byte-identical `index.md`. Both stderr outputs contain the same orphan/coverage messages modulo the additional `ripgrep not found` warning in the second run.

#### Two runs produce identical output `TC-code-mapping-deterministic-two-runs`
- **Type**: Integration
- **Covers**: `NFR-code-mapping-determinism`, `AC-code-mapping-deterministic-output`
- **Fixture**: `one-marker-one-fr/`
- **Steps**:
  1. Run the audit, capture stderr to `run1.txt` and `index.md` to `index1.md`.
  2. Run it again to `run2.txt`, `index2.md`.
- **Expected Result**: `diff run1.txt run2.txt` is empty. `diff index1.md index2.md` is empty.

### Infrastructure

#### Exclusion list respected `TC-code-mapping-exclusion-respected`
- **Type**: Integration
- **Covers**: infrastructure
- **Fixture**: `extension-exclude/`
- **Steps**:
  1. Run the audit. `legacy/` contains an orphan marker.
- **Expected Result**: Exit 0. The orphan marker in `legacy/` is not reported because the path is excluded via `pdeq.json:codeMappingExclude`.

#### `selfHost: true` scans framework files `TC-code-mapping-selfhost-includes`
- **Type**: Integration
- **Covers**: infrastructure (engineering §Exclusions)
- **Fixture**: `pdeq-self-host/`
- **Steps**:
  1. Run the audit. A marker lives at `scripts/audit-traceability.sh:some-line`.
- **Expected Result**: The marker is discovered and listed in `index.md`'s Code column.

#### `selfHost: false` skips `.pdeq/` `TC-code-mapping-consumer-excludes-pdeq`
- **Type**: Integration
- **Covers**: infrastructure
- **Fixture**: `consumer-excludes-pdeq/`
- **Steps**:
  1. Run the audit. `.pdeq/some-file.sh` contains a marker citing a slug that does not exist in the consumer's product spec.
- **Expected Result**: Exit 0. The `.pdeq/` marker is not discovered; no orphan error.

---

## Edge Cases & Error Scenarios

### Marker in a file the syntax table doesn't cover

- **Trigger**: Author adds a marker in `.rb` before the syntax table lists Ruby.
- **Expected behavior**: Marker is ignored. The FR is treated as uncovered. Author sees the coverage warning, notices the marker is not counted, updates the syntax table.
- **Test case**: Covered implicitly by `TC-code-mapping-syntax-table` — if a file kind is absent from the fixture, its markers don't count.

### Marker inside a string literal

- **Trigger**: Source code contains `const s = "// Implements: FR-ex-one";`.
- **Expected behavior**: Documented as a known limitation (engineering spec §Known precision limitations). The audit will count it. No dedicated test case — documenting the behavior in the spec is enough. If the limitation becomes a real-world problem, add `TC-code-mapping-string-literal-known-limit`.

### Empty product spec

- **Trigger**: Project has `pdeq.json`, `index.md`, but `product/` is empty.
- **Expected behavior**: Phases 5–9 run with an empty slug set. Any marker is treated as an orphan. This is correct behavior.
- **Test case**: Not in v1 scope — the existing `audit-traceability.sh` already handles empty product/, and the new phases inherit the same guard.

### Binary files in repo

- **Trigger**: `.png`, `.jpg`, `.zip` files in the tree.
- **Expected behavior**: Ripgrep's binary detection skips them by default. Grep fallback uses `--binary-files=without-match`. Either way, no false matches.

## Regression Considerations

- **Existing audit phases 1–4** must keep passing exactly as before. The harness runs the full audit on the current pdeq repo before and after the extension lands; output must differ only by the addition of phase-5–9 lines and the Code column in `index.md`.
- **Migrations pre-commit gate (`audit-migrations.sh`)** is unrelated but shares the commit-msg hook chain. A smoke test runs both hooks in sequence on a realistic fixture to confirm no interference.
- **`/kickoff` flow** — after PDEQ-srrrdnzx lands, `/kickoff` emits a Code Map section. Regression: run `/kickoff` on a throwaway feature, audit, confirm green.
