---
product-hash: 7e42c8798456b4865d3587297815795edd1881abf503cac093811f6011b752a7
product-slugs: [AC-migrations-absent-reported, AC-migrations-dry-run-accurate, AC-migrations-gate-allows-nonbreaking, AC-migrations-gate-blocks, AC-migrations-idempotent-rerun, AC-migrations-lineage-refused, AC-migrations-missing-file-refused, AC-migrations-no-bump-on-failure, AC-migrations-nonbreaking-advance, AC-migrations-noop-when-current, AC-migrations-ordered-apply, AC-migrations-scope-respected, AC-migrations-self-migration-runs, AC-migrations-semantic-context, AC-migrations-update-bump-failure, AC-migrations-update-dry-run, AC-migrations-update-end-to-end, AC-migrations-update-in-session, AC-migrations-update-noop, FR-migrations-absent-version, FR-migrations-atomic-bump, FR-migrations-author-written, FR-migrations-bootstrap-chain, FR-migrations-breaking-gate, FR-migrations-dry-run, FR-migrations-explicit-run, FR-migrations-failure-report, FR-migrations-idempotent, FR-migrations-lineage-integrity, FR-migrations-mechanical-block, FR-migrations-missing-file-refused, FR-migrations-no-false-positive, FR-migrations-nonbreaking-advance, FR-migrations-noop-when-current, FR-migrations-one-per-version, FR-migrations-order-within, FR-migrations-ordered, FR-migrations-ordered-application, FR-migrations-pending-detection, FR-migrations-recoverable-partial, FR-migrations-scoped-writes, FR-migrations-self-migration, FR-migrations-semantic-block, FR-migrations-unknown-version, FR-migrations-update-bump-failure, FR-migrations-update-bumps-pin, FR-migrations-update-chains, FR-migrations-update-command, FR-migrations-update-dry-run, FR-migrations-update-in-session, FR-migrations-update-noop, FR-migrations-version-bump, FR-migrations-version-field, FR-migrations-version-readable, NFR-migrations-determinism, NFR-migrations-enforcement-precision, NFR-migrations-idempotency, NFR-migrations-scope-minimalism]
---
# Migrations — CLI Technical Spec

> Based on requirements in `../../product/migrations.md`
> Based on design in `../../design/cli/migrations.md`

## What We're Building

The migrations feature adds an explicit upgrade contract between pdeq and consumer projects. Technically, it is (a) a new `pdeqVersion` field in `pdeq.json`, (b) a directory of author-written migration markdown files checked into the pdeq repo and surfaced to consumers through the existing `.pdeq` submodule, (c) a `/pdeq-migrate` slash command whose orchestration lives in a markdown file that Claude drives — delegating deterministic version math, file discovery, and idempotent mechanical edits to POSIX-compatible shell helpers in `scripts/` — and (d) a new pre-commit hook in the pdeq repo that blocks breaking version bumps without a matching migration file.

Two design decisions shape everything downstream. First, the runner is **Claude-orchestrated, not shell-orchestrated**: shell scripts cannot hand control back to an AI agent mid-run to execute a semantic block, so the `/pdeq-migrate` slash command itself loops across pending migrations, invoking shell helpers for mechanical work and reading the semantic prompt block inline to execute it. Second, scope enforcement is **author discipline + post-run audit**, not a sandboxed filesystem — a real sandbox is overkill for v1 and would complicate the hybrid Claude/shell execution model; a post-hoc check against the declared `scope:` frontmatter field is sufficient to catch author mistakes.

## Technical Approach

### Execution model — split between `/pdeq-migrate` (Claude) and shell helpers

The `/pdeq-migrate` slash command is the orchestrator. It is a markdown file at `.claude/commands/pdeq-migrate.md` that instructs Claude to:

1. Invoke `scripts/migrate.sh` subcommands (pure shell, no AI) to: read recorded and pinned versions, list pending migration files, parse a migration file's frontmatter and section table of contents, and bump the recorded version on success.
2. For each pending migration, execute the mechanical block by running the shell commands verbatim from the migration's `## Mechanical` section via the Bash tool.
3. If a `## Semantic` block is present and this is not a dry-run, read the declared `### Files` as context and execute the `### Prompt` inline as an agent pass — this is where judgment lives and why pure shell cannot do it.
4. After each migration finishes cleanly, call `scripts/migrate.sh bump <version>` to write the new recorded version. If a mechanical or semantic step fails, abort the loop and report the failure per the design's Surface 5 format.
5. Emit output matching the design's surfaces (status line, `▸` migration headers, `✓`/`~`/`✗`/`•` block status lines, trailing summary).

This split honors two constraints: POSIX shell is sufficient for everything deterministic (and has zero runtime dependencies beyond bash, which `init.sh` already assumes), while the semantic pass genuinely requires an AI agent and can only happen in Claude's execution context.

Satisfies `FR-migrations-explicit-run`, `FR-migrations-pending-detection`, `FR-migrations-ordered-application`, `FR-migrations-mechanical-block`, `FR-migrations-semantic-block`, `FR-migrations-order-within`, `AC-migrations-semantic-context`.

### Runtime constraints

- **No node, no python runtime dependency.** Everything shell-side is POSIX-compatible bash in the `scripts/init.sh` style (`set -euo pipefail`, colored output via `green`/`skip`/`warn` helpers, `shift`-based argv parsing).
- **Semver comparison is shell-native** (see §Version storage and comparison).
- **Env overrides for testability**: `PDEQ_MIGRATIONS_DIR`, `PDEQ_CONFIG_PATH`, `PDEQ_SPECS_ROOT`, `PDEQ_SEMANTIC_AGENT`, and `PDEQ_LINEAGE_FILE` override the default lookup paths and inject stubs so QA fixtures can exercise the runner end-to-end without touching a real `.pdeq` submodule or live Claude session. See §Testability hooks.

## Data Model

Three pieces of state are added or touched:

1. **`pdeqVersion` in `pdeq.json`** (new field) — the consumer's recorded conformance version. String, semver (MAJOR.MINOR.PATCH, no pre-release or build metadata in v1). Optional in the schema; absent = predates migrations (`FR-migrations-absent-version`).
2. **VERSION file at the pdeq repo root** (new file) — single-line semver, authoritative answer to "what version is this checkout of pdeq." Written by release tagging, read by `init.sh` and by the runner to determine the pinned version.
3. **Migration files at `.pdeq/migrations/<version>.md`** (new directory in pdeq repo) — one authored markdown file per breaking pdeq version, with the structure the design spec defines. Filename is the canonical source of the target version; frontmatter `target-version` must agree with filename (validated on parse).

The `pdeqVersion` field's semantics:

- **Write authority:** Written by `init.sh` on first install (initialized to the current pdeq VERSION). Written by `scripts/migrate.sh bump` after each successful migration. Never edited by an agent directly outside these code paths.
- **Read authority:** Read by `scripts/migrate.sh` (version math) and by any future pdeq command that behaves differently by version (`FR-migrations-version-readable`).
- **Absence semantics:** Absent field means "this project predates migrations." The runner does not silently treat this as `0.0.0`; it reports the absent state and blocks further action (matching design Surface 6 sub-case 1). This reconciles the product spec's "reported clearly" language with the design's "refuse to proceed" behavior — reporting and blocking happen together (`FR-migrations-absent-version`, `AC-migrations-absent-reported`).

## API / Interface Design

### `scripts/migrate.sh` subcommand surface

Single script, subcommand-dispatched. Every subcommand is non-interactive, prints to stdout in the design's glyph style on stderr for logs, exits non-zero on error.

| Subcommand | Args | Output | Purpose |
|---|---|---|---|
| `recorded` | — | `0.3.2` or empty | Prints the `pdeqVersion` from `pdeq.json`, or empty if absent. |
| `pinned` | — | `0.4.0` | Prints the pinned pdeq version (reads `.pdeq/VERSION` or equivalent). |
| `list-pending` | — | `0.3.0\n0.3.2\n0.4.0` | Prints pending migration versions, one per line, ascending semver. Empty if none. |
| `parse <file>` | migration path | machine-readable block | Prints frontmatter + section-heading table of contents for a migration file. Used by the `/pdeq-migrate` orchestrator to know whether `## Semantic` is present. |
| `bump <version>` | target version | — | Writes the new `pdeqVersion` back to `pdeq.json`. Fails if target is older than current recorded. |
| `check-lineage <version>` | pinned version | — | Verifies the recorded version appears in the pinned pdeq's tag history (or VERSION history). Non-zero if lineage mismatch. |
| `lineage-breaking <from> <to>` | exclusive-from, inclusive-to | `0.4.0\n0.5.0` | Prints versions declared breaking in the pinned lineage between `<from>` (exclusive) and `<to>` (inclusive). Empty if all intervening releases are non-breaking. Orchestrator uses this to distinguish non-breaking-advance (`FR-migrations-nonbreaking-advance`) from missing-file refusal (`FR-migrations-missing-file-refused`). |
| `audit-scope <migration>` | migration path | — | Post-run check: diffs `git status` against the migration's declared `scope:` and reports writes outside scope. |

All subcommands honor `PDEQ_CONFIG_PATH` (defaults to `./pdeq.json`) and `PDEQ_MIGRATIONS_DIR` (defaults to `.pdeq/migrations/`).

### Migration file parse contract

The design spec fixes the section vocabulary (`Context`, `Mechanical`, `Semantic` with `Files`/`Prompt` subsections, `Notes`). The `parse` subcommand emits a deterministic summary of a migration file:

```
target-version: 0.3.0
breaking: true
summary: Slugs change from FR-auth-1 to FR-auth-email-login.
scope: default
has-mechanical: true
has-semantic: true
semantic-files: product/**/*.md design/**/*.md engineering/**/*.md qa/**/*.md
```

The orchestrator uses this to decide whether to run a semantic pass (and, in dry-run, whether to print the "(absent)" line or the summary-only preview).

### `/pdeq-migrate` command-line surface

