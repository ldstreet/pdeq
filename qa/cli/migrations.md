---
product-hash: 7e42c8798456b4865d3587297815795edd1881abf503cac093811f6011b752a7
product-slugs: [AC-migrations-absent-reported, AC-migrations-dry-run-accurate, AC-migrations-gate-allows-nonbreaking, AC-migrations-gate-blocks, AC-migrations-idempotent-rerun, AC-migrations-lineage-refused, AC-migrations-missing-file-refused, AC-migrations-no-bump-on-failure, AC-migrations-nonbreaking-advance, AC-migrations-noop-when-current, AC-migrations-ordered-apply, AC-migrations-scope-respected, AC-migrations-self-migration-runs, AC-migrations-semantic-context, AC-migrations-update-bump-failure, AC-migrations-update-dry-run, AC-migrations-update-end-to-end, AC-migrations-update-in-session, AC-migrations-update-noop, FR-migrations-absent-version, FR-migrations-atomic-bump, FR-migrations-author-written, FR-migrations-bootstrap-chain, FR-migrations-breaking-gate, FR-migrations-dry-run, FR-migrations-explicit-run, FR-migrations-failure-report, FR-migrations-idempotent, FR-migrations-lineage-integrity, FR-migrations-mechanical-block, FR-migrations-missing-file-refused, FR-migrations-no-false-positive, FR-migrations-nonbreaking-advance, FR-migrations-noop-when-current, FR-migrations-one-per-version, FR-migrations-order-within, FR-migrations-ordered, FR-migrations-ordered-application, FR-migrations-pending-detection, FR-migrations-recoverable-partial, FR-migrations-scoped-writes, FR-migrations-self-migration, FR-migrations-semantic-block, FR-migrations-unknown-version, FR-migrations-update-bump-failure, FR-migrations-update-bumps-pin, FR-migrations-update-chains, FR-migrations-update-command, FR-migrations-update-dry-run, FR-migrations-update-in-session, FR-migrations-update-noop, FR-migrations-version-bump, FR-migrations-version-field, FR-migrations-version-readable, NFR-migrations-determinism, NFR-migrations-enforcement-precision, NFR-migrations-idempotency, NFR-migrations-scope-minimalism]
---
# Migrations — CLI Test Plan

> Based on requirements in `../../product/migrations.md`
> Based on design in `../../design/cli/migrations.md`
> Based on engineering in `../../engineering/cli/migrations.md`

## What We're Testing

This plan verifies the migrations feature on the CLI platform end-to-end: version-state detection, migration execution (single, multi-step, dry-run, idempotent), failure and partial-state handling, atomic version bump semantics, scope enforcement, the pdeq-repo pre-commit gate, semantic-block context handoff, and pdeq's own self-migration. The test surface is shell-based: fixtures are temporary directories seeded with a known `pdeqVersion` and a mock migrations directory, exercised through `/pdeq-migrate` (and the equivalent underlying script) with env overrides (`PDEQ_MIGRATIONS_DIR`, `PDEQ_CONFIG_PATH`) to isolate each run from the real repository.

## Test Strategy

### Tooling

- **Primary harness**: plain POSIX shell test scripts under `engineering/apps/cli/tests/migrations/`. Plain shell keeps dependencies minimal and matches existing pdeq style (`scripts/init.sh`, `scripts/audit-traceability.sh`). Each test script sets up a fixture in a `mktemp -d` directory, runs the command, asserts on exit code / stdout / stderr / filesystem state, and cleans up on exit via `trap`.
- **Assertion helpers**: a small `tests/lib/assert.sh` provides `assert_eq`, `assert_contains`, `assert_file_exists`, `assert_file_absent`, `assert_version_recorded`, `assert_tree_matches`.
- **Color-safe output comparison**: tests run with `NO_COLOR=1` (or the pdeq-equivalent env override) so glyph assertions don't have to account for ANSI escapes. A separate small set of rendering tests runs *with* color enabled to confirm glyph choice (`✓`/`~`/`✗`/`•`).
- **Semantic-block tests**: the semantic transform normally hands a prompt to a live agent. Automated tests substitute a **canned agent script** (path injected via `PDEQ_SEMANTIC_AGENT`) that returns a deterministic transformation given its input files. Tests that require observing real agent judgment are marked `[manual]`.
- **Pre-commit gate tests**: use `git init` in a `mktemp -d`, install the gate hook, stage synthetic changes, run `git commit`, and assert on exit code and hook output. Fully automated.

### Automation split

- `[auto]` — fully automated shell test, no human required.
- `[manual]` — requires a human and/or a live agent to observe judgment-based behavior or release-day flow.
- `[semi-auto]` — automated using the canned-agent stub; requires a live agent run at least once per release to confirm stub realism.

### Env overrides used

- `PDEQ_CONFIG_PATH` — path to the fixture's `pdeq.json`.
- `PDEQ_MIGRATIONS_DIR` — path to the fixture's mock `.pdeq/migrations/` directory.
- `PDEQ_SPECS_ROOT` — path to the fixture's minimal specs root.
- `PDEQ_SEMANTIC_AGENT` — path to a stub agent executable for semantic-block tests.
- `PDEQ_LINEAGE_FILE` — path to a file listing versions that belong to the pinned lineage (used to fake lineage validation deterministically).
- `NO_COLOR=1` — disables color for easier assertion.

---

## Fixture Catalogue

Every fixture is created by a helper `make_fixture <template>` which copies a template from `tests/fixtures/` into a fresh `mktemp -d` and returns its path. All paths in the sections below are relative to that root.

