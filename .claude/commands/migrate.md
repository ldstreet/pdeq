<!-- Implements: FR-migrations-explicit-run, FR-migrations-ordered-application, FR-migrations-order-within, FR-migrations-dry-run, FR-migrations-failure-report, FR-migrations-self-migration -->
# Migrate: $ARGUMENTS

Apply pending pdeq migrations from the pinned `.pdeq` submodule to this project. You are the migration runner. Shell helpers in `scripts/migrate.sh` do version math and file discovery; you drive the loop, read migration files, and execute semantic prompts inline.

Follow the steps below in order. Do not skip. Abort on any non-zero exit from a shell helper unless a step explicitly says to tolerate failure.

---

## Step 0 — Parse arguments

`$ARGUMENTS` contains the flags passed to `/migrate`. Recognized forms:

| Form | Meaning |
|---|---|
| (empty) | Run pending migrations, write to disk. |
| `--dry-run` | Preview only. Mechanical blocks print `would …` lines; semantic blocks are skipped with the summary-only notice. No disk writes. No version bump. |
| `--from <version>` | Recovery: start replay at an explicit version. Used only after a failure instructs you to. Overrides the recorded version for loop entry, but `bump` still writes the normal target. |

Parse into two locals: `DRY_RUN` (bool) and `FROM_VERSION` (string or empty). Any other argument: print `✗ unknown argument: <arg>` to stderr and exit.

---

## Step 1 — Read version state

Run these shell helpers and capture stdout:

```
RECORDED=$(scripts/migrate.sh recorded || true)
PINNED=$(scripts/migrate.sh pinned)
```

If `scripts/migrate.sh pinned` fails (no VERSION file), stop and report the failure verbatim — this is an installation problem, not a migration state.

Print the opening status line (always, regardless of state):

```
pdeq: recorded <RECORDED-or-(none)> → pinned <PINNED>
```

If `DRY_RUN` is set, append `   [DRY RUN — no writes]` to the header.

---

## Step 2 — Precondition checks

Run these in order. Each is a terminal condition: on match, print the Surface 6 sub-case, exit non-zero, do nothing else.

### 2a. Absent recorded version

If `RECORDED` is empty, print:

```
✗ No pdeq version is recorded for this project.

  Your project config (pdeq.json) has no "pdeqVersion" field. This means the
  project predates the migrations feature, so pdeq cannot tell which migrations
  are already applied.

  What to do:
    1. Manually inspect your specs against pdeq <PINNED>'s expectations.
    2. Once confirmed in conformance, add "pdeqVersion": "<PINNED>" to pdeq.json.
    3. Future upgrades will then run through /migrate normally.
```

Exit 2. Satisfies `FR-migrations-absent-version`, `AC-migrations-absent-reported`.

### 2b. Recorded newer than pinned

If `RECORDED > PINNED` (use `scripts/migrate.sh` subcommands — do not compare strings yourself), print:

```
✗ Recorded version (<RECORDED>) is newer than the pinned pdeq submodule (<PINNED>).

  This usually means the submodule was rolled back without also rolling back
  the recorded version, or this project is tracking a different pdeq lineage.

  /migrate will not run. No files changed.

  What to do:
    1. If you intended to roll back, also set pdeq.json "pdeqVersion" to <PINNED> or earlier.
    2. If the submodule bump is wrong, bump it forward to ≥ <RECORDED>.
```

Exit 2. Satisfies `FR-migrations-unknown-version`.

### 2c. Foreign lineage

Run `scripts/migrate.sh check-lineage`. On non-zero exit, print:

```
✗ Recorded pdeq version <RECORDED> does not match the pinned pdeq lineage.

  The pinned pdeq submodule does not include a release tagged <RECORDED> in its
  history. This project may have been initialized against a fork.

  /migrate will not run. No files changed.

  What to do:
    1. Confirm the pdeq submodule URL in .gitmodules matches your release source.
    2. If the project was initialized against a fork, align pdeqVersion with
       the current lineage or re-pin the submodule.
```

Exit 2. Satisfies `FR-migrations-lineage-integrity`, `AC-migrations-lineage-refused`.

---

## Step 3 — Enumerate pending work

Run:

```
PENDING=$(scripts/migrate.sh list-pending)
BREAKING_IN_WINDOW=$(scripts/migrate.sh lineage-breaking "$RECORDED" "$PINNED")
```