The slash command accepts the argument forms from design Surface 1: bare `/pdeq-migrate`, `/pdeq-migrate --dry-run`, `/pdeq-migrate --from <version>`. The orchestrator parses these from `$ARGUMENTS` inside `.claude/commands/pdeq-migrate.md`.

Satisfies `FR-migrations-dry-run`, `FR-migrations-explicit-run`.

## Component Architecture

### New files

| Path | Kind | Purpose |
|---|---|---|
| `VERSION` | file | Single-line semver at pdeq repo root — authoritative pdeq version. |
| `scripts/migrate.sh` | shell | Subcommand dispatcher for version math, file discovery, parsing, and version bump. |
| `scripts/audit-migrations.sh` | shell | Commit-msg hook — blocks breaking version bumps that lack a matching migration file. |
| `scripts/sync-symlinks.sh` | shell | Idempotent helper that creates missing symlinks under `<git-root>/scripts/` and `<git-root>/.claude/commands/` from the `.pdeq/` submodule, and (with `--prune`) removes dangling symlinks for files that no longer exist. Called by both `init.sh` Steps 5–6 and `.claude/commands/pdeq-update.md`. |
| `.claude/commands/pdeq-migrate.md` | markdown | `/pdeq-migrate` slash command — orchestrates the runner from Claude's execution context. |
| `.claude/commands/pdeq-update.md` | markdown | `/pdeq-update` slash command — orchestrates the consumer-facing upgrade flow: bump submodule, sync symlinks, chain into the migration loop. |
| `.pdeq/migrations/` | directory | Container for authored migration files. In the pdeq repo itself, this lives at `migrations/` at the repo root (see §Bootstrap chain). |
| `.pdeq/migrations/0.2.0.md` (first real migration) | markdown | The first authored migration file, created when the first breaking change after baseline lands. |

### Modified files

| Path | Change |
|---|---|
| `pdeq.schema.json` | Add optional `pdeqVersion` field (semver pattern). |
| `scripts/init.sh` | Always create `pdeq.json` (even in default-config cases) and populate `pdeqVersion` from the pdeq `VERSION` file. Refactor Steps 5–6 to call `scripts/sync-symlinks.sh` (without `--prune`) instead of the inline symlink loops, so init and update share one implementation of the symlink rules. |
| `CLAUDE.md` (root) | No behavior change; any future version-dependent coordinator behavior reads `pdeqVersion` via `scripts/migrate.sh recorded`. |
| `glossary.md` | Already contains the relevant terms — no change needed. |
| `.git/hooks/pre-commit` + `.git/hooks/commit-msg` (local, not checked in) | Document the two-hook composition: `pre-commit` runs `audit-traceability.sh` and `merge-decisions.sh`; `commit-msg` runs `audit-migrations.sh`. The pdeq repo does not currently check in any hooks; this spec proposes documenting the expected composition in a README-adjacent location (see §Commit-msg hook). |

### Migration discovery and ordering

Discovery is filesystem-driven: every `*.md` file in `$PDEQ_MIGRATIONS_DIR` is a candidate, with one exclusion. Files whose basename is `TEMPLATE.md` or `README.md`, or whose filename stem starts with `_`, are skipped — these are authoring aids, not migrations. Every other `*.md` file's filename-minus-extension must be a valid semver string (`^[0-9]+\.[0-9]+\.[0-9]+$`); files that fail validation are an error (not silently skipped) because they indicate author mistakes.

Ordering uses the shell-native semver comparator (see below). "Pending" is defined as `version > recorded AND version <= pinned`. The pinned bound matters: a submodule that contains migrations for versions newer than the pinned version (because, for example, a maintainer fat-fingered a partial checkout) should not apply those migrations.

Satisfies `FR-migrations-one-per-version`, `FR-migrations-ordered`, `NFR-migrations-determinism`.

## State Management

### Version storage and comparison

Recorded version is stored in `pdeq.json` at `$PDEQ_CONFIG_PATH`. Read and write use a minimal shell JSON approach: `pdeq.json` is small and flat enough that a `grep`/`sed` pair is acceptable and keeps us dependency-free. Example:

```bash
# Read pdeqVersion from pdeq.json (prints empty string if absent).
# Uses a tolerant regex that matches "pdeqVersion": "X.Y.Z" with any whitespace.
recorded_version() {
  local config="${PDEQ_CONFIG_PATH:-./pdeq.json}"
  [[ -f "$config" ]] || { echo ""; return; }
  sed -n 's/^[[:space:]]*"pdeqVersion"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$config" \
    | head -n 1
}
```

Write is also tolerant: if the field exists, rewrite in place; if absent, insert before the closing `}` with correct comma handling. Both operations are tested against the three example shapes in `pdeq.schema.json`.

Semver comparison uses `sort -V` — POSIX-universal, available on every macOS and Linux shell host pdeq targets, and correctly orders `0.3.0 < 0.3.2 < 0.4.0 < 0.10.0`. Two-value comparison wrapper:

```bash
# semver_cmp A B:
#   echoes -1 if A < B, 0 if equal, 1 if A > B.
semver_cmp() {
  local a="$1" b="$2"
  [[ "$a" == "$b" ]] && { echo 0; return; }
  local first
  first=$(printf '%s\n%s\n' "$a" "$b" | sort -V | head -n 1)
  [[ "$first" == "$a" ]] && echo -1 || echo 1
}
```

`sort -V` only orders plain MAJOR.MINOR.PATCH correctly; pre-release suffixes (`0.4.0-rc.1`) are out of scope for v1. If pdeq later ships release candidates, the comparator needs a reimplementation — flagged in §Open Technical Questions.

Pinned version is read from the checked-in pdeq's `VERSION` file. In a consumer project this is `$GIT_ROOT/.pdeq/VERSION`. In the pdeq repo itself it is `$GIT_ROOT/.pdeq/VERSION` (the self-pinned previous stable) while developing, and `$GIT_ROOT/VERSION` (the in-development version) when the maintainer is releasing (see §Bootstrap chain).

Satisfies `FR-migrations-version-field`, `FR-migrations-version-readable`, `NFR-migrations-determinism`.

### Atomic version bump — per-migration, not whole-run

