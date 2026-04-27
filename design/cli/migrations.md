---
product-hash: 7e42c8798456b4865d3587297815795edd1881abf503cac093811f6011b752a7
product-slugs: [AC-migrations-absent-reported, AC-migrations-dry-run-accurate, AC-migrations-gate-allows-nonbreaking, AC-migrations-gate-blocks, AC-migrations-idempotent-rerun, AC-migrations-lineage-refused, AC-migrations-missing-file-refused, AC-migrations-no-bump-on-failure, AC-migrations-nonbreaking-advance, AC-migrations-noop-when-current, AC-migrations-ordered-apply, AC-migrations-scope-respected, AC-migrations-self-migration-runs, AC-migrations-semantic-context, AC-migrations-update-bump-failure, AC-migrations-update-dry-run, AC-migrations-update-end-to-end, AC-migrations-update-in-session, AC-migrations-update-noop, FR-migrations-absent-version, FR-migrations-atomic-bump, FR-migrations-author-written, FR-migrations-bootstrap-chain, FR-migrations-breaking-gate, FR-migrations-dry-run, FR-migrations-explicit-run, FR-migrations-failure-report, FR-migrations-idempotent, FR-migrations-lineage-integrity, FR-migrations-mechanical-block, FR-migrations-missing-file-refused, FR-migrations-no-false-positive, FR-migrations-nonbreaking-advance, FR-migrations-noop-when-current, FR-migrations-one-per-version, FR-migrations-order-within, FR-migrations-ordered, FR-migrations-ordered-application, FR-migrations-pending-detection, FR-migrations-recoverable-partial, FR-migrations-scoped-writes, FR-migrations-self-migration, FR-migrations-semantic-block, FR-migrations-unknown-version, FR-migrations-update-bump-failure, FR-migrations-update-bumps-pin, FR-migrations-update-chains, FR-migrations-update-command, FR-migrations-update-dry-run, FR-migrations-update-in-session, FR-migrations-update-noop, FR-migrations-version-bump, FR-migrations-version-field, FR-migrations-version-readable, NFR-migrations-determinism, NFR-migrations-enforcement-precision, NFR-migrations-idempotency, NFR-migrations-scope-minimalism]
---
# Migrations — CLI Design Spec

> Based on requirements in `../../product/migrations.md`

## What We're Designing

This spec covers every user-facing surface of the migrations feature on the CLI platform: the `/pdeq-migrate` slash command and its terminal output, the unified `/pdeq-update` upgrade entrypoint that wraps the submodule bump and the migration run, the markdown format that pdeq maintainers author migrations in, the dry-run presentation, the pre-commit gate output shown to pdeq maintainers, and the dogfood/self-migration presentation. The design goal is that a consumer running `/pdeq-update` (or `/pdeq-migrate`) can tell at a glance what happened, what didn't, and what to do next — and a pdeq maintainer authoring a migration has one obvious file to create with a clear structural template.

Tonally this design matches the existing pdeq slash commands (`/pdeq-kickoff`, `/pdeq-status`, `/pdeq-impact`, `/pdeq-bootstrap`): terse, declarative, oriented toward a small number of well-labeled outcomes. Terminal output reuses the color and glyph vocabulary established in `scripts/init.sh` — green `✓` for success, yellow `~` for skip/no-op, cyan `?` for prompt, and adds red `✗` for failure.

## Screen Inventory

The CLI platform has no screens in the GUI sense. Instead, the "surfaces" are:

1. **`/pdeq-migrate` invocation** — the slash command and its argument forms.
2. **No-op output** — what the user sees when nothing is pending.
3. **Pending-run output** — what the user sees when migrations will run.
3b. **Non-breaking advance output** — what the user sees when the pinned version advances but no migrations apply.
4. **Dry-run output** — preview mode.
5. **Failure output** — a migration errored out mid-run.
6. **Precondition-error output** — absent version, foreign lineage, newer recorded version, missing migration file.
7. **Migration file format** — the authored markdown a maintainer writes.
8. **Commit-msg gate output** — what a pdeq maintainer sees when the gate blocks a commit.
9. **Self-migration output** — pdeq's own release-time run.
10. **`/pdeq-update` invocation** — the unified upgrade entrypoint that bumps the pinned pdeq reference and chains into `/pdeq-migrate`.
11. **Update no-op output** — what the user sees when already at the latest pinned version.
12. **Update happy-path output** — bump + chained migration in a single run.
13. **Update dry-run output** — preview of the would-be bump and its consequent pending migrations.
14. **Update bump-failure output** — the underlying bump step failed; nothing else ran.

Each is defined below.

---

## Surface Definitions

### 1. `/pdeq-migrate` invocation

One sentence: the command the consumer runs after bumping the pdeq submodule to apply any pending migrations.

- **Entry points**: The consumer types `/pdeq-migrate` in their coding agent session, or runs the equivalent underlying script.
- **Invocation forms**:
  - `/pdeq-migrate` — apply all pending migrations, in version order, writing to disk.
  - `/pdeq-migrate --dry-run` — preview what would change. Make no writes.
  - `/pdeq-migrate --from <version>` — (advisory, for recovery) start replay from an explicit version. Only used when the consumer has been instructed to by a failure-report message. Not part of routine flow.
- **States**: no-op, pending-run, dry-run, failure, precondition-error, self-migration. Enumerated below.
- **Requirements satisfied**: `FR-migrations-explicit-run`, `FR-migrations-pending-detection`, `FR-migrations-dry-run`.

Regardless of state, every invocation starts with a single status line that names the comparison being made, so the user knows what versions are in play before any work begins:

```
pdeq: recorded 0.2.1 → pinned 0.4.0
```