Apply `--from` if set: filter `PENDING` to versions `>= $FROM_VERSION` using the shell comparator (`sort -V`).

Four cases, evaluated in order:

### 3a. Both empty AND `RECORDED == PINNED` → no-op

Print:

```
~ Already at <PINNED> — nothing to migrate.
```

Exit 0. Satisfies `FR-migrations-noop-when-current`, `AC-migrations-noop-when-current`, `AC-migrations-idempotent-rerun`.

### 3b. `PENDING` empty AND `RECORDED < PINNED` → non-breaking advance

No migration files exist in the `(RECORDED, PINNED]` window and `BREAKING_IN_WINDOW` is also empty — every intermediate release was non-breaking. Print:

```
~ No migrations pending. Advancing recorded version <RECORDED> → <PINNED> (non-breaking releases).
```

Then (skip if `DRY_RUN`): `scripts/migrate.sh bump "$PINNED"`.

Print the success summary:

```

✓ pdeq: recorded <RECORDED> → <PINNED>
  No migrations ran.
```

Exit 0. Satisfies `FR-migrations-nonbreaking-advance`, `AC-migrations-nonbreaking-advance`.

### 3c. `BREAKING_IN_WINDOW` names versions with no corresponding file → missing-file refusal

For each version in `BREAKING_IN_WINDOW`, check whether a matching file exists in the migrations directory (the `PENDING` list is authoritative — if a breaking version appears in the lineage but not in `PENDING`, the file is missing). For the first missing version, print:

```
✗ Missing migration file for <VERSION>.

  The pinned pdeq lineage declares <VERSION> as a breaking change, but the
  migration file is not present:
    expected: .pdeq/migrations/<VERSION>.md  (not found)

  /migrate will not run. No files changed.

  What to do:
    1. Confirm your pdeq submodule is fully checked out: `git submodule update --init`.
    2. If the submodule is correct but the file is missing, the pinned pdeq
       release is incomplete — report to pdeq maintainers and pin to an earlier
       version in the meantime.
```

Exit 2. Do not bump. Satisfies `FR-migrations-missing-file-refused`, `AC-migrations-missing-file-refused`.

### 3d. `PENDING` non-empty → proceed to Step 4

Print the count-line:

```
  <N> migrations pending: <v1>, <v2>, …, <vN>
```

Blank line, then loop.

---

## Step 4 — Run each migration in order

For each version in `PENDING` (already sorted ascending):

### 4a. Parse and announce

```
MIG_FILE=".pdeq/migrations/<VERSION>.md"    # consumer context
# In pdeq-repo self-migration context, replace with migrations/<VERSION>.md
SUMMARY_BLOCK=$(scripts/migrate.sh parse "$MIG_FILE")
```

From `SUMMARY_BLOCK`, extract `summary`, `has-mechanical`, `has-semantic`, `scope`, and — if semantic — `semantic-files`.

Print:

```
▸ <VERSION> — <summary>
```

### 4b. Mechanical block

If `has-mechanical == true`:

- **Real run**: read every fenced `shell` code block under `## Mechanical` in `$MIG_FILE`. Execute them in order via the Bash tool from the consumer's specs root (`cd "$(scripts/migrate.sh specs-root 2>/dev/null || echo .)"`). Capture non-zero exit → go to Step 4d (failure).
- **Dry-run**: for each shell block, print `  • mechanical    would <first-line-of-block>` plus up to a handful of concrete operations the block performs (grep the block for obvious file writes; if the block is opaque, just list the command invocations). Append `…N more…` when truncating. Do NOT execute.

On success (real run), print:

```
  ✓ mechanical    <one-line summary of what changed — file counts, slug counts>
```

If `has-mechanical == false`, skip the line entirely — migrations with no mechanical block should declare `## Mechanical\n\nNone.` which parses as absent. Print `  ~ mechanical    no mechanical block`.

### 4c. Semantic block

If `has-semantic == true`:

- **Real run**: read the globs from the migration's `### Files` list and load the matching files. Read the prose in `### Prompt` verbatim. Execute the prompt inline as an agent pass with ONLY those files in context — honor `AC-migrations-semantic-context` strictly. On completion, emit `  ✓ semantic      reviewed <M> files, updated <N>`.
- **Dry-run**: print `  • semantic      would review <M> files (preview suppressed in dry-run — semantic changes require a live agent pass; re-run without --dry-run to see proposed edits)`.
- **Testing override**: if `$PDEQ_SEMANTIC_AGENT` is set, invoke that executable in place of the live agent pass. Pass the resolved file list on stdin and the prompt text via `PDEQ_SEMANTIC_PROMPT_FILE`. Use its exit code and stdout as the result.