The design spec requires that recorded version advance only to the last fully-applied migration on failure (`FR-migrations-atomic-bump`, `AC-migrations-no-bump-on-failure`, design Surface 5's "Recorded pdeq version: 0.3.0 (advanced from 0.2.1 — 0.3.0 applied cleanly)"). Two implementation strategies:

- **Per-migration bump (chosen).** After each migration completes cleanly, immediately call `scripts/migrate.sh bump <version>`. On failure mid-run, the recorded version is already at the last fully-applied migration; no rollback is needed. Resuming via `/pdeq-migrate` picks up from the now-recorded version.
- **Whole-run atomic bump (rejected).** Defer all version writes until every migration in the batch succeeds. Failures require rollback logic or leave recorded version behind last-applied — either violates the design's explicit "advanced to 0.3.0" output.

Per-migration bump is chosen because it directly realizes the design's observable behavior, makes partial runs resumable without special handling, and avoids any rollback machinery. Tradeoff: the `pdeq.json` file is rewritten once per migration in a multi-migration batch — noisy in `git status` but harmless, and the noise is a feature (it makes partial application visible).

Satisfies `FR-migrations-atomic-bump`, `FR-migrations-recoverable-partial`, `FR-migrations-version-bump`, `AC-migrations-no-bump-on-failure`.

### Non-breaking advance

When `list-pending` returns empty but `recorded < pinned` (all intervening releases were non-breaking — no files exist for any version in the `(recorded, pinned]` window), the orchestrator advances `pdeqVersion` directly to `pinned` in a single call to `scripts/migrate.sh bump`, and prints design Surface 3b. No mechanical or semantic work runs. This code path is distinct from no-op (`recorded == pinned`) and from pending-run (`list-pending` non-empty).

Satisfies `FR-migrations-nonbreaking-advance`, `AC-migrations-nonbreaking-advance`.

### Missing-file detection

For each breaking version in the pinned lineage that falls inside the pending window, a migration file MUST exist. The lineage declares breaking-ness via `scripts/migrate.sh lineage-breaking <version>` (reads either `$PDEQ_LINEAGE_FILE` when set, or a `.pdeq/LINEAGE` manifest — see §Open Technical Questions). The orchestrator enumerates breaking versions in the window and refuses to proceed if any expected file is absent, printing design Surface 6's missing-migration-file sub-case. The recorded version is not advanced. This is distinct from `FR-migrations-author-written` (authored is required; missing is a runtime refusal).

Satisfies `FR-migrations-missing-file-refused`, `AC-migrations-missing-file-refused`.

### Pending detection

Pseudocode for `list-pending`:

```bash
recorded=$(recorded_version)
pinned=$(pinned_version)

# Absent recorded → precondition error, not a migration run.
[[ -z "$recorded" ]] && { report_absent; exit 2; }

# Recorded > pinned → lineage/rollback error.
[[ "$(semver_cmp "$recorded" "$pinned")" == "1" ]] && { report_newer; exit 2; }

for f in "$PDEQ_MIGRATIONS_DIR"/*.md; do
  v=$(basename "$f" .md)
  # Strict semver filename check
  [[ "$v" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { warn "bad filename: $f"; exit 2; }
  # v > recorded AND v <= pinned
  if [[ "$(semver_cmp "$v" "$recorded")" == "1" && \
        "$(semver_cmp "$v" "$pinned")" != "1" ]]; then
    echo "$v"
  fi
done | sort -V
```

Satisfies `FR-migrations-pending-detection`, `NFR-migrations-determinism`.

## Error Handling

The design spec defines the user-facing failure surfaces (Surface 5 for mid-run failure, Surface 6 for precondition errors). Engineering maps them to concrete exit conditions:

| Error | Exit code | Exit path |
|---|---|---|
| Absent `pdeqVersion` | 2 (precondition) | `/pdeq-migrate` orchestrator prints Surface 6 sub-case 1 and stops. |
| Recorded > pinned | 2 | Surface 6 sub-case 2. |
| Foreign lineage | 2 | Surface 6 sub-case 3 — detected via `check-lineage` subcommand. |
| Mechanical block fails | 1 (run failure) | Orchestrator prints Surface 5, leaves filesystem as-is, does not bump version for the failing migration. |
| Semantic block fails | 1 | Same as mechanical — but mechanical for that migration has already run, so filesystem has partial writes from mechanical. This is correct per `FR-migrations-order-within`. |
| Malformed migration file | 2 | Parse error surfaces via `parse` subcommand; orchestrator refuses to proceed. |
| Bump target older than recorded | 2 | `bump` subcommand guard; prevents regression. |

**Recovery policy is leave-as-is.** No automatic rollback. The design spec Surface 5 explicitly prints `No rollback was performed. Your working tree is as the failing step left it — review git status to inspect.` Engineering implements this by doing nothing beyond the failure report — the consumer uses `git` to recover.

### Lineage verification (`check-lineage`)

The design spec's Surface 6 foreign-lineage sub-case is the trickiest. Detection approach:

- Read the pinned submodule's tag history (`git -C .pdeq tag --list`).
- If the recorded version does not appear as a tag in the pinned submodule's reachable history, lineage mismatch.
- Edge case: consumer's recorded version is older than the oldest tag in the pinned submodule (e.g., submodule was re-initialized against a shallow clone). Treat as lineage mismatch — the user's guidance in Surface 6 ("confirm the pdeq submodule URL") addresses it.

For the self-hosting pdeq repo, the "pinned submodule" is itself — `check-lineage` reads `.pdeq`'s tags. If the repo has no `.pdeq` submodule yet (pre-baseline — see §Bootstrap chain), `check-lineage` is a no-op success because there is nothing to verify against.

Satisfies `FR-migrations-lineage-integrity`, `FR-migrations-unknown-version`, `AC-migrations-lineage-refused`.

### Idempotency

Idempotency is mostly the author's responsibility — mechanical scripts must be written so that running them against already-migrated content is a no-op, and semantic prompts must include the "leave already-conformant files alone" instruction (design §7 Migration file format calls this out explicitly).

Engineering's contribution to idempotency:

- **No-op detection in `list-pending`.** When recorded == pinned, `list-pending` produces empty output; the orchestrator prints Surface 2 without invoking any migration's shell block. This gives idempotency a shortcut — re-running `/pdeq-migrate` after a clean run does literally nothing.
- **Per-migration bump** (§Atomic version bump) means the second run starts from the advanced recorded version; any already-applied migrations are outside the pending window.

Satisfies `FR-migrations-idempotent`, `FR-migrations-noop-when-current`, `NFR-migrations-idempotency`, `AC-migrations-noop-when-current`, `AC-migrations-idempotent-rerun`.

## Performance Considerations

Migrations are batch-invoked, not hot-path. The only performance-relevant concerns:

- **`sort -V` is O(n log n)** across migration count; migration counts are measured in single digits to low tens over the lifetime of pdeq. No concern.
- **Mechanical scripts' performance is the author's problem** — they run consumer-supplied shell code against the consumer's filesystem.
- **Semantic blocks' cost dominates** any real run. Per-migration semantic blocks are expected to read O(spec-file-count) bytes of context into Claude. Dry-run explicitly skips semantic execution (design Surface 4) — this is the single biggest performance lever and is already in the UX.

No caching, no parallelism. Migrations are ordered and sequential by design (`FR-migrations-ordered-application`).

## Security Considerations

### Trust model

Migration files are checked into the pdeq repo by pdeq maintainers and delivered to consumers via the submodule. The trust boundary is the same as trusting the pdeq repo itself — whoever owns the pdeq upstream can already ship arbitrary shell code via `scripts/*.sh`. Migration shell blocks are no worse.

### Scope enforcement — author discipline + post-run audit (chosen)

The design spec's `scope:` frontmatter field declares which paths a migration may write. Product requires that writes stay inside specs root + `pdeq.json` unless broader scope is declared up front (`FR-migrations-scoped-writes`, `AC-migrations-scope-respected`).

Two options considered:

- **Sandboxed filesystem (rejected).** Run the mechanical block in a container, chroot, or with an LD_PRELOAD write-intercepting shim, then rsync allowed paths back. Heavy, platform-specific, and the semantic block — which runs in Claude's context — cannot be easily sandboxed the same way. Would produce a system where mechanical writes are sandboxed but semantic writes are not, which is worse than a uniform policy.
- **Author discipline + post-run audit (chosen).** Author declares `scope:` in frontmatter. After the migration runs, `audit-scope` subcommand reads `git status --porcelain` and diffs the changed paths against the declared scope globs. If any writes landed outside, it reports the violation and exits non-zero — the orchestrator surfaces this as a failed migration even if the shell block itself exited 0.

This is "honor system + trailing verifier." It catches the common failure mode (author forgets to declare `scope: "**"` before writing to scripts/) without inventing new infrastructure. Tradeoff: a malicious or careless migration can still modify files before `audit-scope` runs, and `audit-scope` only catches it after the fact. Given the trust model above (maintainers are already trusted with arbitrary shell), this is acceptable for v1.

Scope glob syntax: same as `git` pathspec globs — `**` for recursive, `*` for single-segment, relative to repo root. Defaults (when `scope: default`) are `specsRoot/**` and `pdeq.json`. Broader scope is declared as a YAML list of globs:

```yaml
scope:
  - "**"       # whole repo — use sparingly
  - ".pdeq/**" # framework files only
```

Satisfies `FR-migrations-scoped-writes`, `NFR-migrations-scope-minimalism`, `AC-migrations-scope-respected`.

### Mechanical block execution model

Shell blocks from `## Mechanical` are executed via the Bash tool from inside the `/pdeq-migrate` slash command. They run with the consumer's shell environment unchanged — no attempt to strip env vars, no sandboxed PATH. This matches how `init.sh` and `audit-traceability.sh` are run today.

The orchestrator pins `cd` to the consumer's specs root before each mechanical block (`cd "$specsRoot"`) so relative paths in the migration work uniformly. Authors referring to `.pdeq/migrations/<version>/helper.sh` (companion shell scripts alongside the migration markdown) must use the `$PDEQ_MIGRATIONS_DIR` env var the orchestrator exports, not hard-coded paths.

## Commit-msg hook — `scripts/audit-migrations.sh`

### Scope and composition

This hook is **pdeq-repo only** — it never ships to consumers because consumers do not author migrations. It sits alongside `audit-traceability.sh` and `merge-decisions.sh` in `scripts/`. The pdeq repo's pre-commit hook composes all three.

Since the pdeq repo does not currently check in a pre-commit hook file (hooks live in `.git/hooks/` which is not tracked), this spec documents the expected composition but does not itself install it. Installing is out of scope here; maintainers wire the hook manually or via a `scripts/install-hooks.sh` helper (proposed as a small follow-up, not required for this feature).

### Detection logic

The hook fires only on commits in the pdeq repo. Algorithm:

```bash
# 1. Collect staged framework-file changes.
framework_changes=$(git diff --cached --name-only -- \
  'CLAUDE.md' '*/CLAUDE.md' 'scripts/*.sh' '.claude/commands/*.md' 'pdeq.schema.json')

# 2. Check whether VERSION is among the staged changes.
version_change=$(git diff --cached --name-only -- VERSION)

# 3. If neither, exit 0 (nothing interesting — gate is silent).
[[ -z "$framework_changes" && -z "$version_change" ]] && exit 0

# 4. If VERSION changed, determine old and new values.
old_ver=$(git show HEAD:VERSION 2>/dev/null | head -n 1 || echo "")
new_ver=$(cat VERSION)

# 5. Determine whether the bump is breaking.
#    "Breaking" = MAJOR or MINOR bump. PATCH bumps are assumed non-breaking.
#    If the maintainer asserts non-breaking via commit trailer, honor it.
#    The commit-msg hook receives the path to COMMIT_EDITMSG as $1 — the
#    pending commit's message. `git log -1` would read the PREVIOUS commit,
#    which is wrong here (the new message is not yet in git log).
COMMIT_MSG_FILE="${1:-}"
if [[ -z "$COMMIT_MSG_FILE" || ! -f "$COMMIT_MSG_FILE" ]]; then
  echo "[pdeq gate] commit-msg hook invoked without message path; aborting." >&2
  exit 1
fi
commit_msg=$(cat "$COMMIT_MSG_FILE")
if grep -qE '^pdeq-migration:[[:space:]]*none-required[[:space:]]*$' <<< "$commit_msg"; then
  echo "[pdeq gate] pdeq-migration: none-required — commit allowed."
  exit 0
fi

# 6. If breaking, require migrations/<new_ver>.md to be staged.
if is_breaking_bump "$old_ver" "$new_ver"; then
  if ! git diff --cached --name-only | grep -qxF "migrations/${new_ver}.md"; then
    print_gate_blocked_output "$old_ver" "$new_ver" "$framework_changes"
    exit 1
  fi
fi

exit 0
```

`is_breaking_bump` compares MAJOR and MINOR segments: any change in either is breaking. A PATCH-only bump (`0.3.1 → 0.3.2`) is assumed non-breaking and allowed through without a migration file. If a maintainer lands an accidentally-breaking PATCH change, the `pdeq-migration: none-required` trailer is the wrong tool — the fix is to re-version the change as MINOR and author the migration.

### Commit trailer extraction

The trailer `pdeq-migration: none-required` (design Surface 8 option C) is extracted with a literal regex, not `git interpret-trailers` — the latter is not available everywhere. The trailer must appear on its own line in the commit message, exactly matching `^pdeq-migration:\s*none-required\s*$`. Case-sensitive. Any appearance is recorded in the hook's output (design's "The gate will log this and allow the commit") by echoing `[pdeq gate] pdeq-migration: none-required — commit allowed.` to stderr.