The arrow direction is always `recorded → pinned`. If the two are equal, it still prints (it's the opening line of the no-op state, below). If recorded is greater than pinned, the arrow is still printed — but the run aborts (see precondition-error).

Satisfies `FR-migrations-version-readable`.

---

### 2. No-op output (already current)

One sentence: the user ran `/pdeq-migrate` but there's nothing to do.

Output:

```
pdeq: recorded 0.4.0 → pinned 0.4.0
~ Already at 0.4.0 — nothing to migrate.
```

- Yellow `~` glyph. No green, because no work was done.
- Exits 0.
- **Requirements satisfied**: `AC-migrations-noop-when-current`, `FR-migrations-noop-when-current`, `AC-migrations-idempotent-rerun` (second invocation in a row produces the same no-op output), `FR-migrations-idempotent`.

---

### 3. Pending-run output (multi-step migration)

One sentence: the user ran `/pdeq-migrate` with one or more migrations pending, and they all apply cleanly.

Each migration prints a header line, then per-block status, then a per-migration summary. After all migrations apply, a single trailing success summary confirms the version bump.

```
pdeq: recorded 0.2.1 → pinned 0.4.0
  3 migrations pending: 0.3.0, 0.3.2, 0.4.0

▸ 0.3.0 — human-readable slug format
  ✓ mechanical    rewrote 42 slugs across 18 files
  ✓ semantic      reviewed 6 files, updated 4
  ✓ migration complete

▸ 0.3.2 — roadmap folder
  ✓ mechanical    created roadmap/, moved 2 files
  ~ semantic      no semantic block
  ✓ migration complete

▸ 0.4.0 — pdeqVersion field required
  ✓ mechanical    updated pdeq.json
  ~ semantic      no semantic block
  ✓ migration complete

✓ pdeq: recorded 0.2.1 → 0.4.0
  Ran 3 migrations. Review the diff before committing.
```

Layout rules:
- Each migration is introduced by a `▸` bullet and its version + one-line summary (drawn from the migration file's header).
- Inside each migration, two fixed lines are printed: `mechanical` and `semantic`. Even if a block is absent, it is listed with a `~` and the words `no ... block`. This gives the user a consistent visual shape per migration regardless of contents and makes it obvious when a semantic block ran (vs. was absent).
- The per-migration summary line `✓ migration complete` confirms the whole migration landed.
- The final summary line names the version transition and reminds the user to diff.
- Satisfies `FR-migrations-ordered-application`, `FR-migrations-order-within` (mechanical always listed above semantic), `FR-migrations-version-bump`, `FR-migrations-mechanical-block`, `FR-migrations-semantic-block`, `AC-migrations-ordered-apply`.

Exits 0.

---

### 3b. Non-breaking advance output

One sentence: the user ran `/pdeq-migrate` with the pinned version newer than the recorded version, but no migration files exist in the pending window — all intermediate releases were non-breaking.

```
pdeq: recorded 0.3.0 → pinned 0.3.2
~ No migrations pending. Advancing recorded version 0.3.0 → 0.3.2 (non-breaking releases).

✓ pdeq: recorded 0.3.0 → 0.3.2
  No migrations ran.
```

- Yellow `~` on the advance-line — no mechanical or semantic work was done, only a config bump.
- Green `✓` on the final version-transition line, matching Surface 3's format so the user sees a consistent "success" shape.
- Recorded version is written directly to pinned. No migration files are touched.
- Exits 0.
- **Requirements satisfied**: `FR-migrations-nonbreaking-advance`, `AC-migrations-nonbreaking-advance`.

---

### 4. Dry-run output

One sentence: the user ran `/pdeq-migrate --dry-run` to preview what would change without writing.

Dry-run uses a visually distinct prefix on the header and a `would` verb tense on every status line, so the user cannot mistake it for a real run.

```
pdeq: recorded 0.2.1 → pinned 0.4.0   [DRY RUN — no writes]
  3 migrations pending: 0.3.0, 0.3.2, 0.4.0

▸ 0.3.0 — human-readable slug format
  • mechanical    would rewrite 42 slugs across 18 files:
                    product/auth.md: FR-auth-1 → FR-auth-email-login
                    product/auth.md: FR-auth-2 → FR-auth-forgot-password
                    …40 more…
  • semantic      would review 6 files (preview suppressed in dry-run — semantic
                  changes require a live agent pass; re-run without --dry-run
                  to see proposed edits)

▸ 0.3.2 — roadmap folder
  • mechanical    would create roadmap/, move 2 files:
                    product/_future.md → roadmap/_overview.md
                    product/auth-v2.md → roadmap/auth.md
  • semantic      (absent)

▸ 0.4.0 — pdeqVersion field required
  • mechanical    would update pdeq.json: add "pdeqVersion": "0.4.0"
  • semantic      (absent)

[DRY RUN] No files were modified. Run /pdeq-migrate to apply.
```

Design decisions for dry-run:
- **Bullet glyph `•` instead of `✓`/`~`** so the user does not mistake a preview for a completed action.
- **`[DRY RUN — no writes]` suffix on the header** and **`[DRY RUN]` prefix on the trailer** bracket the entire output.
- **Mechanical preview is exhaustive but truncated** — up to the first few concrete changes per migration, then a `…N more…` collapse so the output stays scannable on a terminal.
- **Semantic blocks are not executed in dry-run.** The preview says *what files would be reviewed* and names the inputs to the semantic block, but does not invoke the agent. Rationale: executing the agent is the expensive, judgment-heavy part; running it in "preview mode" would either duplicate the cost or produce a non-representative preview. This is called out inline so the user knows why the semantic preview is summary-only, and is instructed to re-run without `--dry-run` to see proposed edits. This choice is intentional and described in the Open Questions section below.
- Exits 0.
- **Requirements satisfied**: `FR-migrations-dry-run`, `AC-migrations-dry-run-accurate`, `NFR-migrations-scope-minimalism` (preview lists exactly the files that would change — no reformatting surprises).

---

### 5. Failure output

One sentence: a migration started and failed partway through.

When a migration fails, output stops at the failure, names the migration and the block, and instructs the user how to recover.

```
pdeq: recorded 0.2.1 → pinned 0.4.0
  3 migrations pending: 0.3.0, 0.3.2, 0.4.0

▸ 0.3.0 — human-readable slug format
  ✓ mechanical    rewrote 42 slugs across 18 files
  ✓ semantic      reviewed 6 files, updated 4
  ✓ migration complete

▸ 0.3.2 — roadmap folder
  ✗ mechanical    failed: cannot move product/_future.md — file is modified
                  and unstaged. Commit or stash local changes and re-run.

✗ Migration 0.3.2 failed at the mechanical step.

  Recorded pdeq version: 0.3.0  (advanced from 0.2.1 — 0.3.0 applied cleanly)
  Pinned pdeq version:   0.4.0
  Remaining:             0.3.2, 0.4.0

  What to do:
    1. Resolve the cause above (commit or stash local changes).
    2. Re-run /pdeq-migrate. The runner will resume at 0.3.2.

  No rollback was performed. Your working tree is as the failing step left it —
  review `git status` to inspect.
```

Design rules for failure output:
- **Red `✗` on the failing block line and on the post-summary header.** The earlier successful migration (0.3.0) remains green and its `✓ migration complete` is still shown, so the user can see exactly how far progress got.
- **Recorded version is reported as advanced to the last fully-applied migration** (0.3.0 here, not 0.3.2). This is the load-bearing user-visible confirmation of `FR-migrations-atomic-bump` — the version does not skip forward past the failure point.
- **Remaining list** names exactly which migrations still need to run after the user fixes the cause, so re-running `/pdeq-migrate` is understood to resume, not restart.
- **"What to do" block** names the cause in plain English and the exact next command.
- **Recovery policy is "leave-as-is"** — the runner does not auto-rollback the failing migration's partial writes. The user sees `No rollback was performed` and is pointed at `git status`. This is the intentional choice called out in Open Questions.
- Exits non-zero.
- **Requirements satisfied**: `FR-migrations-atomic-bump`, `AC-migrations-no-bump-on-failure`, `FR-migrations-failure-report`, `FR-migrations-recoverable-partial`.

---

### 6. Precondition-error output

One sentence: the runner refused to start because the version state is invalid.

Three sub-cases share one visual pattern — a single `✗` line naming the condition, then a plain-English explanation, then a suggested next step. No migrations run.

**Absent recorded version** (satisfies `FR-migrations-absent-version`, `AC-migrations-absent-reported`):

```
pdeq: recorded (none) → pinned 0.4.0
✗ No pdeq version is recorded for this project.

  Your project config (pdeq.json) has no "pdeqVersion" field. This means the
  project predates the migrations feature, so pdeq cannot tell which migrations
  are already applied.

  What to do:
    1. Manually inspect your specs against pdeq 0.4.0's expectations.
    2. Once confirmed in conformance, add "pdeqVersion": "0.4.0" to pdeq.json.
    3. Future upgrades will then run through /pdeq-migrate normally.
```

**Recorded version newer than pinned** (satisfies `FR-migrations-unknown-version`, `AC-migrations-lineage-refused`):

```
pdeq: recorded 0.5.0 → pinned 0.4.0
✗ Recorded version (0.5.0) is newer than the pinned pdeq submodule (0.4.0).

  This usually means the submodule was rolled back without also rolling back
  the recorded version, or this project is tracking a different pdeq lineage.

  /pdeq-migrate will not run. No files changed.

  What to do:
    1. If you intended to roll back, also set pdeq.json "pdeqVersion" to 0.4.0 or earlier.
    2. If the submodule bump is wrong, bump it forward to ≥ 0.5.0.
```

**Missing migration file for breaking pinned version** (satisfies `FR-migrations-missing-file-refused`, `AC-migrations-missing-file-refused`):

```
pdeq: recorded 0.3.2 → pinned 0.4.0
✗ Missing migration file for 0.4.0.

  The pinned pdeq lineage declares 0.4.0 as a breaking change, but the
  migration file is not present:
    expected: .pdeq/migrations/0.4.0.md  (not found)

  /pdeq-migrate will not run. No files changed.

  What to do:
    1. Confirm your pdeq submodule is fully checked out: `git submodule update --init`.
    2. If the submodule is correct but the file is missing, the pinned pdeq
       release is incomplete — report to pdeq maintainers and pin to an earlier
       version in the meantime.
```

**Foreign lineage** (satisfies `FR-migrations-lineage-integrity`, `AC-migrations-lineage-refused`):

```
pdeq: recorded 0.4.0 → pinned 0.4.0
✗ Recorded pdeq version 0.4.0 does not match the pinned pdeq lineage.

  The pinned pdeq submodule does not include a release tagged 0.4.0 in its
  history. This project may have been initialized against a fork.

  /pdeq-migrate will not run. No files changed.

  What to do:
    1. Confirm the pdeq submodule URL in .gitmodules matches your release source.
    2. If the project was initialized against a fork, align pdeqVersion with
       the current lineage or re-pin the submodule.
```

Each precondition-error exits non-zero. None perform writes.

---

### 7. Migration file format

One sentence: the markdown file a pdeq maintainer authors for every breaking release.

#### Location and naming

Migrations are authored in the pdeq repo at `migrations/<version>.md`. Consumers reach the same files through the submodule at `.pdeq/migrations/<version>.md`. The filename is the target pdeq version:

```
# In the pdeq repo (authoring):
migrations/0.3.0.md
migrations/0.3.2.md
migrations/0.4.0.md

# In a consumer project (via .pdeq submodule):
.pdeq/migrations/0.3.0.md
.pdeq/migrations/0.3.2.md
.pdeq/migrations/0.4.0.md
```

The two prefixes name the same files in two different filesystem contexts. Surfaces that print expected paths (Surface 8's `expected:` line, runner error messages) use the context-appropriate prefix: the commit-msg gate — which runs only in the pdeq repo — prints `migrations/<version>.md`; the consumer-side runner prints `.pdeq/migrations/<version>.md`. Engineering owns the exact context detection.

One file per pdeq version that introduces a breaking change. Non-breaking versions have no file. Satisfies `FR-migrations-one-per-version`, `FR-migrations-ordered` (semver filename gives the total order), `FR-migrations-author-written`.

#### Structural convention

Every migration file has the same top-to-bottom structure. Sections are declared by H2 headings with a fixed vocabulary, so the runner can parse them deterministically and a human reading the file knows exactly where to look.

```markdown
---
target-version: 0.3.0
breaking: true
summary: Slugs change from FR-auth-1 to FR-auth-email-login.
scope: default
---

# Migration 0.3.0 — Human-readable slug format

## Context

Short prose, for humans only. Why this migration exists, what changed in pdeq,
what the consumer should expect to see in their diff. The runner ignores this
section.

## Mechanical

One code block per operation. The runner executes these sequentially. Each
operation MUST be idempotent — re-running against already-migrated content is
a no-op, not a double-apply.

```shell
# Rewrite numbered slugs to descriptive slugs in product/*.md.
# Uses a fixed lookup table committed to this migration file.
./.pdeq/migrations/0.3.0/rewrite-slugs.sh
```

## Semantic

Optional. A prompt block that is handed to an AI agent along with a declared
set of files. If absent, omit the section entirely — do not include an empty
`## Semantic` heading.

### Files

Glob-style list of files the agent is given as context. The runner loads these
and no others. This is how `AC-migrations-semantic-context` is honored.

- `design/**/*.md`
- `engineering/**/*.md`
- `qa/**/*.md`

### Prompt

Verbatim instructions to the agent. Must:
1. Describe what to look for.
2. Describe what to change.
3. Describe what NOT to change.
4. Instruct the agent to report each file it modified, and to make NO change
   on files that are already conformant (idempotency).
5. Instruct the agent to emit a one-line summary: `updated N of M files`.

## Notes

Optional. Author's notes: edge cases encountered while writing the migration,
rationale for non-obvious choices, links to the PR that introduced the breaking
change. Ignored by the runner.
```

Frontmatter fields:

- `target-version` — the pdeq version this migration advances a project to. Matches the filename.
- `breaking` — always `true` for a file that exists. Present for explicitness and so the pre-commit gate can cross-check.
- `summary` — one-line description, shown in `/pdeq-migrate` output (the text after `—` on the `▸` line).
- `scope` — either `default` (specs root + project config only, the implied scope for `FR-migrations-scoped-writes` / `AC-migrations-scope-respected`) or a glob pattern declaring broader scope. Engineering owns the exact glob syntax — design only establishes that the field exists and is explicit. Satisfies `FR-migrations-scoped-writes`, `NFR-migrations-scope-minimalism`.

Section vocabulary — the runner recognizes exactly these H2 headings: `Context`, `Mechanical`, `Semantic`, `Notes`. Inside `Semantic`, the runner recognizes exactly these H3 headings: `Files`, `Prompt`. Any other heading is treated as prose and ignored.

Satisfies `FR-migrations-mechanical-block`, `FR-migrations-semantic-block`, `FR-migrations-order-within` (Mechanical precedes Semantic structurally in the file, which mirrors runtime order).

#### Worked example — migration 0.3.0 (human-readable slugs)

This is the exemplar migration: it uses both a mechanical block (rename numbered slugs via a lookup table) and a semantic block (Claude reviews downstream specs to make sure renamed slugs are referenced consistently in prose).

````markdown
---
target-version: 0.3.0
breaking: true
summary: Slugs change from FR-auth-1 to FR-auth-email-login.
scope: default
---

# Migration 0.3.0 — Human-readable slug format

## Context

Pdeq 0.3.0 replaces numbered slugs (`FR-ex-auth-1`, `FR-ex-auth-2`) with
descriptive slugs (`FR-ex-auth-email-login`, `FR-ex-auth-forgot-password`).
Numbered slugs are brittle because inserting or removing a requirement
renumbers everything downstream.

This migration does two things:

1. Mechanically rewrites every slug in product/*.md and every
   downstream reference in design/engineering/qa specs, using a
   lookup table committed alongside this file.
2. Semantically reviews prose references that weren't captured by the
   mechanical rewrite — cases where the prose said "requirement 1"
   instead of the slug directly.

## Mechanical

```shell
# Rewrite every slug in the lookup table across every spec file.
# The script is idempotent: if a file has already been migrated,
# no substitutions will match, and the file is left untouched.
./.pdeq/migrations/0.3.0/rewrite-slugs.sh
```

```shell
# Update index.md to use the new slugs. Same lookup table, same
# idempotency guarantee.
./.pdeq/migrations/0.3.0/rewrite-index.sh
```

## Semantic

### Files

- `product/**/*.md`
- `design/**/*.md`
- `engineering/**/*.md`
- `qa/**/*.md`

### Prompt

You are helping migrate a pdeq project from numbered slugs to
descriptive slugs. The mechanical step has already renamed every
`FR-<feature>-<n>` style slug to its descriptive equivalent.

Your job: review prose references that may still point at the old
numbering. Examples to look for and rewrite:

- "requirement 1" or "FR-1" (without the feature prefix) — update
  to the new descriptive slug.
- "see requirement #3 in product/auth.md" — update to the named slug.
- Table rows or bullet lists that enumerate slugs by number.

Do NOT:

- Change any slug that already matches the new `<feature>-<descriptive>`
  pattern — that indicates the file is already conformant.
- Rewrite prose that doesn't reference a slug at all.
- Touch frontmatter, code blocks, or quoted command output.

For each file you change, report: the file path and a one-line summary
of the change. For each file you inspect and leave unchanged, do not
report it — silence means "already conformant."

At the end, emit exactly one line: `updated N of M files` where M is the
total number of files reviewed.

## Notes

The mechanical lookup table is generated from the pre-0.3.0 numbering
used in pdeq itself. Consumer projects whose numbered slugs happen to
collide with this table should run `/pdeq-migrate --dry-run` first and
inspect the preview — the table is conservative (specific feature
prefixes only), so collisions should be rare.
````

How this example demonstrates the format:

- **Both blocks present.** The mechanical block handles the 90% case (every exact numbered-slug match). The semantic block handles the 10% where a human-authored prose reference didn't match the mechanical rule.
- **File-scope discipline.** The semantic block's `### Files` section lists exactly the globs the agent is given. Claude cannot read outside them. This is the design-side expression of `AC-migrations-semantic-context`.
- **Idempotency baked into the prompt.** The prompt explicitly instructs Claude to make no change on already-conformant files and to stay silent about them — so re-running the migration produces no additional edits. This pairs with the mechanical script's "no substitutions match" idempotency for a complete `AC-migrations-idempotent-rerun` / `NFR-migrations-idempotency` story.
- **Mechanical-before-semantic is structural.** The file literally lists `Mechanical` above `Semantic`. This mirrors runtime execution order (`FR-migrations-order-within`) and makes the ordering visible to a human reading the file.

Satisfies `FR-migrations-mechanical-block`, `FR-migrations-semantic-block`, `FR-migrations-order-within`, `FR-migrations-author-written`, `AC-migrations-semantic-context`.

---

### 8. Commit-msg gate output (pdeq repo only)

One sentence: a pdeq maintainer tried to commit a breaking version bump and the gate blocked them for missing a migration.

The commit-msg hook prints to the terminal where the `git commit` command was run. Output format:

```
✗ pdeq commit-msg: breaking-change gate blocked this commit.

  This commit bumps the pdeq version:
    0.3.2 → 0.4.0   (breaking)

  Framework files were modified:
    CLAUDE.md
    scripts/audit-traceability.sh
    pdeq.schema.json

  But no migration file exists for 0.4.0:
    expected: migrations/0.4.0.md  (not found)

  What to do — pick one:

    A) This change is breaking. Author the migration file.
         Create .pdeq/migrations/0.4.0.md
         Include at minimum: frontmatter, Mechanical block (or an explicit
         "## Mechanical\n\nNone." if no mechanical step is needed).

    B) This change is NOT breaking. Downgrade the version bump.
         The version in CLAUDE.md / pdeq.schema.json should change as
         patch (0.3.2 → 0.3.3) or minor (0.3.2 → 0.4.0 with breaking: false
         -- see below), not as a breaking bump.

    C) The gate is wrong about this being a breaking change.
         Add a line to your commit message:
           pdeq-migration: none-required
         This signals to the gate that you have reviewed and this bump
         is deliberately non-breaking despite framework-file changes.
         The gate will log this and allow the commit.
```

Design decisions:

- **One screen of text, no more.** The gate is trying to be helpful, not verbose. Three numbered options (A/B/C), each named in one sentence.
- **Option C is the explicit escape hatch** — a commit trailer `pdeq-migration: none-required` that a maintainer can add when they have consciously decided the bump does not need a migration. Its presence in a commit message instructs the gate to permit the commit and logs the decision. This is how `FR-migrations-no-false-positive` and `AC-migrations-gate-allows-nonbreaking` are expressed in the maintainer UX: the default gate is strict, and the override is explicit and auditable.
- **"Docs-only or non-framework" is never blocked at all**, per `FR-migrations-no-false-positive` and `NFR-migrations-enforcement-precision`. The gate never prints in that case — this output only appears when the gate's preconditions (version bump + framework-file modification) are met.
- Exits non-zero, blocking the commit. Satisfies `FR-migrations-breaking-gate`, `AC-migrations-gate-blocks`.

The non-blocked case produces no gate output at all (`AC-migrations-gate-allows-nonbreaking`, `NFR-migrations-enforcement-precision`).

---

### 9. Self-migration output (dogfood)

One sentence: a pdeq maintainer, at release time, runs `/pdeq-migrate` against pdeq's own specs to advance the pinned-previous-stable version to the version being released.

Output is visually identical to the consumer pending-run output (Surface 3). No special banner, no "dogfood mode" label — the whole point of the bootstrap chain is that the framework manages itself using the exact same command the consumer uses.

```
pdeq: recorded 0.3.2 → pinned 0.4.0
  1 migration pending: 0.4.0

▸ 0.4.0 — pdeqVersion field required
  ✓ mechanical    updated pdeq.json
  ~ semantic      no semantic block
  ✓ migration complete

✓ pdeq: recorded 0.3.2 → 0.4.0
  Ran 1 migration. Review the diff before committing.
```

Design rationale for *not* distinguishing modes: if the CLI output diverged between dogfood and consumer runs, the maintainer would effectively be testing a different codepath than the one consumers will hit. Uniform output keeps the dogfood property meaningful — what works here works in the field.

Satisfies `FR-migrations-bootstrap-chain`, `FR-migrations-self-migration`, `AC-migrations-self-migration-runs`.

---

## Upgrade Entrypoint UX

`/pdeq-migrate` is the verb the runtime uses. `/pdeq-update` is the verb the *consumer* uses. The two are intentionally separate surfaces: `/pdeq-migrate` advances the recorded version against an already-bumped pin, and is what the runner re-enters on retry; `/pdeq-update` is the single, discoverable command a maintainer reaches for when they want to "get on the latest pdeq". `/pdeq-update` performs the pin advance the consumer would otherwise do by hand, then chains into `/pdeq-migrate` so the recorded version catches up, then surfaces any newly-shipped commands so the consumer can use them in the same session.

### Command name decision

The chosen name is **`/pdeq-update`**. Justification:

- **Namespace prefix aids discoverability in crowded slash-command spaces.** The `pdeq-` prefix makes the command unambiguous in projects that have many slash commands from different sources, and signals which framework owns the upgrade flow at a glance.
- **Anticipates a future namespace convention.** This name choice anticipates a future convention where all pdeq slash commands carry the `pdeq-` prefix. Renaming the existing bare-verb commands (`/pdeq-kickoff`, `/pdeq-status`, `/pdeq-migrate`, `/pdeq-impact`, `/pdeq-bootstrap`) is a separate breaking change deferred to a follow-up; introducing the upgrade entrypoint with the prefix sets the precedent without forcing a wider rename now.
- **Extending `/pdeq-migrate` with `--bump` was rejected.** It buries the most user-visible action (advancing the pin) under a flag of a runner-internal command. Maintainers should not need to know the migration runner exists by name to do a routine upgrade — `FR-migrations-update-command` requires the entrypoint be discoverable.

> Implements: `FR-migrations-update-command`.

### Argument surface

```
/pdeq-update                  apply the upgrade end-to-end: bump the pin, then run /pdeq-migrate.
/pdeq-update --dry-run        preview the bump target and the migrations a real /pdeq-update would queue.
                         No writes, no pin change, no migration runs.
```

No `--from` flag (that's a `/pdeq-migrate` recovery affordance for resuming after a failed migration; `/pdeq-update` always starts from the current pin). No `--yes` / `--no-prompt` flag — the chained migration is auto-run on the happy path (see "Migration handoff" below), so there is nothing to confirm.

### Status line

`/pdeq-update` opens with a status line analogous to `/pdeq-migrate`'s, but the comparison is between the *currently pinned* pdeq reference and the *latest available* on the consumer's tracked release lineage:

```
pdeq: pinned 0.2.1 → available 0.4.0
```

This pre-bump line is followed by a blank line and then the bump step. The arrow direction is always `pinned → available`. If the two are equal, this is the no-op case (Surface 11).

> Implements: `FR-migrations-update-command`, `FR-migrations-update-bumps-pin`.

### Surface 10. `/pdeq-update` invocation

One sentence: the command the consumer runs to advance the pinned pdeq reference and apply any migrations the bump made pending, in a single invocation.

- **Entry points**: The consumer types `/pdeq-update` in their coding agent session.
- **Invocation forms**: `/pdeq-update`, `/pdeq-update --dry-run`. See "Argument surface" above.
- **States**: update no-op, update happy-path, update dry-run, update bump-failure. Pending-migration failures during the chained `/pdeq-migrate` step surface as Surface 5 output unchanged — the chained run is not re-skinned.

> Implements: `FR-migrations-update-command`.

### Surface 11. Update no-op output (already current)

One sentence: the user ran `/pdeq-update` but the pinned pdeq reference is already at the latest available version on the lineage.

```
pdeq: pinned 0.4.0 → available 0.4.0
~ Already at 0.4.0 — nothing to update.
```

- Yellow `~` glyph. No green, because no work was done.
- The pin is not touched; `/pdeq-migrate` is not invoked.
- Exits 0.

> Implements: `FR-migrations-update-noop`. Satisfies `AC-migrations-update-noop`.

### Surface 12. Update happy-path output (bump + chained migration)

One sentence: the user ran `/pdeq-update`, the pin advanced cleanly, and the chained `/pdeq-migrate` applied the resulting pending migrations.

The output is composed of three regions, separated by blank lines: the bump region, the chained `/pdeq-migrate` region (visually identical to Surface 3, indented under an `▸ Migrating` lead-in so the user sees the handoff), and the final summary.

```
pdeq: pinned 0.2.1 → available 0.4.0

▸ Bumping pinned pdeq reference
  ✓ pinned pdeq advanced 0.2.1 → 0.4.0

▸ Migrating
  pdeq: recorded 0.2.1 → pinned 0.4.0
    3 migrations pending: 0.3.0, 0.3.2, 0.4.0

  ▸ 0.3.0 — human-readable slug format
    ✓ mechanical    rewrote 42 slugs across 18 files
    ✓ semantic      reviewed 6 files, updated 4
    ✓ migration complete

  ▸ 0.3.2 — roadmap folder
    ✓ mechanical    created roadmap/, moved 2 files
    ~ semantic      no semantic block
    ✓ migration complete

  ▸ 0.4.0 — pdeqVersion field required
    ✓ mechanical    updated pdeq.json
    ~ semantic      no semantic block
    ✓ migration complete

  ✓ pdeq: recorded 0.2.1 → 0.4.0
    Ran 3 migrations. Review the diff before committing.

✓ pdeq: updated to 0.4.0
  New commands available: /foo, /bar
  Updated commands: /pdeq-kickoff
  Removed commands: /old-thing
  Review the diff before committing.
```

Layout rules:

- **Two top-level `▸` lead-ins** — `Bumping pinned pdeq reference` and `Migrating` — bracket the two phases. The bump phase is one or two lines; the migrate phase is the unmodified Surface 3 output, indented two spaces to make the nesting visible.
- **The final `✓ pdeq: updated to <version>` summary** is the user-visible confirmation that the whole `/pdeq-update` flow succeeded. It is distinct from the inner Surface 3 `✓ pdeq: recorded X → Y` line (which only confirms the recorded-version bump).
- **Migration handoff is auto-run, not prompted.** Once the pin has advanced, the chained `/pdeq-migrate` runs immediately without confirmation. Rationale: the consumer already opted in by running `/pdeq-update`; introducing a confirmation step here would split the upgrade into two decisions when the user has already made one. Recovery from a mid-migration failure is the same as for a bare `/pdeq-migrate` — Surface 5 fires, the user fixes the cause, and re-runs `/pdeq-update` (or `/pdeq-migrate` directly; the runner resumes from the last fully-applied migration).
- **On chained-migration failure, the runner breaks out of the indented region before printing Surface 5.** The successful `▸ <version>` migration headers and `✓` / `~` block lines remain indented two spaces under `▸ Migrating` (matching the rest of the chained region). When a migration fails: print the failing block's `✗` line at the same two-space indentation (so the failing-block context stays visually attached to its migration header), then print one blank line, then **drop indentation entirely** and print Surface 5's `✗ Migration X.Y.Z failed at the <block> step.` summary block plus the `pdeq: recorded …` / `Pinned pdeq version: …` / `Remaining: …` / `What to do:` recovery text left-aligned (no indent). The final `✓ pdeq: updated to …` summary is **not** printed — the run failed. The transition from indented to left-aligned is intentional: Surface 5's recovery block has its own column-aligned shape that does not survive nesting, and the user reads it as the authoritative "what to do next" signal regardless of which entrypoint launched the migration. Engineering: this means the chained-migrate inline reuse strips its indent prefix before emitting Surface 5's summary block.
- **In-session command availability is reported on the final summary line.** When the bumped pdeq version introduces, modifies, or removes slash commands, `/pdeq-update` lists them under `New commands available:`, `Updated commands:`, and `Removed commands:` so the consumer sees, in one glance, what changed. The three lines print in that fixed order — `New` → `Updated` → `Removed` — directly under the `✓ pdeq: updated to <version>` summary. Each line is omitted independently when its set is empty; if all three are empty (a release that adds, modifies, and removes no commands), the summary collapses to just `✓ pdeq: updated to 0.4.0` and the diff-reminder line. The `Removed commands:` line names commands whose backing files no longer exist in the new pdeq version — engineering's `scripts/sync-symlinks.sh --json` reports these in its `deleted` array when their dangling symlinks are pruned. Engineering owns *how* in-session availability is achieved (the harness's command-discovery mechanism is out of design's lane); this surface specifies only what the consumer sees and the contract that any command listed under `New` or `Updated` can be immediately invoked, and any command listed under `Removed` is no longer invocable.
- Exits 0.

> Implements: `FR-migrations-update-command`, `FR-migrations-update-bumps-pin`, `FR-migrations-update-chains`, `FR-migrations-update-in-session`. Satisfies `AC-migrations-update-end-to-end`, `AC-migrations-update-in-session`.

### Surface 13. Update dry-run output

One sentence: the user ran `/pdeq-update --dry-run` to preview what the bump would advance to and which migrations would then become pending, without changing the pin or touching any file.

Dry-run uses the same `[DRY RUN — no writes]` header suffix and `•` neutral glyph as Surface 4, so the visual contract is uniform.

```
pdeq: pinned 0.2.1 → available 0.4.0   [DRY RUN — no writes]

▸ Bumping pinned pdeq reference
  • would advance pinned pdeq 0.2.1 → 0.4.0

▸ Migrating
  pdeq: recorded 0.2.1 → pinned 0.4.0   [DRY RUN — no writes]
    3 migrations would become pending: 0.3.0, 0.3.2, 0.4.0

  ▸ 0.3.0 — human-readable slug format
    • mechanical    would rewrite 42 slugs across 18 files
    • semantic      would review 6 files (preview suppressed in dry-run —
                    re-run without --dry-run to see proposed edits)

  ▸ 0.3.2 — roadmap folder
    • mechanical    would create roadmap/, move 2 files
    • semantic      (absent)

  ▸ 0.4.0 — pdeqVersion field required
    • mechanical    would update pdeq.json
    • semantic      (absent)

[DRY RUN] Pin not advanced. Recorded version not changed. No files modified.
          Run /pdeq-update to apply.
```

Design rules for update dry-run:
- **Bump is preview-only.** The "would advance" line names the target version but does not mutate the submodule reference, so the working tree's `.gitmodules` / submodule pointer is untouched.
- **Chained migrate dry-run reuses Surface 4 verbiage** — `would rewrite`, `would create`, file-list preview, semantic preview suppressed — indented two spaces under the `▸ Migrating` lead-in.
- **No `New commands available:` listing.** Dry-run does not surface command availability because nothing has been advanced; listing them would imply they are usable, which they are not until a real `/pdeq-update`.
- **Trailer makes the unchanged-state contract explicit** — pin, recorded version, and working tree all unchanged.
- Exits 0.

#### Dry-run refused during partial-failure recovery

If the project is in the Surface 5 partial-failure recovery state — a previous `/pdeq-migrate` (or chained `/pdeq-update`) failed mid-run, leaving the recorded version partially advanced with one or more migrations still pending against the *current* pin — `/pdeq-update --dry-run` refuses to preview and points the user at `/pdeq-migrate` to finish recovery first.

```
pdeq: pinned 0.4.0 → available 0.4.0   [DRY RUN — no writes]
✗ Cannot dry-run: a previous migration is partially complete.

  Recorded pdeq version: 0.3.0   (advanced from 0.2.1)
  Pinned pdeq version:   0.4.0
  Pending against current pin: 0.3.2, 0.4.0

  A `/pdeq-update --dry-run` preview is not reliable while recovery is in flight —
  the next bump's pending set depends on whether the in-flight migrations
  finish first, and dry-run cannot speak to that.

  What to do:
    1. Run /pdeq-migrate to resume the previous run from 0.3.2.
    2. Once recorded matches pinned, re-run /pdeq-update --dry-run.
```

- Red `✗` matching Surface 5/6 vocabulary; same recorded/pinned/pending block.
- Detection condition: `recorded < pinned` AND at least one migration file is pending against the *current* pin (i.e., a real `/pdeq-migrate` has work left to do). This is exactly the state Surface 5 leaves the project in after a mid-run failure. Engineering's existing `scripts/migrate.sh list-pending` already exposes the pending set against current state — no new helper needed.
- The pin is **not** advanced and `git fetch` is **not** run; refusal happens before any network work, so an offline consumer in mid-recovery still gets a clear message rather than a network-error surface.
- Exits non-zero.
- Bare `/pdeq-update` (no `--dry-run`) is **not** subject to this refusal — it short-circuits the bump (pin already at current via the existing no-op check) and the chained `/pdeq-migrate` resumes from the last fully-applied migration. The dry-run refusal is specific to preview accuracy, not to recovery itself.

> Implements: `FR-migrations-update-dry-run`. Satisfies `AC-migrations-update-dry-run`.

### Surface 14. Update bump-failure output

One sentence: the bump step failed (network error, version-control error, lineage mismatch in the remote, etc.), so `/pdeq-update` aborted before invoking `/pdeq-migrate`.

The output names the failing step in plain English, gives the consumer the actionable cause, and tells them exactly how to retry. The recorded pdeq version is **never** advanced when the bump itself fails, because the migration step does not run.

```
pdeq: pinned 0.2.1 → available 0.4.0

▸ Bumping pinned pdeq reference
  ✗ failed: could not fetch latest pdeq reference.
            underlying error: fatal: unable to access 'https://…': Could not resolve host.

✗ /pdeq-update failed at the bump step.

  Pinned pdeq version:   0.2.1  (unchanged)
  Recorded pdeq version: 0.2.1  (unchanged)
  No migration ran.

  What to do:
    1. Resolve the cause above (check network, credentials, or the
       remote URL configured for the pdeq submodule).
    2. Re-run /pdeq-update. The bump will be retried from the current pin.

  Your working tree is unchanged.
```

Design rules for update bump-failure:
- **Red `✗` on the bump line and on the post-summary header.** Same vocabulary as Surface 5.
- **Both versions reported as unchanged**, so the consumer sees plainly that no half-state exists. This is the load-bearing user-visible confirmation of `FR-migrations-update-bump-failure` — the recorded version did not advance because the migration step was not entered.
- **"What to do" block** names the cause and the exact next command. Re-running `/pdeq-update` is the recovery — there is no separate retry verb.
- **No "No rollback was performed" line.** The bump is atomic-or-not (either the submodule reference advanced cleanly or it didn't), so there is no partial state to roll back. This contrasts with Surface 5's `/pdeq-migrate` failure recovery, which can have partial filesystem writes.
- Exits non-zero.

> Implements: `FR-migrations-update-bump-failure`. Satisfies `AC-migrations-update-bump-failure`.

---

## Interaction Flows

### Flow A — Consumer upgrades normally via `/pdeq-update` (happy path)

The consumer is a pdeq project maintainer who wants to pick up new pdeq features without learning the submodule mechanics or the migration runner by name.

1. Consumer runs `/pdeq-update --dry-run` → sees Surface 13 output: target version `0.4.0`, three migrations that would become pending.
2. Consumer reviews the preview, decides it looks right.
3. Consumer runs `/pdeq-update` → sees Surface 12 output: bump phase advances the pin 0.2.1 → 0.4.0, chained `/pdeq-migrate` applies the three pending migrations, final summary lists newly-available commands.
4. Consumer immediately invokes one of the listed new commands in the same session (no restart required).
5. Consumer runs `git diff` → inspects the changes.
6. Consumer commits with whatever message they like. No pdeq-specific commit rule here — the gate is pdeq-repo only.

Satisfies `AC-migrations-update-end-to-end`, `AC-migrations-update-dry-run`, `AC-migrations-update-in-session`.

### Flow A2 — Consumer upgrades manually via `/pdeq-migrate` (legacy / recovery path)

The consumer (or a tool) bumped the submodule independently and wants to apply migrations directly.

1. Consumer runs `git submodule update --remote .pdeq` → submodule advances from 0.2.1 to 0.4.0.
2. Consumer runs `/pdeq-migrate --dry-run` → sees Surface 4 output listing the three pending migrations.
3. Consumer reviews the preview, decides it looks right.
4. Consumer runs `/pdeq-migrate` → sees Surface 3 output, watches each migration apply, confirms final "recorded 0.2.1 → 0.4.0" success line.
5. Consumer runs `git diff` → inspects the changes.
6. Consumer commits.

This flow is supported but no longer the primary path — `/pdeq-update` covers it end-to-end. `/pdeq-migrate` remains the recovery verb when a previous `/pdeq-update` failed mid-migration.

### Flow B — Consumer re-runs after the first run already succeeded

The consumer forgot whether they ran `/pdeq-migrate` or not after bumping.

1. Consumer runs `/pdeq-migrate` a second time → sees Surface 2 no-op output.
2. Consumer confirms nothing changed.

Satisfies `AC-migrations-idempotent-rerun`, `FR-migrations-idempotent`.

### Flow C — Consumer hits a failure mid-run

The consumer has local uncommitted edits to a file a migration wants to move.

1. Consumer runs `/pdeq-migrate` → sees migrations 0.3.0 apply cleanly, then Surface 5 failure output on 0.3.2.
2. Recorded version is now 0.3.0 (advanced from 0.2.1, but not past the failure).
3. Consumer follows the "What to do" step: stashes changes, re-runs `/pdeq-migrate`.
4. Migrations 0.3.2 and 0.4.0 now apply, final recorded version becomes 0.4.0.

Satisfies `FR-migrations-atomic-bump`, `FR-migrations-failure-report`, `FR-migrations-recoverable-partial`, `AC-migrations-no-bump-on-failure`.

### Flow D — Consumer is on a project that predates migrations

The project was initialized against pdeq 0.1.0, before `pdeqVersion` existed in the config.

1. Consumer bumps submodule to 0.4.0, runs `/pdeq-migrate`.
2. Sees the "absent version" precondition-error (Surface 6, first sub-case).
3. Manually audits their project against 0.4.0 (using the guidance in the error output).
4. Adds `"pdeqVersion": "0.4.0"` to pdeq.json.
5. Future `/pdeq-migrate` runs start from the "no-op" state and proceed normally on the next upgrade.

Satisfies `FR-migrations-absent-version`, `AC-migrations-absent-reported`.

### Flow E — pdeq maintainer, release day

The maintainer is cutting pdeq 0.4.0.

1. Maintainer finishes all 0.4.0 feature work. The in-development pdeq repo is on 0.4.0.
2. Maintainer runs `/pdeq-migrate` from the pdeq repo itself (where the pinned-previous-stable submodule is still on 0.3.2).
3. Sees Surface 9 output — pdeq's own specs advance from 0.3.2 to 0.4.0.
4. Maintainer commits the resulting diff.
5. Maintainer tags 0.4.0.

Satisfies `FR-migrations-bootstrap-chain`, `FR-migrations-self-migration`, `AC-migrations-self-migration-runs`.

### Flow F — pdeq maintainer, pre-commit gate blocks them

The maintainer made a breaking config change and forgot to author the migration.

1. Maintainer runs `git commit` → gate fires, prints Surface 8.
2. Maintainer picks option A (author the migration file), runs `git commit` again.
3. Second commit succeeds.

Alternate path: the maintainer realizes the change is non-breaking, picks option C, adds `pdeq-migration: none-required` to the commit message, and re-commits.

Satisfies `FR-migrations-breaking-gate`, `AC-migrations-gate-blocks`, `AC-migrations-gate-allows-nonbreaking`.

### Flow G — Consumer's `/pdeq-update` fails at the bump step

The consumer is offline (or behind a captive portal) when they run `/pdeq-update`.

1. Consumer runs `/pdeq-update` → bump phase fails, Surface 14 output prints.
2. Consumer reads the recovery hint, reconnects to the network.
3. Consumer re-runs `/pdeq-update` → bump succeeds this time, chained `/pdeq-migrate` runs, Surface 12 output prints.
4. Recorded version is now 0.4.0. No half-state existed between the two attempts.

Satisfies `FR-migrations-update-bump-failure`, `AC-migrations-update-bump-failure`.

### Flow H — Consumer is already at the latest pinned version

The consumer ran `/pdeq-update` last week and runs it again today out of habit.

1. Consumer runs `/pdeq-update` → Surface 11 prints, no work done.
2. Consumer confirms nothing changed.

Satisfies `FR-migrations-update-noop`, `AC-migrations-update-noop`.

---

## Component Specs

### Status line

Every `/pdeq-migrate` invocation opens with one line of the form `pdeq: recorded X → pinned Y`.

- **Variants**: no-op (X == Y), pending (X < Y), precondition-error (X > Y or foreign).
- **Inputs**: recorded version from `pdeq.json`, pinned version from submodule.
- **States**: three visual states map to the three variants above.
- **Behavior**: always printed first. Satisfies `FR-migrations-version-readable`.

### Migration header line

One line per migration during a run: `▸ <version> — <summary>`.

- **Inputs**: version (from filename), summary (from frontmatter `summary`).
- **Behavior**: printed once per migration, before its per-block lines.

### Block status line

One line per mechanical/semantic block within a migration.

- **Variants**: `✓` (ran successfully), `~` (block absent, no-op), `✗` (failed), `•` (dry-run preview).
- **Props**: block name (`mechanical` / `semantic`), status message.
- **Behavior**: always two per migration (both block names always listed, even if one is absent, so the visual shape is uniform).

### Per-migration summary line

One line per migration after its blocks: `✓ migration complete` on success, `✗ Migration X.Y.Z failed at the <block> step.` on failure.

### Run summary block

Printed once at the end of a run. Two lines on success (version-transition line + "Ran N migrations"). Longer block on failure, listing remaining migrations and recovery steps (see Surface 5).

---

## Responsive Behavior

The CLI has no responsive breakpoints in the GUI sense, but terminal output makes two assumptions that need to be documented:

- **Width**: Output assumes ≥ 80 columns. Long file-path lists in dry-run preview are allowed to wrap at word boundaries — no hard column discipline. No ASCII art or tables that would break at narrow widths.
- **Color**: Green / yellow / cyan / red are used but every colored glyph is paired with a character prefix (`✓`, `~`, `?`, `✗`, `•`) so output is readable in a color-disabled terminal or piped to a file. Matches the convention in `scripts/init.sh`.

## Accessibility

- **Screen readers**: the character prefixes (`✓`, `~`, `✗`, `•`) convey state without color. Verbs in status text (`rewrote`, `would rewrite`, `failed`) also convey state redundantly.
- **Keyboard**: `/pdeq-migrate` is a non-interactive command in its primary invocation — no prompts, no TTY required. The `absent recorded version` precondition-error does NOT prompt the user to fill in the field; it fails out and names the fix explicitly. Rationale: a prompt in a failure path is easy to miss when the command is invoked from tooling or CI, and the correct value (the pinned version) is only confirmable by a human.
- **Output is grep-friendly**: every state line starts with a fixed-width prefix (`  ✓`, `▸ `, `✗ `) so simple grep/awk pipelines can filter by state. This is not a user-visible concern per se, but keeps the output diagnostic-friendly for downstream tooling.

---

## Requirements Coverage Check

Every product requirement is addressed somewhere in this design spec, either as a surface, a component, or a documented UX choice:

| Slug | Addressed by |
|---|---|
| `FR-migrations-version-field` | Frontmatter of migration file references the field; `pdeq.json "pdeqVersion"` named in Surface 6 recovery text. Purely config — mostly invisible to user, surfaces when absent. |
| `FR-migrations-version-readable` | Status line component (every `/pdeq-migrate` invocation opens with `recorded X → pinned Y`). |
| `FR-migrations-absent-version` | Surface 6 absent-version sub-case. |
| `FR-migrations-one-per-version` | Migration file naming (`.pdeq/migrations/<version>.md`). |
| `FR-migrations-ordered` | Semver filenames give a total order; `/pdeq-migrate` output lists pending migrations in that order (Surface 3). |
| `FR-migrations-mechanical-block` | Migration file format — `## Mechanical` section; `✓ mechanical` status line per migration. |
| `FR-migrations-semantic-block` | Migration file format — `## Semantic` section; `✓ semantic` / `~ semantic` status line per migration. |
| `FR-migrations-order-within` | File structure places `Mechanical` above `Semantic`; output always lists mechanical status before semantic status. |
| `FR-migrations-author-written` | Surface 7 is an authored markdown file, not a generated diff. |
| `FR-migrations-explicit-run` | `/pdeq-migrate` is a user-invoked slash command; nothing else triggers it. |
| `FR-migrations-pending-detection` | Status line + "N migrations pending: …" header in Surface 3/4. |
| `FR-migrations-ordered-application` | Surface 3 lists migrations in version order, applies them sequentially. |
| `FR-migrations-version-bump` | Final success line: `✓ pdeq: recorded X → Y`. |
| `FR-migrations-noop-when-current` | Surface 2. |
| `FR-migrations-dry-run` | Surface 4 + `--dry-run` flag on `/pdeq-migrate`. |
| `FR-migrations-idempotent` | Flow B; migration file prompt instructs semantic block to be idempotent; mechanical scripts documented as idempotent. |
| `FR-migrations-scoped-writes` | `scope` frontmatter field in migration file format; default scope is specs root + config. |
| `FR-migrations-breaking-gate` | Surface 8 pre-commit output. |
| `FR-migrations-no-false-positive` | Surface 8 option C (`pdeq-migration: none-required` trailer); gate silence on docs-only commits. |
| `FR-migrations-lineage-integrity` | Surface 6 foreign-lineage sub-case. |
| `FR-migrations-bootstrap-chain` | Surface 9 — dogfood run uses the same command. |
| `FR-migrations-self-migration` | Surface 9 + Flow E. |
| `FR-migrations-atomic-bump` | Surface 5: recorded version advances only to last fully-applied migration; shown explicitly in failure output. |
| `FR-migrations-failure-report` | Surface 5: names migration, block, cause, recovery. |
| `FR-migrations-recoverable-partial` | Surface 5: "No rollback was performed. … review `git status`." + "re-run /pdeq-migrate will resume at X.Y.Z". |
| `FR-migrations-unknown-version` | Surface 6 newer-than-pinned sub-case. |
| `NFR-migrations-idempotency` | Migration file semantic-block prompt mandates idempotent behavior; mechanical scripts' idempotency documented. |
| `NFR-migrations-determinism` | Semver ordering + "pending: X, Y, Z" header showing the exact order. |
| `NFR-migrations-scope-minimalism` | Dry-run lists exactly what would change; `scope` frontmatter field makes broader scope explicit. |
| `NFR-migrations-enforcement-precision` | Surface 8 gate is silent on non-matching commits; option C exists for deliberate non-breaking cases. |
| `AC-migrations-noop-when-current` | Surface 2. |
| `AC-migrations-ordered-apply` | Surface 3. |
| `AC-migrations-no-bump-on-failure` | Surface 5. |
| `AC-migrations-dry-run-accurate` | Surface 4 — preview enumerates exact files / exact changes mechanical block would make. |
| `AC-migrations-gate-blocks` | Surface 8. |
| `AC-migrations-gate-allows-nonbreaking` | Surface 8 silence on non-matching commits + option C. |
| `AC-migrations-semantic-context` | Migration file format — `## Semantic / ### Files` block declares exactly the files the agent sees. |
| `AC-migrations-idempotent-rerun` | Flow B → Surface 2 on second run. |
| `AC-migrations-absent-reported` | Surface 6 absent-version sub-case. |
| `AC-migrations-lineage-refused` | Surface 6 newer-than-pinned and foreign-lineage sub-cases. |
| `AC-migrations-scope-respected` | Default `scope: default` in frontmatter; `scope` field required to be explicit when broader. |
| `AC-migrations-self-migration-runs` | Surface 9 + Flow E. |
| `FR-migrations-nonbreaking-advance` | Surface 3b non-breaking advance output. |
| `AC-migrations-nonbreaking-advance` | Surface 3b. |
| `FR-migrations-missing-file-refused` | Surface 6 missing-migration-file sub-case. |
| `AC-migrations-missing-file-refused` | Surface 6 missing-migration-file sub-case. |
| `FR-migrations-update-command` | Surfaces 10–14; command-name decision in "Upgrade Entrypoint UX". |
| `FR-migrations-update-bumps-pin` | Surface 12 bump phase; status-line `pinned → available` comparison. |
| `FR-migrations-update-chains` | Surface 12 chained `/pdeq-migrate` region; auto-run handoff (no prompt). |
| `FR-migrations-update-in-session` | Surface 12 final summary `New commands available:` / `Updated commands:` listing. Engineering owns the mechanism. |
| `FR-migrations-update-noop` | Surface 11. |
| `FR-migrations-update-bump-failure` | Surface 14; both versions reported unchanged. |
| `FR-migrations-update-dry-run` | Surface 13; `--dry-run` flag; explicit unchanged-state trailer. |
| `AC-migrations-update-end-to-end` | Surface 12 + Flow A. |
| `AC-migrations-update-noop` | Surface 11 + Flow H. |
| `AC-migrations-update-in-session` | Surface 12 final summary listing. |
| `AC-migrations-update-bump-failure` | Surface 14 + Flow G. |
| `AC-migrations-update-dry-run` | Surface 13. |

---

## Open Questions

- **Dry-run treatment of semantic blocks.** This spec commits to a choice: dry-run skips executing the semantic agent and prints a summary notice instead. The alternative — running the agent in a read-only mode — would double the cost of a dry-run and produce a preview that might differ from the real run's output anyway. If engineering hits a case where users genuinely need the semantic preview, we can revisit with a `--dry-run=deep` flag; this spec does not reserve one yet.
- **Failure recovery policy.** This spec commits to "leave-as-is" — no auto-rollback, failure output tells the user to inspect `git status`. Product's open question lists this as engineering's call; recording here that the design assumes leave-as-is. If engineering picks auto-rollback instead, Surface 5's "No rollback was performed" line needs to be rewritten to describe the rolled-back state.
- **`scope` glob syntax.** The frontmatter field is defined; the glob grammar is not. Engineering owns.
- **Exact non-breaking override trailer text.** The spec proposes `pdeq-migration: none-required` as the commit-message trailer. If engineering prefers a different convention (a git notes entry, a file marker, etc.), Surface 8 option C needs updating. The design assumption is "something lightweight in the commit message itself" so the decision is auditable via `git log`.
- **Migration file path context-awareness.** Resolved: authored at `migrations/<ver>.md` in the pdeq repo, exposed to consumers at `.pdeq/migrations/<ver>.md` via submodule. Surface 8 (commit-msg gate, pdeq-repo-only) prints `migrations/`; consumer-side runner prints `.pdeq/migrations/`. Engineering owns context detection.
- **`/pdeq-update` command name.** Resolved: the command is `/pdeq-update` (not the bare-verb `/update`, not `/pdeq-migrate --bump`). Justification in "Upgrade Entrypoint UX → Command name decision".
- **Auto-run vs. prompt for chained migration.** Resolved: auto-run. Once the consumer has typed `/pdeq-update`, they have already opted in to the upgrade; a confirmation prompt would split one decision into two. Recovery on mid-migration failure goes through Surface 5 unchanged.
- **In-session command availability — engineering handoff.** Surface 12 specifies what the consumer sees after a successful `/pdeq-update`: a final summary line listing `New commands available:` and/or `Updated commands:`, plus the contract that any command listed is immediately invokable in the same session. The mechanism by which the harness discovers and exposes commands shipped by the newly-pinned pdeq version mid-session is **out of design's lane and explicitly handed off to engineering**. Engineering must ensure the listed commands are usable when the user reads the summary line; how that is achieved (process re-exec, command-table refresh, on-demand resolution, etc.) is engineering's call.

---

## Cross-References

- Product requirements: `../../product/migrations.md`
- Glossary terms used: *Migration*, *Mechanical transform*, *Semantic transform*, *Breaking change*, *Bootstrap chain* — see `../../glossary.md`.
- Existing slash-command style reference: `../../.claude/commands/pdeq-kickoff.md`, `../../.claude/commands/pdeq-status.md`, `../../.claude/commands/pdeq-impact.md`, `../../.claude/commands/pdeq-bootstrap.md`, `../../.claude/commands/pdeq-migrate.md`.
- Terminal output conventions reused: `../../scripts/init.sh` (green `✓`, yellow `~`, cyan `?`, plus this spec's additions `✗` red and `•` neutral for dry-run).