If `has-semantic == false`, print `  ~ semantic      no semantic block`.

### 4d. Scope audit

After the mechanical and semantic blocks finish, run:

```
scripts/migrate.sh audit-scope "$MIG_FILE"
```

On non-zero exit: treat as a failed migration (fall through to Step 4e). The audit's stdout names the out-of-scope paths; include it in the failure output.

### 4e. Per-migration completion

On clean completion of 4b/4c/4d:

- **Real run**: `scripts/migrate.sh bump "<VERSION>"`. Print `  ✓ migration complete`.
- **Dry-run**: print nothing extra (the block lines already stand alone).

On any failure in 4b/4c/4d, stop the loop and jump to Step 5b. Do NOT bump for the failing migration. Do NOT run subsequent migrations.

Satisfies `FR-migrations-mechanical-block`, `FR-migrations-semantic-block`, `FR-migrations-order-within`, `FR-migrations-scoped-writes`, `FR-migrations-atomic-bump`, `AC-migrations-ordered-apply`, `AC-migrations-semantic-context`.

---

## Step 5 — Trailing summary

### 5a. Success path

All migrations in `PENDING` completed. Print:

```

✓ pdeq: recorded <ORIGINAL-RECORDED> → <PINNED>
  Ran <N> migrations. Review the diff before committing.
```

In dry-run, replace the final line with `[DRY RUN] No files were modified. Run /migrate to apply.` and drop the `✓` line.

Exit 0.

### 5b. Failure path

The loop stopped at migration `<FAILED-VERSION>` in block `<mechanical|semantic|scope>`. Read the post-failure state:

```
LAST_APPLIED=$(scripts/migrate.sh recorded)     # per-migration bump means this is already correct
REMAINING=$(echo "$PENDING" | awk -v v="$FAILED-VERSION" '$0==v{flag=1} flag')
```

Print Surface 5:

```
✗ Migration <FAILED-VERSION> failed at the <BLOCK> step.

  Recorded pdeq version: <LAST-APPLIED>  (advanced from <ORIGINAL-RECORDED> — <list of clean migrations> applied cleanly)
  Pinned pdeq version:   <PINNED>
  Remaining:             <REMAINING, comma-separated>

  What to do:
    1. Resolve the cause above (<one-line paraphrase of the failure>).
    2. Re-run /migrate. The runner will resume at <FAILED-VERSION>.

  No rollback was performed. Your working tree is as the failing step left it —
  review `git status` to inspect.
```

Exit 1. Satisfies `FR-migrations-failure-report`, `FR-migrations-recoverable-partial`, `FR-migrations-atomic-bump`, `AC-migrations-no-bump-on-failure`.

---

## Output style reference

| Glyph | ANSI | When |
|---|---|---|
| `✓` | green `\033[0;32m` | successful block or final summary |
| `~` | yellow `\033[0;33m` | absent block or no-op |
| `✗` | red `\033[0;31m` | failure or precondition refusal |
| `•` | no color (plain) | dry-run line prefix |
| `▸` | no color | migration header |

Indentation: two-space indent for per-block lines under a `▸` header; four-space indent for nested continuations (e.g., dry-run change previews).

Tone rules from `design/cli/migrations.md`:

- Always print the opening `pdeq: recorded X → pinned Y` line first, before any work.
- Never skip the per-migration `mechanical`/`semantic` lines — absent blocks print with `~` and `no … block` so the visual shape is consistent.
- Failure output names the **last fully-applied** migration for `Recorded pdeq version`, not the failing one.

---

## Self-migration context (pdeq repo only)

When `/migrate` runs inside the pdeq repository itself, the filesystem layout differs:

- Migration files live at `migrations/<VERSION>.md` (no `.pdeq/` prefix). `scripts/migrate.sh` auto-detects this via the `MIGRATIONS_DIR` resolution rule.
- The pinned version is read from `.pdeq/VERSION` (the self-pinned previous-stable submodule), not from root `VERSION` (which is the in-development version).
- Error messages that print expected paths must use the repo-local form `migrations/<VERSION>.md`. All shell helpers do this automatically; inline path references in your output should match.

Satisfies `FR-migrations-self-migration`, `AC-migrations-self-migration-runs`.