The hook runs as a **`commit-msg` hook** because the trailer-override check needs the final commit message, which is only written to `.git/COMMIT_EDITMSG` by the time `commit-msg` fires (`pre-commit` runs earlier and cannot see message trailers reliably). Git invokes `commit-msg` with the path to `COMMIT_EDITMSG` as `$1`; the hook reads that file directly. `git log -1` would read the **previous** commit — wrong, since the new message is not yet in the log.

This departs from the `pre-commit` convention used elsewhere in pdeq (e.g., `audit-traceability.sh`); the composed-hook documentation calls out the split explicitly.

### Output format and path context

On block, stdout matches design Surface 8 exactly. On allow (trailer case), a single-line log. On non-matching commits (docs-only, non-framework, non-breaking), total silence (`NFR-migrations-enforcement-precision`).

**Path context in output.** The `expected: …` line names the filesystem path where the missing migration file would be. Because this hook runs **only inside the pdeq repo**, the printed path is always `migrations/<version>.md` — no `.pdeq/` prefix. (The `.pdeq/migrations/<version>.md` form shown in the design spec's Screen Inventory describes the **consumer-side** path where the same file is reached via the submodule; that form is used by the `/pdeq-migrate` runner's missing-file error, not by this gate.) Concretely the gate always uses the repo-local path, and the `/pdeq-migrate` orchestrator resolves its path from `$PDEQ_MIGRATIONS_DIR` (default `.pdeq/migrations/` for consumers). This split is what reconciles the two paths that appear in upstream specs.

Satisfies `FR-migrations-breaking-gate`, `FR-migrations-no-false-positive`, `NFR-migrations-enforcement-precision`, `AC-migrations-gate-blocks`, `AC-migrations-gate-allows-nonbreaking`.

## Bootstrap chain — pdeq managing itself

### Initial state — baseline

Currently pdeq has no `.pdeq` submodule; it **is** pdeq. There is no previous-stable version for the first migrations-capable release to pin against.

The bootstrap plan:

1. **Before this feature ships**, tag the current `main` as `v0.1.0`. This is the baseline — pdeq without migrations, without `pdeqVersion`, without a VERSION file.
2. **This feature lands in `v0.2.0`** (or whatever the next version is). The merge introduces: `VERSION` file with `0.2.0`, the `pdeqVersion` schema field, `scripts/migrate.sh`, `scripts/audit-migrations.sh`, `.claude/commands/pdeq-migrate.md`, `migrations/` directory, and `migrations/0.2.0.md` — the first authored migration. The 0.2.0 migration's job is to tell consumers "add `pdeqVersion: 0.2.0` to your `pdeq.json`" — mechanical block edits the file directly.
3. **After v0.2.0 is tagged**, the pdeq repo adds itself as a submodule: `git submodule add <self-url> .pdeq`, pinned to `v0.1.0`. The pdeq repo's own `pdeq.json` declares `pdeqVersion: 0.1.0` — the pdeq repo is now a consumer of pdeq-v0.1.0.
4. **On release of v0.3.0**: the maintainer bumps `VERSION` to `0.3.0`, authors `migrations/0.3.0.md`, ensures the `commit-msg` gate passes, commits, tags `v0.3.0`. Then bumps `.pdeq` submodule pin from `v0.1.0` → `v0.2.0` (the previous release, not v0.3.0 — pdeq is always a consumer of N-1), runs `/pdeq-migrate` against its own specs, commits the resulting diff.

### Why N-1, not N-2 or N

- **N (self-pinning to the in-development version).** Rejected — the whole point of the bootstrap chain is that the framework is managed by a **stable** version, not the version under active development. If pdeq pins itself to itself, every framework edit immediately takes effect for the maintainer's own kickoff runs, defeating the dogfood property (`FR-migrations-bootstrap-chain`).
- **N-1 (chosen).** The maintainer works on `v(N).0` edits in the framework source (root `CLAUDE.md`, `scripts/`, `.claude/commands/`). Their own kickoff runs, status runs, etc., execute against `.pdeq/CLAUDE.md` — which is v(N-1). Framework edits under development do **not** affect the maintainer's own workflow until the next release cycle.
- **N-2.** No benefit; lags the bootstrap chain further behind for no additional property.

### Filesystem layout during development

In the pdeq repo, two directories coexist:

| Location | Contents | Role |
|---|---|---|
| `<repo-root>/CLAUDE.md`, `scripts/`, `.claude/commands/`, `migrations/`, `pdeq.schema.json`, `VERSION` | Framework source being developed | What ships to consumers via submodule |
| `<repo-root>/.pdeq/` | Submodule pinned to v(N-1) | Pdeq's own agent imports resolve here |

The root `CLAUDE.md` at pdeq's repo root is both the framework source (copied into consumer projects via init.sh, which wires `@.pdeq/CLAUDE.md`) and — once the submodule exists — the pdeq repo's own root `CLAUDE.md` starts with `@.pdeq/CLAUDE.md` (importing the v(N-1) coordinator) followed by project-specific overrides, if any. The two uses do not collide because consumers never see pdeq's self-configured root `CLAUDE.md` — they see the framework-source one that init.sh assembles.

**Note:** There is a subtle choice here — does pdeq's own `product/CLAUDE.md` etc. `@.pdeq/product/CLAUDE.md`, or live directly at `product/CLAUDE.md` as authored? For now, the in-repo framework source files are the authoritative version (what ships), and they will be gradually rewritten to live as-if-submoduled once `.pdeq` exists. This is tracked in §Open Technical Questions.

### Release flow script

A helper `scripts/release.sh` is **not** part of this feature, but the flow is documented here so the dogfood story is end-to-end:

```text
# Maintainer, ready to ship v0.3.0:
echo "0.3.0" > VERSION
# Author migrations/0.3.0.md
git add VERSION migrations/0.3.0.md <other framework changes>
git commit -m "Release v0.3.0 — <summary>"   # commit-msg gate validates
git tag v0.3.0
git push origin main --tags

# Then, pdeq-as-its-own-consumer:
cd .pdeq && git fetch && git checkout v0.2.0 && cd -   # bump pin to N-1
# Update pdeq.json pdeqVersion to 0.2.0 was already done; now run:
/pdeq-migrate   # executes migrations/0.2.0.md against pdeq's own specs
git add pdeq.json .pdeq <migrated spec files>
git commit -m "Bump self-pdeq to v0.2.0"
```

Satisfies `FR-migrations-bootstrap-chain`, `FR-migrations-self-migration`, `AC-migrations-self-migration-runs`.

## `/pdeq-migrate` slash command markdown

### Location

`.claude/commands/pdeq-migrate.md` at the pdeq repo root. Symlinked into consumer projects by `init.sh`'s Step 6 (which already symlinks everything in `.pdeq/.claude/commands/*`).

### Contents (shape, not verbatim)

The file follows the `pdeq-kickoff.md` / `pdeq-bootstrap.md` / `pdeq-status.md` conventions already established in `.claude/commands/`:

1. **Header** — `# Migrate: $ARGUMENTS` and one-sentence description.
2. **Step 0: Parse arguments.** Flags: `--dry-run`, `--from <version>`.
3. **Step 1: Read config.** Invoke `scripts/migrate.sh recorded` and `scripts/migrate.sh pinned`. Emit the status line (`pdeq: recorded X → pinned Y`).
4. **Step 2: Precondition checks.** Absent recorded → print Surface 6 sub-case 1, exit. Recorded > pinned → Surface 6 sub-case 2. Invoke `scripts/migrate.sh check-lineage` → Surface 6 sub-case 3 on failure.
5. **Step 3: List pending + breaking-in-window check.** Invoke `scripts/migrate.sh list-pending` and `scripts/migrate.sh lineage-breaking <recorded> <pinned>`.
   - Both empty **and** `recorded == pinned` → Surface 2 no-op output, exit 0.
   - Both empty **and** `recorded < pinned` → Surface 3b non-breaking-advance: invoke `bump <pinned>`, exit 0 (`FR-migrations-nonbreaking-advance`).
   - `lineage-breaking` names versions that are NOT present as files in `$PDEQ_MIGRATIONS_DIR` → Surface 6 missing-file sub-case, exit non-zero, no bump (`FR-migrations-missing-file-refused`).
   - `list-pending` non-empty → proceed to Step 4.
6. **Step 4: For each pending migration, in order:**
   - Invoke `scripts/migrate.sh parse <file>` — get `has-mechanical`, `has-semantic`, `scope`, `summary`.
   - Print `▸ <version> — <summary>`.
   - **Mechanical:** if present, execute each shell block in `## Mechanical` via Bash tool (or print `would …` lines if `--dry-run`). On non-zero exit, print Surface 5 failure output and stop.
   - **Semantic:** if present and not dry-run, read the files in `### Files`, execute the `### Prompt` inline as an agent pass, emit `✓ semantic  reviewed N files, updated M`. If dry-run, print the summary-only notice from design Surface 4. If absent, print `~ semantic  no semantic block`.
   - **Scope audit:** invoke `scripts/migrate.sh audit-scope <file>`. On violation, surface as a failed migration.
   - **Bump:** on clean completion, invoke `scripts/migrate.sh bump <version>`.
7. **Step 5: Print trailing summary.** Success: design's `✓ pdeq: recorded X → Y` + "Ran N migrations".

The markdown itself is procedural — it instructs Claude the same way `pdeq-kickoff.md` does, not a template to be filled in.

Satisfies `FR-migrations-explicit-run`, `FR-migrations-ordered-application`, `FR-migrations-order-within`, `FR-migrations-dry-run`, `FR-migrations-version-bump`, `FR-migrations-failure-report`, `AC-migrations-ordered-apply`, `AC-migrations-dry-run-accurate`, `AC-migrations-semantic-context`.

## Upgrade Entrypoint

`/pdeq-update` is the consumer-facing wrapper that combines the submodule bump and the `/pdeq-migrate` run into a single invocation. Like `/pdeq-migrate`, it is a **prompt-driven runner**: shell helpers do the deterministic git plumbing, the model orchestrates the loop and prints output. The two commands are deliberately separate slash commands rather than one with a `--bump` flag — design's command-name decision is binding here, and engineering reuses the runner pattern rather than reimplementing it.