| Template | Purpose | Contents |
|---|---|---|
| `baseline-at-latest/` | Recorded == pinned. Used for no-op tests. | `pdeq.json` with `pdeqVersion: 0.4.0`, specs root with a couple of clean specs, migrations dir with `0.4.0.md` already "applied". |
| `baseline-one-behind/` | Single pending migration. | `pdeq.json` at `0.3.2`, pinned `0.4.0`, one migration file `0.4.0.md` (mechanical-only). |
| `baseline-multi-behind/` | Multiple pending migrations. | `pdeq.json` at `0.2.1`, pinned `0.4.0`, three migration files `0.3.0.md`, `0.3.2.md`, `0.4.0.md`. Mixed mechanical/semantic. |
| `absent-version/` | `pdeq.json` has no `pdeqVersion` field. | Config is pre-migrations; specs root has one spec. |
| `newer-than-pinned/` | Recorded > pinned. | `pdeqVersion: 0.5.0`, pinned `0.4.0`. |
| `foreign-lineage/` | Recorded version not in pinned lineage. | `pdeqVersion: 0.4.0` but `PDEQ_LINEAGE_FILE` does not list `0.4.0`. |
| `noop-fixture/` | Migration file whose mechanical script is a guaranteed no-op (idempotent by trivial construction). | `0.9.0.md` with mechanical that matches no files. |
| `mechanical-only/` | Migration file with only a `## Mechanical` block. | Rewrites slugs in `product/auth.md` using a lookup table. |
| `with-semantic/` | Migration file with both mechanical and semantic blocks. | Semantic block lists globs under `design/**/*.md` and invokes the canned agent. |
| `semantic-only/` | Migration file with only `## Semantic`. | Tests the `~ mechanical no mechanical block` line. |
| `failing-mechanical/` | Migration whose mechanical script exits non-zero mid-run. | Script writes one file then fails; used to test atomic bump + recoverable partial. |
| `failing-semantic/` | Migration whose semantic stub returns an error. | Mechanical succeeds, semantic fails. |
| `out-of-scope-write/` | Migration whose mechanical script attempts to write outside specs root + config. | Attempts to write `/tmp/nope.txt` (or a sibling directory of the fixture) — should be caught and fail the migration. |
| `broad-scope-declared/` | Migration with explicit `scope:` frontmatter declaring a broader glob. | Writes to an explicitly-declared extra path, should succeed. |
| `unknown-format/` | Migration file with an unrecognized frontmatter or missing required section. | Used to test authoring-time error reporting. |
| `pdeq-repo-like/` | Mimics pdeq repo layout for gate tests: git-initialized, framework files present, `pdeq.schema.json`. | Plus the hook script. |
| `self-migration/` | Mimics pdeq repo at release time: recorded `0.3.2`, pinned `0.4.0`, one self-migration file. | Uses same code path as consumer `/pdeq-migrate`. |
| `nonbreaking-advance/` | Recorded `0.3.0`, pinned `0.3.2`. Lineage file marks intermediate releases non-breaking. Migrations dir is empty for that window. | Used for `TC-migrations-nonbreaking-advance`. |
| `breaking-missing-file/` | Recorded `0.3.2`, pinned `0.4.0`. Lineage file marks `0.4.0` as breaking but `PDEQ_MIGRATIONS_DIR` has no `0.4.0.md`. | Used for `TC-migrations-missing-file-refused`. |
| `update-pin-behind/` | Consumer-shaped repo: working tree has `pdeq.json` at recorded `0.2.1` and a `.pdeq/` submodule pinned to `0.2.1`. A bare local "remote" git repo (used as the submodule's `origin`) has additional commits/tags advancing to `0.4.0`, including breaking versions `0.3.0`, `0.3.2`, `0.4.0` with matching migration files. `.pdeq/VERSION` post-bump reads `0.4.0`. | Used for `TC-migrations-update-happy`. |
| `update-pin-at-latest/` | Consumer repo with submodule already at the latest available SHA on its tracked line; bare remote has no newer commits. `pdeq.json` recorded `0.4.0`, pinned `0.4.0`. | Used for `TC-migrations-update-noop-current`. |
| `update-nonbreaking-window/` | Consumer repo at `0.3.0`; bare remote advances pinned to `0.3.2` across only non-breaking versions. `PDEQ_LINEAGE_FILE` does NOT mark intermediate versions as breaking; submodule's `migrations/` dir is empty for the `(0.3.0, 0.3.2]` window. | Used for `TC-migrations-update-nonbreaking-only`. |
| `update-new-command-shipped/` | Consumer repo at `0.3.2`; bare remote advances to `0.4.0` and the post-bump submodule contains a new file `.pdeq/.claude/commands/update-fixture-test.md` not present in the pre-bump submodule. Migration `0.4.0.md` is mechanical-only and trivial. | Used for `TC-migrations-update-in-session-new-command`. |
| `update-bump-broken-remote/` | Consumer repo at `0.3.2`; submodule's `origin` URL points at a path that does not exist (or returns non-zero on fetch). `pdeq.json` recorded `0.3.2`. | Used for `TC-migrations-update-bump-failure-network`. |
| `update-self-host/` | Mimics the pdeq repo itself: git-initialized, root-level `VERSION` file present, `.pdeq/` submodule whose configured remote URL matches the fixture repo's own `origin` (per the self-host detection rule in engineering §Self-host context). | Used for `TC-migrations-update-self-host-refuses`. |
| `update-deleted-command/` | Consumer repo at `0.3.2` with a symlink at `<git-root>/.claude/commands/old.md → ../../.pdeq/.claude/commands/old.md`. Bare remote advances to `0.4.0`; in the post-bump submodule, `.claude/commands/old.md` no longer exists. Migration `0.4.0.md` is a trivial mechanical no-op. | Used for `TC-migrations-update-symlink-prune`. |

### Canned semantic agent stubs

Stored in `tests/fixtures/agents/`:

| Stub | Behavior |
|---|---|
| `deterministic-rewrite.sh` | Takes file paths on stdin, rewrites each according to a hardcoded rule, prints one `file updated` line per change and a final `updated N of M files`. |
| `noop-already-conformant.sh` | Reads files, prints nothing (silence = conformant), emits `updated 0 of M files`. Used for idempotent re-run assertions. |
| `failing.sh` | Exits non-zero with a canned error message. Used for semantic-failure tests. |
| `snooping.sh` | Attempts to read files outside the declared `### Files` globs and reports what it saw. Used to test scope-confinement of the agent's file context. |

---

## Coverage Matrix

| Requirement | Test Cases | Status |
|---|---|---|
| `FR-migrations-version-field` | `TC-migrations-version-field-read`, `TC-migrations-absent-version-state` | Not started |
| `FR-migrations-version-readable` | `TC-migrations-status-line-printed`, `TC-migrations-status-line-at-latest` | Not started |
| `FR-migrations-absent-version` | `TC-migrations-absent-version-state`, `TC-migrations-absent-version-no-writes` | Not started |
| `FR-migrations-one-per-version` | `TC-migrations-one-file-per-version`, `TC-migrations-non-breaking-no-file` | Not started |
| `FR-migrations-ordered` | `TC-migrations-multi-order`, `TC-migrations-ordered-pending-list` | Not started |
| `FR-migrations-mechanical-block` | `TC-migrations-mechanical-runs`, `TC-migrations-mechanical-absent-marker` | Not started |
| `FR-migrations-semantic-block` | `TC-migrations-semantic-runs`, `TC-migrations-semantic-absent-marker` | Not started |
| `FR-migrations-order-within` | `TC-migrations-mechanical-before-semantic` | Not started |
| `FR-migrations-author-written` | `TC-migrations-file-required` | Not started |
| `FR-migrations-explicit-run` | `TC-migrations-no-auto-trigger` | Not started |
| `FR-migrations-pending-detection` | `TC-migrations-pending-detection-single`, `TC-migrations-pending-detection-multi`, `TC-migrations-pending-detection-none` | Not started |
| `FR-migrations-ordered-application` | `TC-migrations-multi-order`, `TC-migrations-no-skip-gaps` | Not started |
| `FR-migrations-version-bump` | `TC-migrations-version-bump-success` | Not started |
| `FR-migrations-noop-when-current` | `TC-migrations-noop-at-latest`, `TC-migrations-noop-no-writes` | Not started |
| `FR-migrations-dry-run` | `TC-migrations-dry-run-no-writes`, `TC-migrations-dry-run-output-shape`, `TC-migrations-dry-run-semantic-skipped` | Not started |
| `FR-migrations-idempotent` | `TC-migrations-rerun-is-noop`, `TC-migrations-mechanical-idempotent`, `TC-migrations-semantic-idempotent` | Not started |
| `FR-migrations-scoped-writes` | `TC-migrations-scope-default-enforced`, `TC-migrations-scope-broader-declared`, `TC-migrations-scope-semantic-context-confined` | Not started |
| `FR-migrations-breaking-gate` | `TC-migrations-gate-blocks-missing-file`, `TC-migrations-gate-passes-with-file` | Not started |
| `FR-migrations-no-false-positive` | `TC-migrations-gate-docs-only`, `TC-migrations-gate-nonframework`, `TC-migrations-gate-trailer-override` | Not started |
| `FR-migrations-lineage-integrity` | `TC-migrations-foreign-lineage-refused` | Not started |
| `FR-migrations-bootstrap-chain` | `TC-migrations-self-migration-same-command` | Not started |
| `FR-migrations-self-migration` | `TC-migrations-self-migration-advances-version`, `TC-migrations-self-migration-same-command` | Not started |
| `FR-migrations-atomic-bump` | `TC-migrations-atomic-bump-on-mechanical-fail`, `TC-migrations-atomic-bump-on-semantic-fail` | Not started |
| `FR-migrations-failure-report` | `TC-migrations-failure-report-names-migration`, `TC-migrations-failure-report-names-block`, `TC-migrations-failure-report-recovery-steps` | Not started |
| `FR-migrations-recoverable-partial` | `TC-migrations-partial-recoverable-state`, `TC-migrations-resume-after-fix` | Not started |
| `FR-migrations-unknown-version` | `TC-migrations-newer-recorded-refused`, `TC-migrations-foreign-lineage-refused` | Not started |
| `NFR-migrations-idempotency` | `TC-migrations-rerun-is-noop`, `TC-migrations-mechanical-idempotent`, `TC-migrations-semantic-idempotent` | Not started |
| `NFR-migrations-determinism` | `TC-migrations-determinism-two-runs` | Not started |
| `NFR-migrations-scope-minimalism` | `TC-migrations-untouched-files-unchanged`, `TC-migrations-dry-run-file-list-exhaustive` | Not started |
| `NFR-migrations-enforcement-precision` | `TC-migrations-gate-docs-only`, `TC-migrations-gate-nonframework` | Not started |
| `AC-migrations-noop-when-current` | `TC-migrations-noop-at-latest`, `TC-migrations-noop-no-writes` | Not started |
| `AC-migrations-ordered-apply` | `TC-migrations-multi-order`, `TC-migrations-version-bump-success` | Not started |
| `AC-migrations-no-bump-on-failure` | `TC-migrations-atomic-bump-on-mechanical-fail`, `TC-migrations-atomic-bump-on-semantic-fail` | Not started |
| `AC-migrations-dry-run-accurate` | `TC-migrations-dry-run-matches-real-run`, `TC-migrations-dry-run-no-writes` | Not started |
| `AC-migrations-gate-blocks` | `TC-migrations-gate-blocks-missing-file` | Not started |
| `AC-migrations-gate-allows-nonbreaking` | `TC-migrations-gate-docs-only`, `TC-migrations-gate-nonframework`, `TC-migrations-gate-trailer-override` | Not started |
| `AC-migrations-semantic-context` | `TC-migrations-semantic-context-receives-files`, `TC-migrations-scope-semantic-context-confined` | Not started |
| `AC-migrations-idempotent-rerun` | `TC-migrations-rerun-is-noop` | Not started |
| `AC-migrations-absent-reported` | `TC-migrations-absent-version-state`, `TC-migrations-absent-version-no-writes` | Not started |
| `AC-migrations-lineage-refused` | `TC-migrations-newer-recorded-refused`, `TC-migrations-foreign-lineage-refused` | Not started |
| `AC-migrations-scope-respected` | `TC-migrations-scope-default-enforced`, `TC-migrations-scope-broader-declared` | Not started |
| `AC-migrations-self-migration-runs` | `TC-migrations-self-migration-advances-version` | Not started |
| `FR-migrations-nonbreaking-advance` | `TC-migrations-nonbreaking-advance` | Not started |
| `AC-migrations-nonbreaking-advance` | `TC-migrations-nonbreaking-advance` | Not started |
| `FR-migrations-missing-file-refused` | `TC-migrations-missing-file-refused` | Not started |
| `AC-migrations-missing-file-refused` | `TC-migrations-missing-file-refused` | Not started |
| `FR-migrations-update-command` | `TC-migrations-update-happy`, `TC-migrations-update-noop-current`, `TC-migrations-update-self-host-refuses` | Not started |
| `FR-migrations-update-bumps-pin` | `TC-migrations-update-happy`, `TC-migrations-update-nonbreaking-only` | Not started |
| `FR-migrations-update-chains` | `TC-migrations-update-happy`, `TC-migrations-update-nonbreaking-only` | Not started |
| `FR-migrations-update-in-session` | `TC-migrations-update-in-session-new-command`, `TC-migrations-update-symlink-prune` | Not started |
| `FR-migrations-update-noop` | `TC-migrations-update-noop-current` | Not started |
| `FR-migrations-update-bump-failure` | `TC-migrations-update-bump-failure-network` | Not started |
| `FR-migrations-update-dry-run` | `TC-migrations-update-dry-run` | Not started |
| `AC-migrations-update-end-to-end` | `TC-migrations-update-happy`, `TC-migrations-update-nonbreaking-only` | Not started |
| `AC-migrations-update-noop` | `TC-migrations-update-noop-current` | Not started |
| `AC-migrations-update-in-session` | `TC-migrations-update-in-session-new-command` | Not started |
| `AC-migrations-update-bump-failure` | `TC-migrations-update-bump-failure-network` | Not started |
| `AC-migrations-update-dry-run` | `TC-migrations-update-dry-run` | Not started |

Every AC has at least one TC. Every FR and NFR is also covered.

---

## Test Cases

Test cases are grouped by area. Each case tags `[auto]`, `[semi-auto]`, or `[manual]`.

### Group 1 — Version State

Verifies the `/pdeq-migrate` command's reading of and response to the four version states: at-latest, pending (one or more behind), absent, and foreign/newer.

#### Status line always printed `TC-migrations-status-line-printed` `[auto]`

- **Type**: Integration
- **Covers**: `FR-migrations-version-readable`
- **Preconditions**: `baseline-one-behind/` fixture.
- **Steps**:
  1. `PDEQ_CONFIG_PATH=<fixture>/pdeq.json PDEQ_MIGRATIONS_DIR=<fixture>/.pdeq/migrations /pdeq-migrate --dry-run`.
  2. Capture stdout.
- **Expected Result**: First non-empty line of stdout matches the pattern `^pdeq: recorded 0\.3\.2 → pinned 0\.4\.0`. Exit 0.

#### Status line at latest `TC-migrations-status-line-at-latest` `[auto]`

- **Type**: Integration
- **Covers**: `FR-migrations-version-readable`
- **Preconditions**: `baseline-at-latest/` fixture (recorded == pinned == 0.4.0).
- **Steps**: Run `/pdeq-migrate`.
- **Expected Result**: First line is `pdeq: recorded 0.4.0 → pinned 0.4.0`. (No-op body follows — asserted separately.)

#### Version field read from config `TC-migrations-version-field-read` `[auto]`

- **Type**: Unit
- **Covers**: `FR-migrations-version-field`, `FR-migrations-version-readable`
- **Preconditions**: `baseline-one-behind/` fixture with `pdeqVersion: 0.3.2` in `pdeq.json`.
- **Steps**: Run `/pdeq-migrate --dry-run`; grep for `recorded 0.3.2` in output.
- **Expected Result**: Output confirms the version was read from the config file. If the config is mutated to `0.2.1` and rerun, the output says `recorded 0.2.1`.

#### Absent version reported `TC-migrations-absent-version-state` `[auto]`

- **Type**: Integration
- **Covers**: `FR-migrations-absent-version`, `AC-migrations-absent-reported`, `FR-migrations-version-field`
- **Preconditions**: `absent-version/` fixture — `pdeq.json` has no `pdeqVersion` key.
- **Steps**: Run `/pdeq-migrate`.
- **Expected Result**:
  - Exit non-zero.
  - Stdout contains `pdeq: recorded (none) → pinned 0.4.0`.
  - Stdout contains `✗ No pdeq version is recorded for this project.`
  - Stdout contains a "What to do" section with the three numbered steps from design Surface 6.
  - No files are modified (diff `ls -lR` before and after).

#### Absent version performs no writes `TC-migrations-absent-version-no-writes` `[auto]`

- **Type**: Integration
- **Covers**: `FR-migrations-absent-version`, `AC-migrations-absent-reported`
- **Preconditions**: `absent-version/` fixture, snapshot specs root file-tree hash before run.
- **Steps**: Run `/pdeq-migrate`; hash the specs root file tree after.
- **Expected Result**: Pre-run and post-run hashes are identical.

#### Newer recorded than pinned refused `TC-migrations-newer-recorded-refused` `[auto]`

- **Type**: Integration
- **Covers**: `FR-migrations-unknown-version`, `AC-migrations-lineage-refused`
- **Preconditions**: `newer-than-pinned/` fixture.
- **Steps**: Run `/pdeq-migrate`.
- **Expected Result**:
  - Exit non-zero.
  - Output contains `✗ Recorded version (0.5.0) is newer than the pinned pdeq submodule (0.4.0).`
  - Output contains recovery guidance matching Surface 6.
  - No files modified.

#### Foreign lineage refused `TC-migrations-foreign-lineage-refused` `[auto]`

- **Type**: Integration
- **Covers**: `FR-migrations-lineage-integrity`, `FR-migrations-unknown-version`, `AC-migrations-lineage-refused`
- **Preconditions**: `foreign-lineage/` fixture. `PDEQ_LINEAGE_FILE` does NOT include `0.4.0`.
- **Steps**: Run `/pdeq-migrate`.
- **Expected Result**:
  - Exit non-zero.
  - Output contains `✗ Recorded pdeq version 0.4.0 does not match the pinned pdeq lineage.`
  - Output mentions `.gitmodules` in the recovery block.
  - No files modified.

#### Non-breaking advance applies without running migrations `TC-migrations-nonbreaking-advance` `[auto]`

- **Type**: Integration
- **Covers**: `FR-migrations-nonbreaking-advance`, `AC-migrations-nonbreaking-advance`
- **Preconditions**: Fixture recorded `0.3.0`, pinned `0.3.2`. `PDEQ_MIGRATIONS_DIR` contains NO `.md` files in the `(0.3.0, 0.3.2]` window. `PDEQ_LINEAGE_FILE` does NOT mark `0.3.1`/`0.3.2` as breaking.
- **Steps**: Run `/pdeq-migrate`.
- **Expected Result**:
  - Exit 0.
  - Output contains `~ No migrations pending. Advancing recorded version 0.3.0 → 0.3.2 (non-breaking releases).`
  - Final line: `✓ pdeq: recorded 0.3.0 → 0.3.2` followed by `No migrations ran.`
  - `pdeqVersion` in `pdeq.json` is now `0.3.2`.
  - No `.md` file in the specs tree was modified (hash compare).

#### Missing migration file for breaking pinned version refused `TC-migrations-missing-file-refused` `[auto]`

- **Type**: Integration
- **Covers**: `FR-migrations-missing-file-refused`, `AC-migrations-missing-file-refused`
- **Preconditions**: Fixture recorded `0.3.2`, pinned `0.4.0`. `PDEQ_LINEAGE_FILE` declares `0.4.0` as breaking. `PDEQ_MIGRATIONS_DIR` does NOT contain `0.4.0.md`.
- **Steps**: Run `/pdeq-migrate`.
- **Expected Result**:
  - Exit non-zero.
  - Output contains `✗ Missing migration file for 0.4.0.`
  - Output names the expected path (`.pdeq/migrations/0.4.0.md` in consumer context, since the runner uses `$PDEQ_MIGRATIONS_DIR`).
  - `pdeqVersion` is unchanged at `0.3.2`.
  - No files in the specs tree modified.

### Group 2 — Migration Runs

Verifies end-to-end execution: single migration, multi-step chain, dry-run preview, and idempotency on re-run.

#### No-op at latest `TC-migrations-noop-at-latest` `[auto]`

- **Type**: Integration
- **Covers**: `AC-migrations-noop-when-current`, `FR-migrations-noop-when-current`, `FR-migrations-pending-detection`
- **Preconditions**: `baseline-at-latest/` fixture.
- **Steps**: Run `/pdeq-migrate`.
- **Expected Result**:
  - Exit 0.
  - Output contains `~ Already at 0.4.0 — nothing to migrate.`
  - No migration-header `▸` lines printed.
  - File tree unchanged (hash compare).

#### No-op makes no writes `TC-migrations-noop-no-writes` `[auto]`

- **Type**: Integration
- **Covers**: `FR-migrations-noop-when-current`, `NFR-migrations-scope-minimalism`
- **Preconditions**: `baseline-at-latest/` fixture, file tree hash snapshot.
- **Steps**: Run `/pdeq-migrate`; re-hash.
- **Expected Result**: Hashes match byte-for-byte.

#### Single migration applies cleanly `TC-migrations-pending-detection-single` `[auto]`

- **Type**: Integration
- **Covers**: `FR-migrations-pending-detection`, `FR-migrations-explicit-run`
- **Preconditions**: `baseline-one-behind/` fixture, `mechanical-only/` migration.
- **Steps**: Run `/pdeq-migrate`.
- **Expected Result**:
  - Output contains `1 migration pending: 0.4.0`.
  - One `▸ 0.4.0 — …` header printed.
  - `✓ mechanical` line printed.
  - `~ semantic    no semantic block` line printed.
  - `✓ migration complete` printed.
  - Final line `✓ pdeq: recorded 0.3.2 → 0.4.0`.
  - Exit 0. Recorded version in `pdeq.json` is now `0.4.0`.

#### Multiple migrations apply in version order `TC-migrations-multi-order` `[auto]`

- **Type**: Integration
- **Covers**: `FR-migrations-ordered`, `FR-migrations-ordered-application`, `AC-migrations-ordered-apply`, `NFR-migrations-determinism`
- **Preconditions**: `baseline-multi-behind/` fixture (pending: 0.3.0, 0.3.2, 0.4.0).
- **Steps**: Run `/pdeq-migrate`.
- **Expected Result**:
  - Output contains `3 migrations pending: 0.3.0, 0.3.2, 0.4.0` in that order.
  - Three `▸ 0.3.0`, `▸ 0.3.2`, `▸ 0.4.0` headers printed in that order (assert with `grep -n '^▸'` then ordering check).
  - Exit 0. Recorded version is `0.4.0`.

#### Pending-list none case `TC-migrations-pending-detection-none` `[auto]`

- **Type**: Integration
- **Covers**: `FR-migrations-pending-detection`
- **Preconditions**: `baseline-at-latest/` fixture.
- **Steps**: Run `/pdeq-migrate --dry-run`.
- **Expected Result**: Output does not contain `pending:`; contains the no-op "already at" message. Exit 0.

#### Pending-list multi case `TC-migrations-pending-detection-multi` `[auto]`

- **Type**: Integration
- **Covers**: `FR-migrations-pending-detection`
- **Preconditions**: `baseline-multi-behind/` fixture.
- **Steps**: Run `/pdeq-migrate --dry-run`.
- **Expected Result**: Output contains exactly `3 migrations pending: 0.3.0, 0.3.2, 0.4.0`. Exit 0.

#### Version bump on success `TC-migrations-version-bump-success` `[auto]`

- **Type**: Integration
- **Covers**: `FR-migrations-version-bump`, `AC-migrations-ordered-apply`
- **Preconditions**: `baseline-multi-behind/` fixture.
- **Steps**: Run `/pdeq-migrate`; read `pdeqVersion` field from `pdeq.json`.
- **Expected Result**: `pdeqVersion` equals `0.4.0` (pinned version).

#### Dry-run makes no writes `TC-migrations-dry-run-no-writes` `[auto]`

- **Type**: Integration
- **Covers**: `FR-migrations-dry-run`, `AC-migrations-dry-run-accurate`
- **Preconditions**: `baseline-multi-behind/` fixture, file tree hash snapshot.
- **Steps**: Run `/pdeq-migrate --dry-run`; re-hash.
- **Expected Result**: Hashes match. `pdeqVersion` still `0.2.1`. Exit 0.

#### Dry-run output shape matches design `TC-migrations-dry-run-output-shape` `[auto]`

- **Type**: Integration
- **Covers**: `FR-migrations-dry-run`, `AC-migrations-dry-run-accurate`
- **Preconditions**: `baseline-multi-behind/` fixture.
- **Steps**: Run `/pdeq-migrate --dry-run`.
- **Expected Result**:
  - Header line ends with `[DRY RUN — no writes]`.
  - Every block status line uses `•` glyph (not `✓`/`~`).
  - Every block status line uses conditional tense ("would rewrite", "would create", "would update", "would review").
  - Final line is `[DRY RUN] No files were modified. Run /pdeq-migrate to apply.`
  - Exit 0.

#### Dry-run skips semantic execution `TC-migrations-dry-run-semantic-skipped` `[auto]`

- **Type**: Integration
- **Covers**: `FR-migrations-dry-run`
- **Preconditions**: `with-semantic/` migration fixture. `PDEQ_SEMANTIC_AGENT` points to a stub that writes `I RAN` to a sentinel file when invoked.
- **Steps**: Run `/pdeq-migrate --dry-run`.
- **Expected Result**:
  - Sentinel file is absent (stub was not invoked).
  - Output contains `would review N files (preview suppressed in dry-run — semantic changes require a live agent pass; re-run without --dry-run to see proposed edits)`.

#### Dry-run matches real run `TC-migrations-dry-run-matches-real-run` `[auto]`

- **Type**: Integration
- **Covers**: `AC-migrations-dry-run-accurate`
- **Preconditions**: `baseline-multi-behind/` fixture (mechanical-only migrations for determinism).
- **Steps**:
  1. Clone the fixture twice (fixture A and fixture B).
  2. On A, run `/pdeq-migrate --dry-run`; capture the list of files each mechanical block would touch (parse the `would rewrite/move/update` lines).
  3. On B, run `/pdeq-migrate` (real); diff the file tree from before/after to get the set of files actually touched.
- **Expected Result**: The two file sets are equal.

#### Dry-run file list exhaustive `TC-migrations-dry-run-file-list-exhaustive` `[auto]`

- **Type**: Integration
- **Covers**: `NFR-migrations-scope-minimalism`, `AC-migrations-dry-run-accurate`
- **Preconditions**: `baseline-multi-behind/` fixture.
- **Steps**: Run `/pdeq-migrate --dry-run`; collect the full set of file paths mentioned in block previews (including truncated ones — assert the `…N more…` count plus visible paths sums to the total touched by the real run).
- **Expected Result**: Visible count + `…N more…` count equals the real run's touched-file count.

#### Re-run is a no-op `TC-migrations-rerun-is-noop` `[auto]`

- **Type**: Integration
- **Covers**: `AC-migrations-idempotent-rerun`, `FR-migrations-idempotent`, `NFR-migrations-idempotency`
- **Preconditions**: `baseline-multi-behind/` fixture.
- **Steps**:
  1. Run `/pdeq-migrate`. Expect exit 0 and `pdeqVersion == 0.4.0`.
  2. Snapshot file tree hash.
  3. Run `/pdeq-migrate` again.
  4. Re-hash.
- **Expected Result**:
  - Second run exits 0.
  - Second run output contains `~ Already at 0.4.0 — nothing to migrate.`
  - Post-second-run hash equals post-first-run hash.

#### Mechanical block is idempotent `TC-migrations-mechanical-idempotent` `[auto]`

- **Type**: Unit
- **Covers**: `FR-migrations-idempotent`, `NFR-migrations-idempotency`
- **Preconditions**: `mechanical-only/` migration; run its shell script once against a test input; capture output.
- **Steps**: Run the same script a second time against the now-migrated files.
- **Expected Result**: Second run makes no substitutions (stdout/stderr reports zero changes; files are byte-identical).

#### Semantic block is idempotent `TC-migrations-semantic-idempotent` `[semi-auto]`

- **Type**: Integration
- **Covers**: `FR-migrations-idempotent`, `NFR-migrations-idempotency`, `AC-migrations-idempotent-rerun`
- **Preconditions**: `with-semantic/` migration; `PDEQ_SEMANTIC_AGENT=noop-already-conformant.sh` (stub simulates a well-behaved agent that emits zero changes when content already conformant).
- **Steps**:
  1. Apply the semantic block once with `deterministic-rewrite.sh` to produce conformant content.
  2. Re-apply with `noop-already-conformant.sh`.
- **Expected Result**: Second invocation emits `updated 0 of M files`; no file changed. A **manual companion run** (marked separately) repeats this once per release with a real agent to confirm the stub is realistic.

#### Non-breaking version has no migration file `TC-migrations-non-breaking-no-file` `[auto]`

- **Type**: Integration
- **Covers**: `FR-migrations-one-per-version`
- **Preconditions**: Fixture with `pdeqVersion: 0.3.1`, pinned `0.3.2` (a bug-fix release), migrations dir has NO `0.3.2.md` file.
- **Steps**: Run `/pdeq-migrate`.
- **Expected Result**: Output states no migrations pending for 0.3.2; recorded advances cleanly to `0.3.2` via direct bump (per the engineering spec's handling of non-breaking releases — assertion: final `pdeqVersion == 0.3.2`, no migration "ran" output lines).

#### One file per version `TC-migrations-one-file-per-version` `[auto]`

- **Type**: Unit
- **Covers**: `FR-migrations-one-per-version`
- **Preconditions**: Test harness attempts to create a fixture with two `.pdeq/migrations/` files both targeting `0.4.0` (differing filenames e.g. `0.4.0.md` and `0.4.0-fix.md`).
- **Steps**: Run `/pdeq-migrate --dry-run`.
- **Expected Result**: Command refuses to start with an error about duplicate target-version, or deterministically picks the correctly-named `0.4.0.md` and warns about the second. (Exact behavior per engineering spec; test pins whichever is chosen.)

#### Author-written file required `TC-migrations-file-required` `[auto]`

- **Type**: Integration
- **Covers**: `FR-migrations-author-written`
- **Preconditions**: Fixture recorded `0.3.2`, pinned `0.4.0`, but `.pdeq/migrations/0.4.0.md` is MISSING even though the version lineage says `0.4.0` is breaking.
- **Steps**: Run `/pdeq-migrate`.
- **Expected Result**: Command errors with a clear message that the migration file is required and missing. Exit non-zero. No writes.

#### No auto-trigger on other pdeq commands `TC-migrations-no-auto-trigger` `[auto]`

- **Type**: Integration
- **Covers**: `FR-migrations-explicit-run`
- **Preconditions**: `baseline-one-behind/` fixture, file tree hash snapshot.
- **Steps**: Run each other pdeq command that might be invoked after a submodule bump: `./scripts/audit-traceability.sh`, `./scripts/init.sh` (in a way that doesn't overwrite), `/pdeq-status` command if present. Do NOT run `/pdeq-migrate`.
- **Expected Result**: None of these trigger migration output. `pdeqVersion` remains at `0.3.2`. File tree hash unchanged.

### Group 3 — Block Composition and Order

Verifies mechanical/semantic block presence, absence, and relative order within a migration.

#### Mechanical block runs and reports `TC-migrations-mechanical-runs` `[auto]`

- **Type**: Integration
- **Covers**: `FR-migrations-mechanical-block`
- **Preconditions**: `mechanical-only/` migration.
- **Steps**: Run `/pdeq-migrate`.
- **Expected Result**: Output contains `✓ mechanical    <summary>` where summary starts with a verb like `rewrote`, `created`, or `updated`.

#### Mechanical absent marker `TC-migrations-mechanical-absent-marker` `[auto]`

- **Type**: Integration
- **Covers**: `FR-migrations-mechanical-block`
- **Preconditions**: `semantic-only/` migration.
- **Steps**: Run `/pdeq-migrate`.
- **Expected Result**: Output contains `~ mechanical    no mechanical block` (yellow `~`).

#### Semantic block runs and reports `TC-migrations-semantic-runs` `[semi-auto]`

- **Type**: Integration
- **Covers**: `FR-migrations-semantic-block`
- **Preconditions**: `with-semantic/` migration, `PDEQ_SEMANTIC_AGENT=deterministic-rewrite.sh`.
- **Steps**: Run `/pdeq-migrate`.
- **Expected Result**: Output contains `✓ semantic      reviewed N files, updated K`. File contents reflect stub's transformation.

#### Semantic absent marker `TC-migrations-semantic-absent-marker` `[auto]`

- **Type**: Integration
- **Covers**: `FR-migrations-semantic-block`
- **Preconditions**: `mechanical-only/` migration.
- **Steps**: Run `/pdeq-migrate`.
- **Expected Result**: Output contains `~ semantic      no semantic block`.

#### Mechanical before semantic `TC-migrations-mechanical-before-semantic` `[auto]`

- **Type**: Integration
- **Covers**: `FR-migrations-order-within`
- **Preconditions**: `with-semantic/` migration. Mechanical step writes a sentinel line to a file; semantic stub (`deterministic-rewrite.sh`) asserts that sentinel is present, or writes a counter-sentinel. Both are timestamped to a log file.
- **Steps**: Run `/pdeq-migrate`; inspect the log.
- **Expected Result**: Mechanical sentinel timestamp precedes semantic sentinel timestamp. Output's `mechanical` line appears before `semantic` line in stdout (assert line order with `grep -n`).

### Group 4 — Failure Modes and Atomicity

Verifies that failures halt progress, do not bump the version past the failure point, and leave the project in a reportable recoverable state.

#### Atomic bump on mechanical failure `TC-migrations-atomic-bump-on-mechanical-fail` `[auto]`

- **Type**: Integration
- **Covers**: `FR-migrations-atomic-bump`, `AC-migrations-no-bump-on-failure`, `FR-migrations-failure-report`
- **Preconditions**: Fixture recorded `0.2.1`, pending `0.3.0` (clean mechanical-only), `0.3.2` (`failing-mechanical/`), `0.4.0` (clean). So first migration succeeds, second fails.
- **Steps**: Run `/pdeq-migrate`.
- **Expected Result**:
  - Exit non-zero.
  - Output shows `▸ 0.3.0` with `✓ migration complete`.
  - Output shows `▸ 0.3.2` with `✗ mechanical    failed: …`.
  - Final summary: `Recorded pdeq version: 0.3.0 (advanced from 0.2.1 — 0.3.0 applied cleanly)`.
  - `pdeqVersion` in `pdeq.json` is `0.3.0` — NOT `0.3.2`, NOT `0.4.0`.
  - Remaining list contains `0.3.2, 0.4.0`.

#### Atomic bump on semantic failure `TC-migrations-atomic-bump-on-semantic-fail` `[semi-auto]`

- **Type**: Integration
- **Covers**: `FR-migrations-atomic-bump`, `AC-migrations-no-bump-on-failure`
- **Preconditions**: Fixture recorded `0.2.1`; pending `0.3.0` (clean), `0.3.2` is `failing-semantic/` (mechanical succeeds, semantic stub exits non-zero).
- **Steps**: Run `/pdeq-migrate` with `PDEQ_SEMANTIC_AGENT=failing.sh`.
- **Expected Result**:
  - Exit non-zero.
  - `▸ 0.3.2` line shows `✓ mechanical` then `✗ semantic    failed: <stub error>`.
  - `pdeqVersion` is `0.3.0` (the last migration that fully completed including both blocks).

#### Failure report names migration `TC-migrations-failure-report-names-migration` `[auto]`

- **Type**: Integration
- **Covers**: `FR-migrations-failure-report`
- **Preconditions**: As `TC-migrations-atomic-bump-on-mechanical-fail`.
- **Steps**: Run `/pdeq-migrate`; capture stdout.
- **Expected Result**: Output contains `✗ Migration 0.3.2 failed at the mechanical step.`

#### Failure report names block `TC-migrations-failure-report-names-block` `[auto]`

- **Type**: Integration
- **Covers**: `FR-migrations-failure-report`
- **Preconditions**: As above (mechanical fail) and `TC-migrations-atomic-bump-on-semantic-fail` (semantic fail).
- **Steps**: Both variants run.
- **Expected Result**: Mechanical-fail output contains `at the mechanical step`. Semantic-fail output contains `at the semantic step`.

#### Failure report provides recovery steps `TC-migrations-failure-report-recovery-steps` `[auto]`

- **Type**: Integration
- **Covers**: `FR-migrations-failure-report`, `FR-migrations-recoverable-partial`
- **Preconditions**: As `TC-migrations-atomic-bump-on-mechanical-fail`.
- **Steps**: Run `/pdeq-migrate`.
- **Expected Result**: Output contains `What to do:` block with at least two numbered items and the phrase `re-run /pdeq-migrate`. Output contains `No rollback was performed` and `git status`.

#### Partial state is recoverable `TC-migrations-partial-recoverable-state` `[auto]`

- **Type**: Integration
- **Covers**: `FR-migrations-recoverable-partial`
- **Preconditions**: As `TC-migrations-atomic-bump-on-mechanical-fail`.
- **Steps**: After the failed run, inspect the specs root.
- **Expected Result**: Any partial file writes from the failing mechanical step are visible on disk (not silently rolled back). The user can `git diff` to see them.

#### Resume after fix completes the run `TC-migrations-resume-after-fix` `[auto]`

- **Type**: Integration
- **Covers**: `FR-migrations-recoverable-partial`, `FR-migrations-ordered-application`
- **Preconditions**: After a failed run as above.
- **Steps**:
  1. Mutate the failing migration's stub script to succeed (simulating the user having fixed the cause).
  2. Re-run `/pdeq-migrate` (no `--from` flag needed — should resume automatically from recorded `0.3.0`).
- **Expected Result**: `▸ 0.3.2` and `▸ 0.4.0` now both complete. Final `pdeqVersion == 0.4.0`. Exit 0.

#### No skip gaps `TC-migrations-no-skip-gaps` `[auto]`

- **Type**: Integration
- **Covers**: `FR-migrations-ordered-application`
- **Preconditions**: Three pending migrations. Delete the middle one's file after the run starts (race-like — simulate via a wrapper that removes it after header prints). Alternative: just verify the tool refuses to "skip" a broken file.
- **Steps**: Run `/pdeq-migrate` with a corrupted middle migration file.
- **Expected Result**: Tool does not skip to the next version; it halts at the corrupted one with an error naming the file.

### Group 5 — Scope Enforcement

Verifies that migrations respect their declared scope and cannot write outside it, and that the semantic block only receives the declared file context.

#### Default scope enforced `TC-migrations-scope-default-enforced` `[auto]`

- **Type**: Integration
- **Covers**: `FR-migrations-scoped-writes`, `AC-migrations-scope-respected`, `NFR-migrations-scope-minimalism`
- **Preconditions**: `out-of-scope-write/` migration (frontmatter `scope: default`, mechanical script attempts `echo x > <sibling dir>/leak.txt`).
- **Steps**: Run `/pdeq-migrate`.
- **Expected Result**:
  - Exit non-zero.
  - Output contains an error naming the out-of-scope path.
  - The target leak file does NOT exist post-run.
  - `pdeqVersion` not advanced.

#### Broader scope declared and honored `TC-migrations-scope-broader-declared` `[auto]`

- **Type**: Integration
- **Covers**: `FR-migrations-scoped-writes`, `AC-migrations-scope-respected`
- **Preconditions**: `broad-scope-declared/` migration (frontmatter declares an explicit extra path like `tools/**`). Fixture has that extra directory.
- **Steps**: Run `/pdeq-migrate`.
- **Expected Result**: Migration succeeds. The declared extra path is modified. Paths outside both default scope and the declared scope are still untouched.

#### Semantic block's file context is confined `TC-migrations-scope-semantic-context-confined` `[semi-auto]`

- **Type**: Integration
- **Covers**: `AC-migrations-semantic-context`, `FR-migrations-scoped-writes`
- **Preconditions**: `with-semantic/` migration declaring `### Files: design/**/*.md`. `PDEQ_SEMANTIC_AGENT=snooping.sh` which reports every path it was given access to.
- **Steps**: Run `/pdeq-migrate`; inspect the stub's log of observed paths.
- **Expected Result**: Every observed path matches `design/**/*.md`. No path from `product/`, `engineering/`, `qa/`, or outside the specs root appears.

#### Semantic block receives the correct files `TC-migrations-semantic-context-receives-files` `[semi-auto]`

- **Type**: Integration
- **Covers**: `AC-migrations-semantic-context`, `FR-migrations-semantic-block`
- **Preconditions**: `with-semantic/` migration with `### Files` listing 3 specific files. Stub agent logs the exact files it received.
- **Steps**: Run `/pdeq-migrate`.
- **Expected Result**: The stub's log enumerates exactly those 3 files with their current (mechanical-post) content, nothing more and nothing less.

#### Untouched files remain byte-identical `TC-migrations-untouched-files-unchanged` `[auto]`

- **Type**: Integration
- **Covers**: `NFR-migrations-scope-minimalism`
- **Preconditions**: `baseline-multi-behind/` fixture seeded with an extra specs file (`product/unrelated.md`) that no migration should touch.
- **Steps**: Snapshot a hash of `product/unrelated.md`; run `/pdeq-migrate`; re-hash.
- **Expected Result**: Hashes match byte-for-byte. No reformatting, no trailing-newline drift.

### Group 6 — Pre-commit Gate (pdeq repo only)

Verifies the enforcement gate in the pdeq repo itself — blocks missing migrations on breaking bumps, stays silent on non-breaking or non-framework commits, and honors the `pdeq-migration: none-required` trailer override.

#### Breaking bump blocked without migration file `TC-migrations-gate-blocks-missing-file` `[auto]`

- **Type**: E2E
- **Covers**: `FR-migrations-breaking-gate`, `AC-migrations-gate-blocks`
- **Preconditions**: `pdeq-repo-like/` fixture: a git-initialized directory with the pdeq framework layout and the gate hook installed. Starting version `0.3.2`.
- **Steps**:
  1. Modify a framework file (e.g., `CLAUDE.md`) and bump the version in config from `0.3.2` to `0.4.0` (flagged as breaking per the schema).
  2. Do NOT create `.pdeq/migrations/0.4.0.md`.
  3. `git add -A && git commit -m "break things"`.
- **Expected Result**:
  - Commit is blocked (exit non-zero from `git commit`).
  - Gate output contains `✗ pdeq pre-commit: breaking-change gate blocked this commit.`
  - Output names `0.3.2 → 0.4.0   (breaking)` and the expected path `.pdeq/migrations/0.4.0.md  (not found)`.
  - Output includes all three options A/B/C.
  - Repo head is unchanged.

#### Breaking bump passes with migration file `TC-migrations-gate-passes-with-file` `[auto]`

- **Type**: E2E
- **Covers**: `FR-migrations-breaking-gate`
- **Preconditions**: As above, PLUS `.pdeq/migrations/0.4.0.md` is present and well-formed.
- **Steps**: `git add -A && git commit`.
- **Expected Result**: Commit succeeds. Gate prints nothing (or only a one-line "gate satisfied" confirmation, per engineering spec).

#### Docs-only commit not blocked `TC-migrations-gate-docs-only` `[auto]`

- **Type**: E2E
- **Covers**: `FR-migrations-no-false-positive`, `NFR-migrations-enforcement-precision`, `AC-migrations-gate-allows-nonbreaking`
- **Preconditions**: `pdeq-repo-like/` fixture. Change only `README.md` or a file under `design/**/*.md`. Do NOT bump the version.
- **Steps**: `git add -A && git commit`.
- **Expected Result**: Commit succeeds. Gate output is empty.

#### Non-framework commit not blocked `TC-migrations-gate-nonframework` `[auto]`

- **Type**: E2E
- **Covers**: `FR-migrations-no-false-positive`, `NFR-migrations-enforcement-precision`, `AC-migrations-gate-allows-nonbreaking`
- **Steps**: Modify only a file outside framework files (e.g., under `roadmap/` or a fixture/test file). `git commit`.
- **Expected Result**: Commit succeeds, gate silent.

#### Trailer override bypasses gate `TC-migrations-gate-trailer-override` `[auto]`

- **Type**: E2E
- **Covers**: `FR-migrations-no-false-positive`, `AC-migrations-gate-allows-nonbreaking`
- **Preconditions**: `pdeq-repo-like/` fixture, framework file modified, version bumped `0.3.2 → 0.4.0`, but NO migration file.
- **Steps**: `git commit -m "refactor only; no consumer-visible contract changed" -m "pdeq-migration: none-required"`.
- **Expected Result**:
  - Commit succeeds.
  - Gate output (if any) logs that the override trailer was detected and honored, for auditability.
  - The trailer appears in `git log -1 --format=%B`.

### Group 7 — Self-Migration (Dogfood)

Verifies that pdeq's own specs can migrate cleanly on release using the same CLI surface consumers use.

#### Self-migration uses the same command `TC-migrations-self-migration-same-command` `[auto]`

- **Type**: Integration
- **Covers**: `FR-migrations-bootstrap-chain`, `FR-migrations-self-migration`
- **Preconditions**: `self-migration/` fixture.
- **Steps**: Run `/pdeq-migrate` (no special flag, no dogfood mode).
- **Expected Result**: Output is visually identical to Surface 9 / Surface 3. No banner, no "dogfood" label. Command uses the same code path (assert via trace/log if engineering provides one).

#### Self-migration advances version `TC-migrations-self-migration-advances-version` `[auto]`

- **Type**: Integration
- **Covers**: `AC-migrations-self-migration-runs`, `FR-migrations-self-migration`
- **Preconditions**: `self-migration/` fixture recorded `0.3.2`, pinned `0.4.0`.
- **Steps**: Run `/pdeq-migrate`; read `pdeqVersion` from the fixture's config.
- **Expected Result**: Exit 0. Output ends with `✓ pdeq: recorded 0.3.2 → 0.4.0`. `pdeqVersion == 0.4.0`.

### Group 8 — Output Formatting and Error Messages

Verifies that all status lines, glyphs, and error messages match the design spec. Catches output drift that would hurt downstream grep/awk tooling and screen-reader behavior.

#### Output uses design glyphs and colors `TC-migrations-output-glyphs` `[auto]`

- **Type**: Integration
- **Covers**: `FR-migrations-version-readable` (surface-level)
- **Preconditions**: `baseline-one-behind/` fixture, run WITHOUT `NO_COLOR`.
- **Steps**: Run `/pdeq-migrate`; capture raw output (including ANSI).
- **Expected Result**: `✓` paired with green escape codes, `~` with yellow, `✗` (in failure variants) with red, `•` (in dry-run) with no color escape. Every glyph matches the set documented in the design spec's Component Specs.

#### Determinism across two runs `TC-migrations-determinism-two-runs` `[auto]`

- **Type**: Integration
- **Covers**: `NFR-migrations-determinism`
- **Preconditions**: Two fresh copies of `baseline-multi-behind/` fixture.
- **Steps**: Run `/pdeq-migrate` on copy A and copy B. Compare (a) final `pdeqVersion`, (b) post-run file tree hashes, (c) stdout modulo timestamps.
- **Expected Result**: Identical final version, identical file trees, identical stdout (up to non-deterministic-by-design fields like timestamps).

#### Unknown migration format reports clearly `TC-migrations-unknown-format-error` `[auto]`

- **Type**: Integration
- **Covers**: `FR-migrations-failure-report`, `FR-migrations-author-written`
- **Preconditions**: `unknown-format/` migration with malformed frontmatter (e.g., missing `target-version`).
- **Steps**: Run `/pdeq-migrate`.
- **Expected Result**: Exit non-zero. Output names the file path and the specific parse problem (missing field / unrecognized section). No writes performed.

#### Status line is grep-friendly `TC-migrations-grep-friendly` `[auto]`

- **Type**: Unit
- **Covers**: design's Accessibility requirements (output is grep-friendly)
- **Preconditions**: `baseline-multi-behind/` fixture.
- **Steps**: Run `/pdeq-migrate`; pipe through `grep -E '^\s*(✓|~|✗|•|▸)'` to extract status lines.
- **Expected Result**: Every status line and migration-header line is extractable. Stdout noise outside those lines is minimal.

### Group 9 — Upgrade Entrypoint (`/pdeq-update`)

Verifies the `/pdeq-update` slash command end-to-end: bump-then-migrate happy path, no-op when current, non-breaking-only advance, in-session command availability after the bump, recoverable bump failures, dry-run preview accuracy, the self-host refusal inside the pdeq repo, and dangling-symlink pruning.

`/pdeq-update` is a prompt-driven slash command, not a pure shell script. The shell side of the runner — `git submodule update --remote .pdeq` and `scripts/sync-symlinks.sh --prune --json` — is fully scriptable; the orchestration that prints Surfaces 11–14 lives in `.claude/commands/pdeq-update.md` and runs inside a coding-agent session. Tests below use the same convention as Group 1–8: where the assertion is on shell-side behavior (pin SHA, recorded version, file tree, symlink state), the test is `[auto]`. Where the assertion requires observing rendered surface output or verifying that a slash command becomes invocable mid-session, the test is `[manual]` or `[semi-auto]` and the harness expectations are spelled out.

#### `/pdeq-update` end-to-end happy path `TC-migrations-update-happy` `[semi-auto]`

- **Type**: E2E
- **Covers**: `AC-migrations-update-end-to-end`, `FR-migrations-update-command`, `FR-migrations-update-bumps-pin`, `FR-migrations-update-chains`
- **Preconditions**: `update-pin-behind/` fixture. Three version states are distinguished:
  - **recorded** (`pdeq.json`'s `pdeqVersion`) = `0.2.1`
  - **pinned** (`.pdeq/VERSION`, i.e. the SHA the submodule is checked out at) = `0.2.1`
  - **available** (origin/HEAD on the bare remote backing `.pdeq/`) = `0.4.0`

  The bare remote backing `.pdeq/` carries breaking versions `0.3.0`, `0.3.2`, and `0.4.0` (with matching mechanical-only migration files at `migrations/0.3.0.md`, `migrations/0.3.2.md`, `migrations/0.4.0.md`) on the path from the pinned commit to the available tip. `/pdeq-update` must advance pinned to match available, then advance recorded to match the new pinned.
- **Steps**:
  1. Snapshot pre-run: `git -C .pdeq rev-parse HEAD` → `PRE_PIN_SHA`; `pdeq.json`'s `pdeqVersion` (= `0.2.1`); `.pdeq/VERSION` content (= `0.2.1`); specs root file-tree hash; `.pdeq/migrations/` listing (the migration files for `0.3.0`, `0.3.2`, `0.4.0` are not yet visible because the submodule is still on `0.2.1`).
  2. Run `/pdeq-update` from inside an agent session whose cwd is the fixture root. (For automated CI, drive via the `pdeq-update.md` orchestrator's underlying shell calls in sequence: `git submodule update --remote --force .pdeq`, then `scripts/sync-symlinks.sh --prune --json`, then `scripts/migrate.sh list-pending`, then iterate the migration loop with `parse` + `bump`. This bypasses the agent prompt but exercises every shell helper `/pdeq-update` invokes.)
  3. After the run: re-read `git -C .pdeq rev-parse HEAD` → `POST_PIN_SHA`; `pdeqVersion`; `.pdeq/VERSION`; output capture.
- **Expected Result**:
  - **Post-bump pinned**: `POST_PIN_SHA != PRE_PIN_SHA` and resolves to the `0.4.0` tag; `.pdeq/VERSION` reads `0.4.0`.
  - **Post-bump recorded**: `pdeqVersion` in `pdeq.json` is `0.4.0`.
  - **Post-bump available**: unchanged at `0.4.0` (origin/HEAD did not move during the test).
  - All three migration files (`0.3.0.md`, `0.3.2.md`, `0.4.0.md`) ran exactly once each in version order (assert via per-migration sentinel files written by their mechanical blocks, ordered by mtime).
  - Captured output contains, in order: `pdeq: pinned 0.2.1 → available 0.4.0` (the pre-bump status line, comparing pre-bump pinned to available), `▸ Bumping pinned pdeq reference`, `✓ pinned pdeq advanced 0.2.1 → 0.4.0`, `▸ Migrating`, the inner status line `pdeq: recorded 0.2.1 → pinned 0.4.0` (now comparing pre-bump recorded to post-bump pinned), three nested `▸ 0.3.0`/`▸ 0.3.2`/`▸ 0.4.0` migration headers, `✓ pdeq: recorded 0.2.1 → 0.4.0`, and the final `✓ pdeq: updated to 0.4.0` summary line.
  - Exit 0.
- **Notes**: The `[semi-auto]` tag reflects that the surface-output assertions are tied to the prompt orchestrator. A pure-shell variant (covering all state assertions but skipping the rendered-output regex) is `[auto]` and should run on every CI build; the surface-text regex assertions run as a manual companion at least once per release.

#### `/pdeq-update` no-op when already current `TC-migrations-update-noop-current` `[auto]`

- **Type**: E2E
- **Covers**: `AC-migrations-update-noop`, `FR-migrations-update-noop`
- **Preconditions**: `update-pin-at-latest/` fixture. `PRE_PIN_SHA` already matches the bare remote's tip; `pdeqVersion` is `0.4.0`.
- **Steps**:
  1. Snapshot `PRE_PIN_SHA`, `pdeqVersion`, and the full working-tree hash (specs root + `pdeq.json` + `.gitmodules` + `.pdeq/` submodule pointer).
  2. Run `/pdeq-update`.
  3. Re-snapshot.
- **Expected Result**:
  - `git submodule update --remote` runs and exits 0 but `POST_PIN_SHA == PRE_PIN_SHA` (no advance available).
  - The runner short-circuits before `scripts/sync-symlinks.sh` and before `/pdeq-migrate`. No symlinks are created, deleted, or pruned. No migration runs.
  - `pdeqVersion` unchanged at `0.4.0`. Working-tree hash byte-identical to pre-run.
  - Output contains `pdeq: pinned 0.4.0 → available 0.4.0` and `~ Already at 0.4.0 — nothing to update.`
  - Exit 0.

#### `/pdeq-update` advances across only non-breaking versions `TC-migrations-update-nonbreaking-only` `[auto]`

- **Type**: E2E
- **Covers**: `AC-migrations-update-end-to-end`, `FR-migrations-update-bumps-pin`, `FR-migrations-update-chains`, `FR-migrations-nonbreaking-advance` (cross-coverage)
- **Preconditions**: `update-nonbreaking-window/` fixture. Recorded `0.3.0`, pinned `0.3.0`; bare remote advances to `0.3.2`. Migrations dir is empty for the `(0.3.0, 0.3.2]` window. `PDEQ_LINEAGE_FILE` does NOT mark `0.3.1`/`0.3.2` as breaking.
- **Steps**:
  1. Snapshot `PRE_PIN_SHA`, `pdeqVersion`, file-tree hash.
  2. Run `/pdeq-update`.
  3. Re-snapshot.
- **Expected Result**:
  - `POST_PIN_SHA` resolves to the `0.3.2` tag; `PRE_PIN_SHA != POST_PIN_SHA`.
  - The chained `/pdeq-migrate` step runs but reports `~ No migrations pending. Advancing recorded version 0.3.0 → 0.3.2 (non-breaking releases).` — no `▸ <version>` migration headers printed.
  - `pdeqVersion` is `0.3.2`. No `.md` file in the specs tree was modified (hash compare).
  - Final output contains `✓ pdeq: updated to 0.3.2`.
  - Exit 0.

#### `/pdeq-update` makes new commands invocable in same session `TC-migrations-update-in-session-new-command` `[manual]` (with `[auto]` file-existence companion)

- **Type**: E2E
- **Covers**: `AC-migrations-update-in-session`, `FR-migrations-update-in-session`
- **Preconditions**: `update-new-command-shipped/` fixture. Pre-bump submodule has no `update-fixture-test.md`; post-bump submodule contains `.pdeq/.claude/commands/update-fixture-test.md` whose body is a one-liner that prints a recognizable sentinel string (e.g., `update-fixture-test: ok`).
- **Test scaffolding & split**:
  - **Automated companion** (`[auto]`): a shell test that drives the shell layer of `/pdeq-update` (same approach as `TC-migrations-update-happy`'s automated half) and asserts on filesystem state only, not on slash-command invocability:
    1. Pre-snapshot: confirm `<git-root>/.claude/commands/update-fixture-test.md` does not exist.
    2. Run `git submodule update --remote --force .pdeq`, then `scripts/sync-symlinks.sh --prune --json`, parsing the JSON report.
    3. Assert: JSON report's `created` array contains `update-fixture-test.md`.
    4. Assert: `<git-root>/.claude/commands/update-fixture-test.md` exists, is a symlink, points at `../../.pdeq/.claude/commands/update-fixture-test.md`, resolves successfully, and the resolved file has the sentinel body.
    5. Assert: the chained `/pdeq-migrate` step then advances `pdeqVersion` to `0.4.0` per `TC-migrations-update-happy`.
  - **Manual companion** (`[manual]`): once per release, a maintainer drives the full flow inside an actual coding-agent session:
    1. Open a fresh session with cwd = fixture root.
    2. Confirm autocomplete does not show `/update-fixture-test`.
    3. Run `/pdeq-update`. Confirm Surface 12 output ends with `New commands available: /update-fixture-test`.
    4. In the same session, type `/update-fixture-test` (literal slash-name; autocomplete is allowed to be stale per engineering §Harness re-reads commands from disk lazily). Confirm the sentinel string is printed.
    5. The manual run is what exercises the harness's lazy disk-lookup behavior, which the automated test cannot reach.
- **Expected Result**:
  - Automated half: symlink created and resolves; `pdeqVersion` advanced; `created` JSON list names the new command.
  - Manual half: `/update-fixture-test` invokes successfully in the same session, prints the sentinel.
- **Notes**: This TC is the only one in the upgrade-entrypoint group whose full coverage depends on an interactive harness. Treat the automated companion as gating; the manual companion is a release-time verification step. If the harness ever adds a stable, programmatic way to invoke a slash command from a test, this TC should be re-promoted to `[auto]`.

#### `/pdeq-update` reports a recoverable bump failure `TC-migrations-update-bump-failure-network` `[auto]`

- **Type**: E2E
- **Covers**: `AC-migrations-update-bump-failure`, `FR-migrations-update-bump-failure`
- **Preconditions**: `update-bump-broken-remote/` fixture. Submodule's `origin` URL points at a non-existent path (or a stub remote that returns non-zero on fetch). `pdeqVersion` recorded `0.3.2`. Optionally, mock `git submodule update` via a `PATH`-shadowed wrapper that exits non-zero with a known stderr line (`fatal: unable to access 'https://…': Could not resolve host.`) — engineering's failure-mode table treats both detection paths identically.
- **Steps**:
  1. Snapshot `PRE_PIN_SHA`, `pdeqVersion`, specs root hash, `.gitmodules` hash.
  2. Run `/pdeq-update`.
  3. Re-snapshot. Capture stdout + stderr + exit code.
  4. Repair the fixture's submodule URL to a working bare remote that has `0.4.0` available with a clean migration file.
  5. Re-run `/pdeq-update`.
- **Expected Result**:
  - First run:
    - Exit non-zero (engineering: exit 1).
    - Output contains `▸ Bumping pinned pdeq reference` followed by `✗ failed: could not fetch latest pdeq reference.` and the captured stderr line.
    - Output contains the post-failure summary block: `✗ /pdeq-update failed at the bump step.`, both `Pinned pdeq version: 0.3.2 (unchanged)` and `Recorded pdeq version: 0.3.2 (unchanged)`, and `No migration ran.`
    - Output contains a "What to do:" block whose recovery instruction names re-running `/pdeq-update`.
    - `PRE_PIN_SHA == POST_PIN_SHA`. `pdeqVersion` still `0.3.2`. Specs root hash unchanged. `scripts/sync-symlinks.sh` was NOT invoked (no JSON report emitted, no new symlinks created, no dangling pruned).
    - No `Surface 5`-style migration-failure output appears (the migration loop never started).
  - Second run (after fix): exits 0, advances pin and recorded version per `TC-migrations-update-happy`'s expectations against the now-working remote.

#### `/pdeq-update --dry-run` previews without changing anything `TC-migrations-update-dry-run` `[auto]`

- **Type**: E2E
- **Covers**: `AC-migrations-update-dry-run`, `FR-migrations-update-dry-run`
- **Preconditions**: `update-pin-behind/` fixture (recorded `0.2.1`, bare remote available at `0.4.0`).
- **Steps**:
  1. Snapshot `PRE_PIN_SHA`, `pdeqVersion`, the full working-tree hash (including `.gitmodules`, `.pdeq/` submodule pointer, `<git-root>/.claude/commands/`, `<git-root>/scripts/`, and the specs root).
  2. Run `/pdeq-update --dry-run`.
  3. Re-snapshot all of the above.
- **Expected Result**:
  - Output's first line is `pdeq: pinned 0.2.1 → available 0.4.0   [DRY RUN — no writes]`.
  - Output contains `▸ Bumping pinned pdeq reference` followed by `• would advance pinned pdeq 0.2.1 → 0.4.0` (neutral `•` glyph, conditional tense — matches Surface 13).
  - Output contains `▸ Migrating` followed by `pdeq: recorded 0.2.1 → pinned 0.4.0   [DRY RUN — no writes]` and `3 migrations would become pending: 0.3.0, 0.3.2, 0.4.0`.
  - Each block status line uses `•` and conditional tense (`would rewrite`, `would create`, `would update`, `would review`).
  - Output contains the trailing `[DRY RUN] Pin not advanced. Recorded version not changed. No files modified. Run /pdeq-update to apply.`
  - Output does NOT contain a `New commands available:` listing (per design Surface 13: dry-run never lists commands as "available").
  - `PRE_PIN_SHA == POST_PIN_SHA`. `pdeqVersion` unchanged at `0.2.1`. Working-tree hash byte-identical to pre-run. The fixture's submodule was either fetched without checkout (engineering: `git -C .pdeq fetch && git -C .pdeq rev-parse origin/HEAD`) or not advanced; `.gitmodules` and `.pdeq/`'s checked-out HEAD are unchanged.
  - Exit 0.
- **Open question flagged to product/design**: the design spec is silent on whether `/pdeq-update --dry-run` is allowed when a previous `/pdeq-update` (or bare `/pdeq-migrate`) left the project in a Surface 5 partial-failure state with pending migrations on a same-pin recorded version. Engineering's dry-run path is fetch-only and would still work mechanically, but design has not described the surface for "dry-run while a recovery is mid-flight." Test pinned to: dry-run on a clean pre-bump state. If a surface decision is added later, add `TC-migrations-update-dry-run-after-failure`.

#### `/pdeq-update` refuses inside the pdeq repo `TC-migrations-update-self-host-refuses` `[auto]`

- **Type**: E2E
- **Covers**: `FR-migrations-update-command` (self-host edge case)
- **Preconditions**: `update-self-host/` fixture. Root `VERSION` file present; `.pdeq/` submodule whose configured remote URL (per `git config --file .gitmodules submodule..pdeq.url`) matches the fixture repo's own `git config --get remote.origin.url`.
- **Steps**:
  1. Snapshot `PRE_PIN_SHA`, the `pdeqVersion` recorded in the fixture's `pdeq.json` (if present), and the full working-tree hash.
  2. Run `/pdeq-update`.
  3. Re-snapshot.
- **Expected Result**:
  - Exit non-zero (engineering: exit 2 specifically — assert exit code is exactly 2 to distinguish self-host refusal from other failure classes).
  - Output contains `✗ /pdeq-update is disabled inside the pdeq repository.` and references `CLAUDE.md §Bootstrap chain`.
  - Output contains the maintainer-flow numbered hint (1. cut a release; 2. advance `.pdeq/` to N-1 and run `/pdeq-migrate` against pdeq's own specs).
  - Output contains `/pdeq-update will not run. No files changed.`
  - `PRE_PIN_SHA == POST_PIN_SHA`. Working-tree hash unchanged. No symlink-sync ran. No migration ran.
  - The refusal triggers BEFORE any `git submodule update` call (assert via tracing or by ensuring the fixture's bare remote, even if reachable, was not contacted — e.g., remote-URL-not-reachable in this fixture should still produce the refusal message rather than Surface 14).

#### `/pdeq-update` prunes a dangling command symlink `TC-migrations-update-symlink-prune` `[auto]`

- **Type**: E2E
- **Covers**: `FR-migrations-update-in-session` (prune-half), `NFR-migrations-scope-minimalism` (cross-coverage)
- **Preconditions**: `update-deleted-command/` fixture. `<git-root>/.claude/commands/old.md` exists pre-run as a symlink whose target (`../../.pdeq/.claude/commands/old.md`) currently resolves. After bump the submodule no longer contains `old.md`, so the symlink dangles.
- **Steps**:
  1. Snapshot the file types and link targets of every entry in `<git-root>/.claude/commands/` and `<git-root>/scripts/`. Confirm `old.md` is a live symlink pre-run.
  2. Run `/pdeq-update` (or its automated shell-layer drive: `git submodule update --remote --force .pdeq`, then `scripts/sync-symlinks.sh --prune --json`, parse JSON, then iterate the migration loop).
  3. Re-snapshot the same directories. Capture the `--json` report.
- **Expected Result**:
  - `old.md` no longer exists in `<git-root>/.claude/commands/` — neither as a symlink nor as a regular file.
  - The `--json` report's `deleted` array contains `old.md`.
  - The final `/pdeq-update` summary line includes (or is consistent with — design omits a dedicated `Removed commands:` field, so absence from `New commands available:` and `Updated commands:` plus the JSON report is the assertion) the deletion. Output does not list `old.md` as new or updated.
  - Any non-symlink hand-authored file at `<git-root>/.claude/commands/<other>.md` (seed the fixture with one) is untouched: file type, content, and mtime preserved.
  - `pdeqVersion` advanced to `0.4.0`.
  - Exit 0.
- **Notes**: Engineering committed to pruning dangling symlinks (§In-session command availability, Step C: "We **do** clean up dangling symlinks"). If a future engineering revision flips that decision, this TC must be removed and replaced with an inverse assertion that dangling symlinks are preserved.

---

## Edge Cases & Error Scenarios

Adversarial exploration — things we expect to go wrong in the wild.

### Recorded version file corrupt

- **Trigger**: `pdeq.json` exists but is not valid JSON, or has `pdeqVersion` set to a non-semver string.
- **Expected behavior**: `/pdeq-migrate` refuses to run; output names the exact parse error and exits non-zero. No writes.
- **Test case**: `TC-migrations-unknown-format-error` covers the migration-file variant; a companion test (informal, can live in the engineering repo's unit tests) covers malformed `pdeq.json`.

### Migration script has a syntax error

- **Trigger**: Mechanical block points at a shell script that doesn't parse.
- **Expected behavior**: Identical to a runtime failure — `✗ mechanical    failed: …`, atomic bump preserved.
- **Test case**: Covered by `TC-migrations-atomic-bump-on-mechanical-fail` with a stub script that has a syntax error instead of an `exit 1`.

### User runs `/pdeq-migrate` without the submodule ever initialized

- **Trigger**: Fresh clone, `.pdeq/` is empty.
- **Expected behavior**: Clear error, no writes. Output tells the user to run `git submodule update --init`.
- **Test case**: Covered informally by a precondition check at run-start — if engineering adds a specific code path, add `TC-migrations-submodule-missing`.

### Non-semver `target-version` in migration frontmatter

- **Trigger**: Malicious/buggy migration file with `target-version: latest`.
- **Expected behavior**: Refused by the runner, identical handling to `TC-migrations-unknown-format-error`.

### Concurrent runs

- **Trigger**: User accidentally runs two `/pdeq-migrate` invocations in parallel on the same project.
- **Expected behavior**: Not specified by product or design. **Flag to product/design**: should the runner take a lockfile? For v1 treat as undefined behavior.

### Submodule bumped backward

- **Trigger**: Consumer rolled back `.pdeq` to an older release but kept their `pdeqVersion` at the newer value.
- **Expected behavior**: Surface 6 "recorded newer than pinned" output. Covered by `TC-migrations-newer-recorded-refused`.

---

## Regression Considerations

The migrations feature touches several existing pdeq mechanisms. When implementing or changing migrations, the following should be re-verified:

- **`pdeq.schema.json` — adding `pdeqVersion`**: re-run existing schema-validation tests to confirm the new field is optional-but-valid on pre-feature consumer configs. Bootstrap script (`scripts/init.sh`) should emit the field on new installs. Nested installs (`nested.repoRoot` present) should also emit the field.
- **`scripts/audit-traceability.sh`**: not expected to change, but any migration that rewrites slugs in specs must keep the index in sync — regression test that after a slug-rewriting migration, `audit-traceability.sh` still passes on the migrated fixture.
- **`/pdeq-kickoff` and `/pdeq-impact` slash commands**: must continue to work on projects that have run `/pdeq-migrate`. Add a smoke test post-migration.
- **Bootstrap agents and `bootstrap.sh`**: the bootstrap flow for new projects should produce a `pdeq.json` with `pdeqVersion` set to the current pinned version, so the first `/pdeq-migrate` is always a no-op.
- **Terminal output style**: the migrations feature introduces the `✗` and `•` glyphs. Ensure other pdeq commands' output style wasn't accidentally changed (sanity-diff `/pdeq-status` output before/after this feature lands).

---

## Gaps and Flags for Upstream

During test-plan drafting, the following were noted for product/design to resolve:

- ~~Non-breaking version advance behavior~~: resolved by `FR-migrations-nonbreaking-advance` and `AC-migrations-nonbreaking-advance` in product. Covered by `TC-migrations-nonbreaking-advance`.
- **Duplicate migration files for a version**: product and design don't address what happens if two migration files target the same version (e.g., accidental `0.4.0.md` and `0.4.0-hotfix.md`). Engineering needs to pick a rule; QA will assert whatever that rule is (test pinned in `TC-migrations-one-file-per-version`).
- ~~Missing migration file for a known-breaking version~~: resolved by `FR-migrations-missing-file-refused` and `AC-migrations-missing-file-refused` in product, with Surface 6 missing-migration-file sub-case in design. Covered by `TC-migrations-missing-file-refused`.
- **Concurrent `/pdeq-migrate` invocations**: no spec, no safety. Flag to product: decide if a lockfile is in scope.
- **Submodule not initialized**: not covered in design's precondition-error surface. Could reasonably extend Surface 6 to include a fourth sub-case, or accept as out-of-scope.
- **Color-disabled output equivalence**: design asserts `NO_COLOR` and screen-reader parity via glyphs. This is testable, but no AC exists for it specifically. Could add an acceptance criterion for color-disabled parity (e.g. AC-migrations-color-disabled-parity, unbackticked here because it's a proposed-but-undefined slug) or leave as an NFR.
- **`/pdeq-update --dry-run` while a previous `/pdeq-update` is mid-failure-recovery**: design Surface 13 describes dry-run on a clean pre-bump state. It doesn't describe what `/pdeq-update --dry-run` should print when the project is in a Surface 5 partial-migration state (pin already advanced by a prior `/pdeq-update`, recorded version partially advanced, some migrations still pending). Engineering's dry-run path is fetch-only and would mechanically produce a "no advance available" output, but the surface text for that intersection is unspecified. Flagged in `TC-migrations-update-dry-run`. Test pinned to clean pre-bump state for now.
- **`/pdeq-update` summary text for deleted commands**: design Surface 12 lists `New commands available:` and `Updated commands:` but does not introduce a `Removed commands:` line, even though engineering prunes dangling symlinks and the `--json` report's `deleted` array carries that data. `TC-migrations-update-symlink-prune` asserts the prune happened (filesystem + JSON report) but does not assert specific surface text for removal, because design has not specified any. If a maintainer wants user-visible removal feedback, that's a design change — not a QA invention.