### Command shape and location

The slash command lives at `.claude/commands/pdeq-update.md` in consumer projects, symlinked from `.pdeq/.claude/commands/pdeq-update.md` by the existing `init.sh` Step 6 loop (which is filesystem-driven and picks up new files automatically — no init.sh change needed for the command file itself). In the pdeq repo's self-host context, `pdeq-update.md` lives at `<repo-root>/.claude/commands/pdeq-update.md` and ships through the same submodule mechanism as every other command.

Argument surface (parsed from `$ARGUMENTS` inside `pdeq-update.md`):

| Form | Meaning |
|---|---|
| (empty) | Bump pin, then chain into the migration loop. |
| `--dry-run` | Preview the bump target and the migrations a real `/pdeq-update` would queue. No git writes, no migration runs, no symlink changes. |

No `--from`, no `--yes` flag (auto-run handoff is fixed by design Surface 12).

Satisfies `FR-migrations-update-command`.

### Bump implementation

The bump step runs `git submodule update --remote .pdeq` from `$GIT_ROOT`, then reads the post-bump `.pdeq/VERSION` to learn the target version. Per-step:

1. **Capture pre-bump state.**

   ```bash
   PRE_PIN_SHA=$(git -C .pdeq rev-parse HEAD)
   PRE_PINNED=$(scripts/migrate.sh pinned)   # reads .pdeq/VERSION
   ```

2. **Advance the submodule.**

   ```bash
   git submodule update --remote --force .pdeq
   ```

   `--force` discards local commits inside the submodule (the consumer should not be authoring inside `.pdeq/`); `--remote` follows the configured `branch` for the submodule (defaults to the tracking branch in `.gitmodules`, conventionally `main` or a `release/*` line — engineering does not own picking the line; that's submodule-config).

3. **Capture post-bump state.**

   ```bash
   POST_PIN_SHA=$(git -C .pdeq rev-parse HEAD)
   POST_PINNED=$(scripts/migrate.sh pinned)
   ```

4. **No-op detection.** If `PRE_PIN_SHA == POST_PIN_SHA`, the remote tracking branch had no new commits — nothing was bumped. The runner short-circuits to design Surface 11 (`~ Already at <PINNED>`) and exits 0 without invoking `/pdeq-migrate`. We compare submodule SHAs rather than VERSION strings because two consecutive releases with the same VERSION (mid-development snapshots) should still be treated as no-op when the SHA matches; conversely, a SHA-only advance with no VERSION change is also a no-op for migration purposes (recorded version cannot move past pinned, and pinned didn't move). The user-visible "version" used in the surface line is `$POST_PINNED`.

   Satisfies `FR-migrations-update-noop`, `AC-migrations-update-noop`.

5. **Failure modes during the bump:**

   | Failure | Detection | Surface |
   |---|---|---|
   | Network unreachable | `git submodule update --remote` non-zero exit; stderr contains `unable to access`, `Could not resolve host`, or similar | Design Surface 14 — `✗ failed: could not fetch latest pdeq reference.` followed by the captured stderr. |
   | Auth failure on remote | non-zero exit; stderr names credentials or 401/403 | Same Surface 14 with the captured stderr. |
   | Submodule URL misconfigured | non-zero exit; stderr names the URL | Same Surface 14. |
   | Detached-head state inside submodule with uncommitted changes | non-zero exit before fetch | Same Surface 14 with a hint to `git -C .pdeq status`. |
   | Fetch succeeded but checkout failed (rare — divergent local refs) | post-`update` exit non-zero, but `PRE_PIN_SHA != POST_PIN_SHA` could not be established | Surface 14, treat as bump failure; do not write recorded version. |

   In every failure case: the recorded `pdeqVersion` is **not** advanced (the bump step lives entirely outside `scripts/migrate.sh bump`), `/pdeq-migrate` is **not** invoked, and the working tree's only mutation is whatever `git submodule update` did internally (which the user can inspect via `git status`). Per design Surface 14 there is no "rollback was performed" line — the bump is atomic-or-not at the git level.

   Satisfies `FR-migrations-update-bump-failure`, `AC-migrations-update-bump-failure`.

The bump shell can be inlined in `pdeq-update.md`'s prompt body or factored into a small `scripts/update.sh bump-pin` helper. We choose **inline** in `pdeq-update.md` (matching the `/pdeq-migrate` precedent of "deterministic shell-only helpers in `scripts/migrate.sh`, prompt orchestration in `.claude/commands/pdeq-migrate.md`"), with the failure-detection guards expressed as bash conditionals the model executes via the Bash tool. If a future maintainer finds the bump logic getting too large to embed comfortably, factor to `scripts/update.sh` then — the command file is the orchestrator, not the algorithm host.

Satisfies `FR-migrations-update-bumps-pin`, `FR-migrations-update-bump-failure`.

### Chained migration — approach A (inline reuse), chosen

Two viable approaches were considered:

- **A) Inline reuse (chosen).** `pdeq-update.md` is structurally a superset of `pdeq-migrate.md`'s prompt. After the bump succeeds, the same loop pattern (Steps 1–5 of `pdeq-migrate.md`) runs in the same prompt with the same shell helpers (`scripts/migrate.sh list-pending`, `parse`, `bump`, `audit-scope`). The migrate steps are duplicated in the update prompt body, indented two spaces under a `▸ Migrating` lead-in to match design Surface 12's nested visual.
- **B) Delegation.** `pdeq-update.md` ends with an instruction to "now run /pdeq-migrate" or invokes `/pdeq-migrate` as a subagent. Rejected because: (i) Claude Code does not have a stable in-prompt mechanism for one slash command to invoke another mid-execution as a structured call, only as a prose instruction the model may or may not follow verbatim; (ii) the chained migrate run needs to share state (`PINNED`, `POST_PIN_SHA`, the in-session symlink-sync result) with the bump preamble, which requires either env-var passing through a Bash subshell or repeated re-discovery; (iii) the surface output is meant to read as one continuous flow, not two distinct command invocations stitched together.

Choice rationale: the migration loop is already prompt-driven and the pdeq-migrate.md prompt is short enough (~150 lines) that duplicating the relevant Steps 4–5 inside pdeq-update.md is cheaper than designing a delegation protocol. The duplication is bounded — the shared logic lives in `scripts/migrate.sh` subcommands, which both prompts call identically. If the migrate prompt grows substantially in the future, a `scripts/migrate.sh run-loop` umbrella subcommand could be introduced and both prompts call it — but that refactor is deferred until needed.

`pdeq-update.md` reuses Surface 5 (mid-migration failure) verbatim — the chained run is not re-skinned. If a migration fails after a successful bump, the failing block's `✗` line is printed at the chained-region's two-space indent (so it stays visually attached to its `▸ <version>` migration header), then the runner emits a single blank line, **drops the indent prefix**, and prints Surface 5's `✗ Migration X.Y.Z failed at the <block> step.` summary plus its `pdeq: recorded …` / `Pinned pdeq version: …` / `Remaining: …` / `What to do:` recovery text left-aligned. The final `✓ pdeq: updated to …` summary is not printed — the run failed. Implementation note: the inline-reuse loop carries the indent as a prefix string (`"  "`) it prepends to each emitted line; on chained failure, the prefix is reset to empty after the failing-block line is emitted, before the Surface 5 summary block runs. The user fixes the cause and re-runs `/pdeq-update`; on re-run the bump step short-circuits to no-op (pin already at `POST_PINNED`), the migration loop resumes from the last fully-applied migration via the existing per-migration bump semantics. No bespoke recovery path needed.

Satisfies `FR-migrations-update-chains`, `AC-migrations-update-end-to-end`.

### In-session command availability

This is the novel piece. Two sub-problems:

#### 1. Symlink sync after the bump

Today, `init.sh` Steps 5–6 symlink every `*` in `.pdeq/scripts/` and `.pdeq/.claude/commands/` into `<git-root>/scripts/` and `<git-root>/.claude/commands/`. The symlink targets are relative paths into the submodule (e.g., `scripts/migrate.sh -> ../.pdeq/scripts/migrate.sh`), so when `git submodule update --remote` advances `.pdeq/`, the symlink targets resolve to the **new** files automatically — **modified** commands and scripts pick up content changes for free with no re-symlinking.

The problem is **new** files: a bumped pdeq version that introduces, say, `.pdeq/.claude/commands/foo.md` and `.pdeq/scripts/foo.sh` ships those into the submodule, but `<git-root>/.claude/commands/foo.md` and `<git-root>/scripts/foo.sh` do not exist yet — no symlink, no command. Conversely, **deleted** files leave dangling symlinks (the target no longer exists in the new submodule content).

The `/pdeq-update` runner handles both cases by re-running the same idempotent symlink loop init.sh already implements, between the bump and the migration loop:

```bash
# Sync symlinks after the bump. This mirrors init.sh Steps 5 and 6 but is
# idempotent — every iteration uses the `[[ -e || -L ]]` guard from init.sh
# to skip already-linked files.

NEW_COMMANDS=()
NEW_SCRIPTS=()

# Step A: scripts/
for src in .pdeq/scripts/*; do
  name=$(basename "$src")
  dest="scripts/$name"
  if [[ ! -e "$dest" && ! -L "$dest" ]]; then
    ln -s "../.pdeq/scripts/$name" "$dest"
    NEW_SCRIPTS+=("$name")
  fi
done

# Step B: .claude/commands/
for src in .pdeq/.claude/commands/*; do
  name=$(basename "$src")
  dest=".claude/commands/$name"
  if [[ ! -e "$dest" && ! -L "$dest" ]]; then
    ln -s "../../.pdeq/.claude/commands/$name" "$dest"
    NEW_COMMANDS+=("$name")
  fi
done

# Step C: prune dangling symlinks (deleted commands/scripts)
DELETED_COMMANDS=()
for dest in .claude/commands/*; do
  if [[ -L "$dest" && ! -e "$dest" ]]; then
    rm "$dest"
    DELETED_COMMANDS+=("$(basename "$dest")")
  fi
done
DELETED_SCRIPTS=()
for dest in scripts/*; do
  if [[ -L "$dest" && ! -e "$dest" ]]; then
    rm "$dest"
    DELETED_SCRIPTS+=("$(basename "$dest")")
  fi
done
```

We **do** clean up dangling symlinks (Step C). Leaving them is worse than the alternative — a dangling `.claude/commands/foo.md` symlink can confuse the harness's command discovery and a dangling `scripts/foo.sh` is an obvious foot-gun for any `for f in scripts/*; do …` consumer code. Pruning is cheap, idempotent, and bounded to symlinks-only (`-L` test) so a consumer's hand-authored real file at the same path is never touched.

**Factoring decision.** This logic is duplicated between init.sh Steps 5–6 and the update runner's sync step. We factor it into a new helper `scripts/sync-symlinks.sh` with one entry point:

```
scripts/sync-symlinks.sh
  --pdeq-dir <path-to-submodule>     # default ".pdeq"
  --git-root <path>                  # default $(git rev-parse --show-toplevel)
  --prune                            # also prune dangling symlinks (default off)
  --json                             # emit a JSON report of {created, deleted}
                                     # for the runner to parse — when omitted,
                                     # output is in the init.sh green/skip style
```

`init.sh` calls `scripts/sync-symlinks.sh` without `--prune` (initial install never has anything to prune) and without `--json` (so its output matches the existing green/skip cosmetic). `pdeq-update.md`'s prompt calls `scripts/sync-symlinks.sh --prune --json` and parses the report into the `New commands available:` / `Updated commands:` / final-summary lists. Existing init.sh Steps 5 and 6 are rewritten as a single call to this helper for parity.

Satisfies `FR-migrations-update-in-session` (mechanism part).

#### 2. Harness re-reads commands from disk lazily

Claude Code's harness (this assistant) reads slash command definitions from `.claude/commands/*.md` **at session start** to populate the autocomplete menu, but reads the file **content** lazily — only when the command is actually invoked. This means:

- A command file that **already existed** at session start and is **modified** by the bump (its symlink target now points to new content): invocable in the same session with the new behavior. The user does not need to restart.
- A command file that **did not exist** at session start and is **created** by the symlink sync: the autocomplete menu does not show it for the rest of the current session, **but invoking it by literal slash-name (`/foo`)** triggers fresh disk lookup and works. The harness does not maintain a deny-list of "commands that didn't exist at startup"; absence is checked on-demand via filesystem read.
- A command file that existed at session start and is deleted: subsequent invocations 404 cleanly, matching the deleted-symlink prune behavior above.

This was verified empirically (test: create `.claude/commands/test-fresh.md` mid-session, type `/test-fresh`; the command runs). The autocomplete-staleness tradeoff is acceptable — design Surface 12's `New commands available: /foo, /bar` final summary line tells the user the exact names to type, which means the user does not depend on autocomplete to discover them. We document this in the runner output and rely on the user reading the summary line.

The relevant text the runner prints, drawn from the JSON report and matching design Surface 12:

```
✓ pdeq: updated to <POST_PINNED>
  New commands available: /<name>, /<name>
  Updated commands: /<name>
  Review the diff before committing.
```

If both `NEW_COMMANDS` and the set of file-content-changed commands (computed via `git -C .pdeq diff --name-only $PRE_PIN_SHA $POST_PIN_SHA -- '.claude/commands/*.md'`) are empty, both lines are omitted and the summary collapses to just `✓ pdeq: updated to <POST_PINNED>` and the diff-reminder line. If only `NEW_COMMANDS` is empty but updated commands exist, only `Updated commands:` is printed, etc.

**No process-restart hint is needed.** Earlier drafts of this spec considered printing `(restart your session to see these in autocomplete)` after the new-commands line, but this is misleading: the commands are *invocable* immediately by typing the name. Autocomplete is a discovery affordance, not a correctness condition. We omit the hint to keep the surface uncluttered.

Satisfies `FR-migrations-update-in-session`, `AC-migrations-update-in-session`.

### Self-host context

Inside the pdeq repo itself, `/pdeq-update` behaves differently from a consumer because pdeq's `.pdeq/` submodule is intentionally pinned to a previous-stable version (N-1) for the bootstrap chain — bumping it to whatever is on `main` would defeat the dogfood property (see §Bootstrap chain). Two options were considered:

- **Refuse with a maintainer-flow hint (chosen).** Inside the pdeq repo, `/pdeq-update` detects self-host context (presence of root-level `VERSION` and a `.pdeq/` submodule whose remote URL matches the current repo, computed via `git config --file .gitmodules submodule..pdeq.url` and comparing to `git config --get remote.origin.url`) and prints a refusal:

  ```
  ✗ /pdeq-update is disabled inside the pdeq repository.

    The pdeq repo's .pdeq/ submodule is intentionally pinned to a previous-stable
    version for the bootstrap chain — see CLAUDE.md §Bootstrap chain.

    Maintainer flow:
      1. Cut a release: bump VERSION, author migrations/<version>.md, tag.
      2. After the new release is tagged, manually advance .pdeq/ to N-1
         (the version just before this one) and run /pdeq-migrate against pdeq's
         own specs.

    /pdeq-update will not run. No files changed.
  ```

  Exit 2.

- **Bump `.pdeq/` to next-stable-N-1.** Rejected. It conflates the maintainer's deliberate "I am cutting a release and advancing the dogfood pin" workflow with the consumer's "I want the latest" workflow. The former is sequenced (release first, then advance pin, then self-migrate); the latter is one-shot. Hiding the maintainer flow behind a consumer-shaped command obscures the bootstrap chain rather than honoring it.

The self-host detection check is wrapped in a single guard at the top of `pdeq-update.md`'s prompt body, before any bump work begins. The detection is conservative — if the URL comparison is ambiguous (e.g., `.gitmodules` is missing), default to consumer behavior (running `/pdeq-update` in a consumer project that for some reason lacks `.gitmodules` is an unusual but recoverable state; refusing inside a pdeq fork that has a slightly different remote URL would be a worse failure mode).

Satisfies `FR-migrations-update-command` (self-host edge case).

### `/pdeq-update` slash command markdown — structural outline

`.claude/commands/pdeq-update.md` follows the `pdeq-migrate.md` shape:

1. **Header** — `# Update: $ARGUMENTS` and one-sentence description.
2. **Step 0: Parse arguments.** `--dry-run` only.
3. **Step 0b: Self-host guard.** Detect pdeq-repo context; refuse with the message above if matched.
4. **Step 1: Capture pre-bump state.** `PRE_PIN_SHA`, `PRE_PINNED`. Print the opening status line `pdeq: pinned <PRE_PINNED> → available …` (in dry-run, append `[DRY RUN — no writes]`).
5. **Step 2: Advance the pin (or, in dry-run, fetch-only to learn the target).**
   - Real run: `git submodule update --remote --force .pdeq`. Failure → Surface 14, exit 1.
   - Dry-run: first, check for partial-failure recovery state — if `scripts/migrate.sh recorded` < `scripts/migrate.sh pinned` AND `scripts/migrate.sh list-pending` is non-empty, the project is in a Surface 5 mid-recovery state. Print the design Surface 13 "Dry-run refused during partial-failure recovery" output (recorded, pinned, pending list, "run /pdeq-migrate first" hint), exit 1, do not run `git fetch`. Otherwise: `git -C .pdeq fetch && git -C .pdeq rev-parse origin/HEAD` to learn the would-be target without checking it out. Print the would-advance line. Skip Steps 3 and 4 entirely; print Surface 13 trailer; exit 0. Detection reuses `scripts/migrate.sh recorded`, `pinned`, and `list-pending` — no new helper subcommand is required, and the refusal happens before any network work so an offline mid-recovery consumer still gets a clear message rather than a network-error surface.
6. **Step 3: Detect no-op.** If `PRE_PIN_SHA == POST_PIN_SHA`, print Surface 11 `~ Already at <POST_PINNED>` and exit 0.
7. **Step 4: Sync symlinks.** Invoke `scripts/sync-symlinks.sh --prune --json`, parse the report into `NEW_COMMANDS`, `DELETED_COMMANDS`, `NEW_SCRIPTS`, `DELETED_SCRIPTS`. Compute updated-commands set from the submodule diff.
8. **Step 5: Chain into migration loop.** Print `▸ Migrating` lead-in. Inline-execute the equivalent of `pdeq-migrate.md` Steps 1–5 with two-space added indentation. On `/pdeq-migrate` failure → Surface 5 (within the `▸ Migrating` block); the runner exits 1 there. The bump is **not** undone — the user fixes the cause and re-runs `/pdeq-update`, which short-circuits the bump (Step 3) and resumes the migration loop.
9. **Step 6: Final summary.** Print `✓ pdeq: updated to <POST_PINNED>` plus the conditional `New commands available:` / `Updated commands:` lines plus the diff reminder.

Argument forms (`/pdeq-update`, `/pdeq-update --dry-run`) and exit codes (0 success/no-op/dry-run, 1 bump or migrate failure, 2 self-host refusal) match the design surfaces 1:1.

Satisfies `FR-migrations-update-command`, `FR-migrations-update-bumps-pin`, `FR-migrations-update-chains`, `FR-migrations-update-in-session`, `FR-migrations-update-noop`, `FR-migrations-update-bump-failure`, `FR-migrations-update-dry-run`.

## init.sh changes

Three changes, all minimal:

1. **Always generate `pdeq.json`**, even for default configs. Today `init.sh` only writes `pdeq.json` when non-default values are set (Step 9's `NEEDS_CONFIG` guard). With `pdeqVersion` now a required-at-runtime field for migrations to work, every consumer needs the file.
2. **Populate `pdeqVersion`** in the generated JSON, reading the version from `$PDEQ_PATH/VERSION`:

   ```bash
   PDEQ_VERSION=$(cat "$PDEQ_PATH/VERSION" 2>/dev/null | head -n 1 || echo "")
   # include "pdeqVersion": "$PDEQ_VERSION" in the JSON emit
   ```

3. **Symlink `migrations/`** so consumers can reach migration files through the same symlink pattern used for scripts and commands. The existing `Step 5` already symlinks `scripts/*`; migrations live in `.pdeq/migrations/` directly (accessed by the runner via `$PDEQ_MIGRATIONS_DIR=.pdeq/migrations/`). **No symlink is needed** — the runner reads migration files from the submodule path directly, the same way it would read any other submodule content. This simplifies init.sh and matches how the design spec describes `.pdeq/migrations/<version>.md`.

init.sh-level VERSION handling: if `.pdeq/VERSION` is missing (e.g., installing against a pre-v0.2.0 submodule), `pdeqVersion` is emitted as empty string — the `/pdeq-migrate` precondition handler then walks the consumer through the absent-version flow on their first upgrade attempt.

Satisfies `FR-migrations-version-field`, `FR-migrations-absent-version`.

## Schema change — `pdeq.schema.json`

The explicit schema edit:

```json
"pdeqVersion": {
  "type": "string",
  "description": "Pdeq version that this project's specs and config conform to. Set by scripts/init.sh on install and updated by /pdeq-migrate. A missing value means the project predates the migrations feature.",
  "pattern": "^[0-9]+\\.[0-9]+\\.[0-9]+$",
  "examples": ["0.2.0", "0.4.0", "1.0.0"]
}
```

Added to the `properties` block, not listed in any `required` array. Pattern is strict MAJOR.MINOR.PATCH — no pre-release, no build metadata, matching §State Management's `sort -V` comparator assumption.

Satisfies `FR-migrations-version-field`.

## Testability hooks

QA's fixture-based tests need to point the runner at canned state. Five env overrides are recognized:

- **`PDEQ_CONFIG_PATH`** — overrides `pdeq.json` lookup. Default `./pdeq.json`. Used by `recorded` and `bump` subcommands and by the precondition checks.
- **`PDEQ_MIGRATIONS_DIR`** — overrides migrations directory lookup. Default `.pdeq/migrations/` in consumer context, `migrations/` in pdeq-repo context (see §Commit-msg hook path context). Used by `list-pending` and `parse`.
- **`PDEQ_SPECS_ROOT`** — overrides specs-root lookup for the orchestrator's `cd` step before mechanical blocks and for `audit-scope`'s default-scope glob expansion. Default: value of `specsRoot` in `pdeq.json`, or `.` if absent.
- **`PDEQ_SEMANTIC_AGENT`** — path to a stub executable invoked by the orchestrator in place of a live Claude semantic pass. When set, the orchestrator runs `$PDEQ_SEMANTIC_AGENT` with the migration's `### Files` globs expanded on stdin and the `### Prompt` as an argv/stdin payload; the stub's exit code and stdout determine the semantic block's result. When unset (default), the orchestrator performs the normal inline agent pass. QA uses this to make semantic-block behavior deterministic across runs.
- **`PDEQ_LINEAGE_FILE`** — overrides lineage detection for `check-lineage`. When set, its contents are a newline-delimited list of versions considered in-lineage; `check-lineage` treats any version outside this list as foreign. When unset (default), `check-lineage` reads `git -C .pdeq tag --list`. QA uses this to fake foreign-lineage conditions without manipulating git.

All overrides are read at the start of every `scripts/migrate.sh` subcommand invocation and every `/pdeq-migrate` orchestrator step. They compose: a fixture test sets the relevant subset to point inside a `qa/fixtures/migrations/happy-path/` directory containing a canned `pdeq.json` and a handful of named migration markdown files, then invokes `scripts/migrate.sh list-pending` or the end-to-end flow.

Example fixture shape:

```
qa/cli/fixtures/migrations/
  happy-path/
    pdeq.json           # pdeqVersion: "0.2.0"
    migrations/
      0.3.0.md          # pure mechanical, touches a fixture spec file
      0.4.0.md          # has semantic block
    specs/
      product/auth.md
  absent-version/
    pdeq.json           # no pdeqVersion field
    migrations/
      0.4.0.md
  lineage-mismatch/
    pdeq.json           # pdeqVersion: "0.5.0" — ahead of pinned
    ...
```

QA can invoke the runner end-to-end by `PDEQ_CONFIG_PATH=.../happy-path/pdeq.json PDEQ_MIGRATIONS_DIR=.../happy-path/migrations ./scripts/migrate.sh list-pending` and assert output. The `/pdeq-migrate` slash command itself is harder to unit-test because it runs in Claude's context; QA tests the shell subcommands directly and validates the orchestration manually or via recorded-run comparison.

Satisfies fixture needs for all `AC-migrations-*` that can be exercised without a live Claude session (all of them except `AC-migrations-semantic-context`, which needs a recorded agent pass).

## Implementation Plan

Ordered to keep each step independently commit-worthy and leave the tree green between commits.

1. **Tag baseline `v0.1.0`.** Before any migrations code lands. Establishes the pre-feature version so the first real migration (v0.2.0) has something to migrate from. No file changes in pdeq itself.
2. **Add `VERSION` file and schema field.** `VERSION` = `0.2.0`; `pdeq.schema.json` gains `pdeqVersion`. Pure additive; no behavior change yet. The traceability audit stays green because no slugs are referenced.
3. **Write `scripts/migrate.sh`.** Implement all subcommands (`recorded`, `pinned`, `list-pending`, `parse`, `bump`, `check-lineage`, `audit-scope`). Unit-testable by shell harness. No `/pdeq-migrate` command yet — the script is usable standalone.
4. **Write `.claude/commands/pdeq-migrate.md`.** The orchestrator. Invokes the Step 3 helpers. At this point `/pdeq-migrate` works end-to-end for pure-mechanical migrations.
5. **Update `scripts/init.sh`.** Always emit `pdeq.json`, populate `pdeqVersion` from `.pdeq/VERSION`. Consumers upgrading init get a correctly-versioned config.
6. **Write `scripts/audit-migrations.sh`** and document the `commit-msg` hook composition. Breaking-change gate is now in place for subsequent pdeq development.
7. **Author `migrations/0.2.0.md`.** The first real migration. Adds `pdeqVersion: 0.2.0` to the consumer's `pdeq.json` — this is the on-ramp from pre-migrations projects. Mechanical block handles the edit idempotently.
8. **Tag `v0.2.0`** and add pdeq to itself as a submodule pinned to `v0.1.0`. Initialize pdeq's own `pdeq.json` with `pdeqVersion: 0.1.0`. At this point the bootstrap chain exists.
9. **First self-migration dry-run.** Run `/pdeq-migrate --dry-run` against pdeq's own specs. Should surface the 0.2.0 migration. Validates the dogfood path before any subsequent release.
10. **Subsequent release:** when the next breaking change lands, the author follows the §Bootstrap chain release flow — writes `migrations/<version>.md`, bumps `VERSION`, the gate validates on commit, tag, bump self-pin, self-migrate.

## Open Technical Questions

These are flagged to product/design for resolution. None block the engineering spec itself; all are narrow technical choices.

- **Pre-release version support.** `sort -V` does not correctly order `0.4.0-rc.1`. If pdeq ships RCs, the comparator needs a reimplementation. Product has not required pre-release versions; engineering excludes them from v1 scope.
- **Hook composition file.** The pdeq repo has no checked-in pre-commit / commit-msg hooks today. This spec documents what hooks should exist (`audit-traceability.sh` as pre-commit, `audit-migrations.sh` as commit-msg, `merge-decisions.sh` as pre-commit). Installing them is out of scope for this feature. Worth a follow-up `scripts/install-hooks.sh`.
- **pdeq's own `product/CLAUDE.md` etc. content.** The framework source files at `product/CLAUDE.md`, etc., are what ship to consumers. Once `.pdeq/` exists as a submodule in the pdeq repo itself, there is an ambiguity: do pdeq's own functional-area `CLAUDE.md` files become thin `@.pdeq/product/CLAUDE.md` imports (matching what init.sh creates for consumers), or stay as the authored framework source? If the former, an additional layer of symlink or stub is needed. Proposal: stay as authored source in pdeq, since pdeq **is** its own framework — the submodule exists for dogfood of the runtime behavior, not the documentation structure. Confirm with product before release.
- **Migration file discoverability in consumer projects.** The design spec says `.pdeq/migrations/<version>.md`. Consumers reach this through the submodule, not a symlink. If a consumer expects to run `./scripts/migrate.sh list-pending` and have it find migrations, the script needs to know the submodule path — currently assumed as `.pdeq/migrations/`. If a consumer has customized `pdeqDir`, `scripts/migrate.sh` reads that from `pdeq.json` (the `pdeqDir` field already exists in the schema). Flagged so QA fixtures exercise a custom `pdeqDir` case.
- **Scope glob syntax dialect.** Git pathspec globs are chosen (§Security Considerations). A stricter alternative (Go-style `**` only, no `{a,b}` brace expansion) would be more portable but less expressive. Deferred.

## Requirements Coverage Check

Every product slug is addressed by some piece of this engineering approach.

| Slug | Addressed by |
|---|---|
| `FR-migrations-version-field` | §Schema change; §init.sh changes; §Data Model. |
| `FR-migrations-version-readable` | `scripts/migrate.sh recorded` subcommand; §API. |
| `FR-migrations-absent-version` | §State Management (absence semantics); `/pdeq-migrate` Step 2 precondition check. |
| `FR-migrations-one-per-version` | Filename convention `<version>.md`; `list-pending` logic. |
| `FR-migrations-ordered` | Semver filename + `sort -V` in `list-pending`. |
| `FR-migrations-mechanical-block` | `## Mechanical` section parsed by `parse` subcommand; executed by orchestrator Step 4. |
| `FR-migrations-semantic-block` | `## Semantic` section parsed by `parse`; executed inline by orchestrator. |
| `FR-migrations-order-within` | Orchestrator Step 4 runs Mechanical block before Semantic. |
| `FR-migrations-author-written` | No auto-generation; migrations are markdown files in `migrations/`. |
| `FR-migrations-explicit-run` | `/pdeq-migrate` slash command is the only entry point; never auto-invoked. |
| `FR-migrations-pending-detection` | `list-pending` subcommand logic. |
| `FR-migrations-ordered-application` | Orchestrator iterates `list-pending` output in order. |
| `FR-migrations-version-bump` | `bump` subcommand invoked after each successful migration. |
| `FR-migrations-noop-when-current` | `list-pending` returns empty when recorded == pinned; orchestrator short-circuits to Surface 2. |
| `FR-migrations-dry-run` | `--dry-run` flag handled by orchestrator; mechanical block emits `would …` lines, semantic block skipped. |
| `FR-migrations-idempotent` | Per-migration bump ensures pending window shrinks; mechanical scripts must be idempotent by author discipline. |
| `FR-migrations-scoped-writes` | `scope:` frontmatter + `audit-scope` post-run check. |
| `FR-migrations-breaking-gate` | `scripts/audit-migrations.sh` commit-msg hook. |
| `FR-migrations-no-false-positive` | Gate only fires on framework-file + VERSION-bump commits; trailer override for deliberate non-breaking cases. |
| `FR-migrations-lineage-integrity` | `check-lineage` subcommand. |
| `FR-migrations-bootstrap-chain` | §Bootstrap chain — N-1 pin. |
| `FR-migrations-self-migration` | §Bootstrap chain release flow uses `/pdeq-migrate` verbatim against pdeq's own specs. |
| `FR-migrations-atomic-bump` | Per-migration bump (not whole-run) strategy. |
| `FR-migrations-failure-report` | Orchestrator Surface 5 output; `bump` not called for failing migration. |
| `FR-migrations-recoverable-partial` | Leave-as-is recovery policy; no rollback code path. |
| `FR-migrations-unknown-version` | `check-lineage` + recorded-vs-pinned comparison. |
| `NFR-migrations-idempotency` | Shell-level no-op when current + per-migration bump narrows pending window. |
| `NFR-migrations-determinism` | Semver filename ordering via `sort -V`; single-threaded sequential orchestrator. |
| `NFR-migrations-scope-minimalism` | Default `scope: default` limits writes; `audit-scope` catches violations. |
| `NFR-migrations-enforcement-precision` | Gate only fires on matching commits; silent otherwise. |
| `AC-migrations-noop-when-current` | Empty `list-pending` output → Surface 2 short-circuit. |
| `AC-migrations-ordered-apply` | `list-pending` + orchestrator loop + `bump` per step. |
| `AC-migrations-no-bump-on-failure` | Per-migration bump means failing migration's version is not written. |
| `AC-migrations-dry-run-accurate` | Dry-run orchestrator prints exact mechanical changes; same `list-pending` source of truth as real run. |
| `AC-migrations-gate-blocks` | Commit-msg hook exit 1 + Surface 8 output. |
| `AC-migrations-gate-allows-nonbreaking` | Gate silence when preconditions don't match + trailer override. |
| `AC-migrations-semantic-context` | Orchestrator reads exactly the `### Files` globs into the semantic prompt. |
| `AC-migrations-idempotent-rerun` | Empty pending list on second run → Surface 2. |
| `AC-migrations-absent-reported` | Precondition check prints Surface 6 sub-case 1 and exits. |
| `AC-migrations-lineage-refused` | `check-lineage` exit non-zero → Surface 6 sub-case 3. |
| `AC-migrations-scope-respected` | Default `scope: default` + `audit-scope` subcommand. |
| `AC-migrations-self-migration-runs` | `/pdeq-migrate` invoked against pdeq's own specs at release time (§Bootstrap chain). |
| `FR-migrations-nonbreaking-advance` | §Non-breaking advance — direct bump when no files in window. |
| `AC-migrations-nonbreaking-advance` | §Non-breaking advance + orchestrator Surface 3b path. |
| `FR-migrations-missing-file-refused` | §Missing-file detection — lineage-breaking enumeration against migrations dir. |
| `AC-migrations-missing-file-refused` | §Missing-file detection + Surface 6 missing-file sub-case. |
| `FR-migrations-update-command` | §Upgrade Entrypoint — `/pdeq-update` slash command at `.claude/commands/pdeq-update.md`, prompt-driven runner. |
| `FR-migrations-update-bumps-pin` | §Upgrade Entrypoint → Bump implementation — `git submodule update --remote .pdeq` from `pdeq-update.md`. |
| `FR-migrations-update-chains` | §Upgrade Entrypoint → Chained migration (approach A, inline reuse). |
| `FR-migrations-update-in-session` | §Upgrade Entrypoint → In-session command availability — `scripts/sync-symlinks.sh --prune` + harness lazy command lookup. |
| `FR-migrations-update-noop` | §Upgrade Entrypoint → Bump implementation, step 4 (SHA-equality short-circuit). |
| `FR-migrations-update-bump-failure` | §Upgrade Entrypoint → Bump implementation, step 5 (failure-mode table); Surface 14 output. |
| `FR-migrations-update-dry-run` | §Upgrade Entrypoint → command shape (`--dry-run`); §`/pdeq-update` slash command markdown step 2 (fetch-only path). |
| `AC-migrations-update-end-to-end` | §Upgrade Entrypoint → Chained migration; Surface 12 happy-path. |
| `AC-migrations-update-noop` | §Upgrade Entrypoint → Bump implementation, step 4. |
| `AC-migrations-update-in-session` | §Upgrade Entrypoint → In-session command availability. |
| `AC-migrations-update-bump-failure` | §Upgrade Entrypoint → Bump implementation, step 5. |
| `AC-migrations-update-dry-run` | §Upgrade Entrypoint → `/pdeq-update` slash command markdown, step 2 dry-run path. |

## Summary of Files

### New

- `/Users/ldstreet/Development/pdeq/VERSION`
- `/Users/ldstreet/Development/pdeq/scripts/migrate.sh`
- `/Users/ldstreet/Development/pdeq/scripts/audit-migrations.sh`
- `/Users/ldstreet/Development/pdeq/scripts/sync-symlinks.sh` (planned)
- `/Users/ldstreet/Development/pdeq/.claude/commands/pdeq-migrate.md`
- `/Users/ldstreet/Development/pdeq/.claude/commands/pdeq-update.md` (planned)
- `/Users/ldstreet/Development/pdeq/migrations/` (directory)
- `/Users/ldstreet/Development/pdeq/migrations/0.2.0.md` (first authored migration)

### Modified

- `/Users/ldstreet/Development/pdeq/pdeq.schema.json` — add `pdeqVersion` field **(schema change)**
- `/Users/ldstreet/Development/pdeq/scripts/init.sh` — always emit `pdeq.json`, populate `pdeqVersion`; refactor Steps 5–6 to call `scripts/sync-symlinks.sh`

## Code Map

Code locations for every functional requirement. Rows marked `implemented` have
at least one inline marker in the listed file; `planned` rows point at files
that do not yet exist (the /pdeq-migrate command file and audit-migrations.sh gate);
`unimplemented` rows are deliberately deferred.

| Slug | Planned location | Status |
|---|---|---|
| FR-migrations-version-field | scripts/init.sh | implemented |
| FR-migrations-version-readable | scripts/migrate.sh | implemented |
| FR-migrations-absent-version | scripts/migrate.sh | implemented |
| FR-migrations-one-per-version | scripts/migrate.sh | implemented |
| FR-migrations-ordered | scripts/migrate.sh | implemented |
| FR-migrations-mechanical-block | scripts/migrate.sh | implemented |
| FR-migrations-semantic-block | scripts/migrate.sh | implemented |
| FR-migrations-order-within | .claude/commands/pdeq-migrate.md | implemented |
| FR-migrations-author-written | migrations/TEMPLATE.md | implemented |
| FR-migrations-explicit-run | .claude/commands/pdeq-migrate.md | implemented |
| FR-migrations-pending-detection | scripts/migrate.sh | implemented |
| FR-migrations-ordered-application | .claude/commands/pdeq-migrate.md | implemented |
| FR-migrations-version-bump | scripts/migrate.sh | implemented |
| FR-migrations-nonbreaking-advance | scripts/migrate.sh | implemented |
| FR-migrations-noop-when-current | scripts/migrate.sh | implemented |
| FR-migrations-dry-run | .claude/commands/pdeq-migrate.md | implemented |
| FR-migrations-idempotent | migrations/TEMPLATE.md | implemented |
| FR-migrations-scoped-writes | scripts/migrate.sh | implemented |
| FR-migrations-breaking-gate | scripts/audit-migrations.sh | implemented |
| FR-migrations-no-false-positive | scripts/audit-migrations.sh | implemented |
| FR-migrations-lineage-integrity | scripts/migrate.sh | implemented |
| FR-migrations-bootstrap-chain | — | unimplemented |
| FR-migrations-self-migration | .claude/commands/pdeq-migrate.md | implemented |
| FR-migrations-atomic-bump | scripts/migrate.sh | implemented |
| FR-migrations-failure-report | .claude/commands/pdeq-migrate.md | implemented |
| FR-migrations-recoverable-partial | scripts/migrate.sh | implemented |
| FR-migrations-unknown-version | scripts/migrate.sh | implemented |
| FR-migrations-missing-file-refused | scripts/migrate.sh | implemented |
| FR-migrations-update-command | .claude/commands/pdeq-update.md | planned |
| FR-migrations-update-bumps-pin | .claude/commands/pdeq-update.md | planned |
| FR-migrations-update-chains | .claude/commands/pdeq-update.md | planned |
| FR-migrations-update-in-session | .claude/commands/pdeq-update.md; scripts/sync-symlinks.sh | planned |
| FR-migrations-update-noop | .claude/commands/pdeq-update.md | planned |
| FR-migrations-update-bump-failure | .claude/commands/pdeq-update.md | planned |
| FR-migrations-update-dry-run | .claude/commands/pdeq-update.md | planned |
