---
product-hash: ce08243bf9b234ad469f976f112637e8e8aa0218660bc7ea4a097dac79428e46
product-slugs: [AC-harness-agnostic-bootstrap-no-subagent, AC-harness-agnostic-codex-install, AC-harness-agnostic-codex-no-commands, AC-harness-agnostic-default-claude, AC-harness-agnostic-installer-output, AC-harness-agnostic-migration-end-to-end, AC-harness-agnostic-migration-idempotent, AC-harness-agnostic-migration-warns-customized, AC-harness-agnostic-multi-install, AC-harness-agnostic-no-new-deps, AC-harness-agnostic-pi-install, AC-harness-agnostic-pi-no-commands, AC-harness-agnostic-remove-harness, AC-harness-agnostic-self-host-migrates, AC-harness-agnostic-unknown-init, AC-harness-agnostic-unknown-schema, FR-harness-agnostic-bootstrap-inline, FR-harness-agnostic-canonical-agents-file, FR-harness-agnostic-claude-import, FR-harness-agnostic-commands-per-harness, FR-harness-agnostic-commands-source-path, FR-harness-agnostic-config, FR-harness-agnostic-content-portable, FR-harness-agnostic-hard-cutover, FR-harness-agnostic-harness-change-reinstall, FR-harness-agnostic-migration, FR-harness-agnostic-migration-default-harness, FR-harness-agnostic-migration-idempotent, FR-harness-agnostic-migration-removes-subagents, FR-harness-agnostic-multiple-per-install, FR-harness-agnostic-no-import-in-canonical, FR-harness-agnostic-no-subagent-files, FR-harness-agnostic-per-harness-install, FR-harness-agnostic-removed-harness-cleaned, FR-harness-agnostic-skill-claude-only, FR-harness-agnostic-symlink-include, FR-harness-agnostic-unknown-rejected, FR-harness-agnostic-v1-harness-set, NFR-harness-agnostic-docs-multi-harness, NFR-harness-agnostic-installer-reporting, NFR-harness-agnostic-no-new-deps, NFR-harness-agnostic-symlink-portability, NFR-migrations-idempotency]
---
# Harness-Agnostic Install — Technical Spec

> Based on requirements in `../../product/harness-agnostic.md`

## What We're Building

Pdeq's installer and submodule layout are being refactored so that the agent-orienting prose, slash-command source files, and consumer-facing skill assets are addressed by harness-neutral paths inside the submodule, and the installer materializes per-harness "views" on top of them in the consumer's project at install time. The submodule's canonical agent-instructions file becomes `AGENTS.md` at every lane; Claude Code consumers continue to get `CLAUDE.md` files via `@import`, and other harnesses get `AGENTS.md` symlinks pointing at the same canonical source. The change ships at pdeq 0.4.0 with a single migration that brings existing 0.3.x consumers from the old layout to the new one in one explicit step.

The approach uses an internal harness adapter table inside `scripts/init.sh` keyed on harness identifiers. Each adapter declares two things: the per-lane agent-file name the harness reads (`CLAUDE.md`, `AGENTS.md`, etc.), and the relative directory inside the consumer's project where that harness expects markdown-defined slash commands (or empty when the harness does not support markdown slash commands). The installer iterates the consumer's `harnesses` list, calls into each adapter to materialize files, and reports per-file what harness drove the action. No new install dependencies are introduced — the adapter table is plain bash arrays and the materialization is `ln -s` and one-line `echo` redirects, mirroring the patterns already in use.

The chosen alternative was to vendor or depend on `block/ai-rules`. That tool covers the same conceptual surface but adds a Rust binary as an install dependency, supports more harnesses than v1 needs, and does not currently support Pi. The bash-internal adapter table is ~60 lines of code, matches the existing project style, and keeps the install-dependency floor at `git + bash`.

## Technical Approach

The work splits into five concrete tracks that run in roughly this order:

1. **Submodule layout migration** — rename canonical files in the pdeq repo and move slash-command source files to a harness-neutral path. This is a one-time edit, executed in the pdeq repo for the 0.4.0 release.
2. **Bootstrap inline fold** — delete `.claude/agents/bootstrap-analyzer/*` and `.claude/agents/bootstrap-generator/*` from the pdeq repo and inline their prompts into `.claude/commands/pdeq-bootstrap.md` (which is itself moving to the new commands directory).
3. **Schema and installer changes** — add `harnesses` to `pdeq.schema.json`, add a harness adapter table to `scripts/init.sh`, replace the hard-coded Claude path emission with per-harness loops, add a `--harnesses` flag.
4. **Migration file** — author `migrations/0.4.0.md` containing the mechanical transform that brings a consumer from the 0.3.x layout to the 0.4.0 layout.
5. **Documentation and meta** — update `README.md` and the consumer-project skill copy to describe pdeq as multi-harness, and update the root `CLAUDE.md` / `AGENTS.md` (post-rename) to remove Claude Code-specific phrasing in the prose itself.

## Data Model

No persistent runtime data model. The two state surfaces are:

- **`pdeq.json` `harnesses` field** — a JSON array of harness identifier strings. Validated by `pdeq.schema.json`. Read by `scripts/init.sh` at install time and by `scripts/migrate.sh` at migration time. Other scripts that need to know harness state (e.g. a future harness-aware audit) read the same field.
- **Consumer filesystem layout post-install** — see the per-harness materialization table below. The filesystem layout *is* the data model from the consumer's perspective: which files exist at which paths drives which harness can read pdeq prose.

### Harness adapter table

Stored as parallel bash associative arrays in `scripts/init.sh`. Adding a new harness is a two-line edit; the install logic itself does not change.

| Harness ID | Agent file name | Commands dir (per-consumer-project root, when supported) | Notes |
|---|---|---|---|
| `claude` | `CLAUDE.md` | `.claude/commands` | Claude supports `@import` syntax; installer emits a one-line import file. |
| `codex` | `AGENTS.md` | _(none — codex CLI has no markdown slash commands at v1)_ | Installer creates an `AGENTS.md` symlink only. |
| `pi` | `AGENTS.md` | _(none — pi slash commands are TypeScript extensions)_ | Installer creates an `AGENTS.md` symlink only. |

This table is the **harness adapter table** referenced throughout this spec and in the glossary. It is the single point of extension for new harnesses.

### Submodule canonical path map (post-rename)

| Old path (pre-0.4.0) | New path (0.4.0+) | Owner |
|---|---|---|
| `CLAUDE.md` | `AGENTS.md` | Pdeq repo + consumer submodule view |
| `product/CLAUDE.md` | `product/AGENTS.md` | Same |
| `design/CLAUDE.md` | `design/AGENTS.md` | Same |
| `engineering/CLAUDE.md` | `engineering/AGENTS.md` | Same |
| `qa/CLAUDE.md` | `qa/AGENTS.md` | Same |
| `roadmap/CLAUDE.md` | `roadmap/AGENTS.md` | Same |
| `.claude/commands/pdeq-*.md` | `pdeq-rules/commands/pdeq-*.md` | Same |
| `.claude/agents/bootstrap-analyzer/*` | _(deleted — folded into `pdeq-rules/commands/pdeq-bootstrap.md`)_ | Same |
| `.claude/agents/bootstrap-generator/*` | _(deleted — folded into `pdeq-rules/commands/pdeq-bootstrap.md`)_ | Same |
| `.claude/skills/pdeq/SKILL.md` | _(unchanged — Claude-specific surface, not part of the canonical content)_ | Same |

Note: `.claude/skills/pdeq/SKILL.md` stays at its existing path because Claude is the only harness with this concept at v1 (per `FR-harness-agnostic-skill-claude-only`). Pdeq does not need to introduce a neutral path for an asset that has no non-Claude consumers.

## API / Interface Design

### `pdeq.schema.json` — new field

```json
"harnesses": {
  "type": "array",
  "description": "List of coding-agent harness identifiers this project uses. The installer materializes per-harness agent-instructions files and slash-command directories. Omit to default to ['claude'] (v0.3.x compatibility).",
  "items": { "type": "string", "enum": ["claude", "codex", "pi"] },
  "uniqueItems": true,
  "default": ["claude"],
  "examples": [["claude"], ["codex"], ["pi"], ["claude", "codex"]]
}
```

The `enum` is the v1 closed set. New harnesses are added by extending the enum and the adapter table in the same commit.

### `scripts/init.sh` — new flag

```
--harnesses <list>      Comma-separated harness IDs (e.g. claude,codex). Default: claude.
                        Recognized: claude, codex, pi.
```

The interactive mode (`--interactive`) gains a prompt for this value when not supplied via flag and not present in an existing `pdeq.json`.

### `scripts/init.sh` — internal API (per-harness materialization helpers)

Two new functions, both pure-bash, both idempotent:

- `_materialize_agent_file <lane_abs_path> <import_relpath> <label>` — for each enabled harness, materialize the agent-instructions file at `lane_abs_path` using either `@import` (claude) or a symlink (others). `import_relpath` is the path from `lane_abs_path` to the canonical `AGENTS.md` inside the submodule. `label` is the user-facing display name ("product", "root", etc.).
- `_materialize_commands <harness_id>` — for harnesses whose adapter declares a commands directory, mirror every file in `pdeq-rules/commands/` into `<git_root>/<commands_dir>/` using relative symlinks. No-op for harnesses without a commands directory.

Both helpers respect the existing `skip`/`green` output convention. The harness name appears in every output line (per `NFR-harness-agnostic-installer-reporting`).

### `scripts/migrate.sh` — no API change

The migration runner is generic. The 0.4.0 migration file is the only new artifact in that lane.

## Component Architecture

The change touches four components. Each is a thin layer that already exists; the change is additive logic, not a new module.

1. **`pdeq.schema.json`** — gains the `harnesses` field. Consumed by editor-side JSON-schema validators and by `init.sh`'s own validation step.
2. **`scripts/init.sh`** — gains the adapter table, the two new helpers above, the `--harnesses` flag, and the per-harness materialization loops. The script's overall structure (parse args → detect install location → 10-step install) is unchanged; Steps 3, 4, and 6 are rewritten to call the new helpers.
3. **`scripts/migrate.sh`** — unchanged. Runs `migrations/0.4.0.md` like any other migration file.
4. **`migrations/0.4.0.md`** — new file. Contains the mechanical transform described under "Migration mechanical transform" below.

The Claude-skill copy under `.claude/skills/pdeq/SKILL.md` gets its user-facing prose updated (separately from the installer logic) to acknowledge multi-harness consumers, but its file path and format are unchanged.

## State Management

There is no in-memory state. Persistent state lives in `pdeq.json` (the `harnesses` field) and on the filesystem (which files exist at which paths). The installer reads the config, decides what should exist, and reconciles the filesystem to match. Re-running the installer's harness-materialization step is the supported way to apply a change to the `harnesses` list (per `FR-harness-agnostic-harness-change-reinstall`).

## Error Handling

- **Unknown harness identifier (init time):** `init.sh` validates each identifier against the adapter table's key set. On mismatch, exit non-zero with `"Unrecognized harness '<id>'. Recognized: claude, codex, pi."` Implements `FR-harness-agnostic-unknown-rejected` / `AC-harness-agnostic-unknown-init`.
- **Unknown harness identifier (schema time):** the JSON-schema `enum` constraint enforces this for any tool reading `pdeq.json`. Implements `AC-harness-agnostic-unknown-schema`.
- **Symlink target already exists as a regular file:** `_materialize_agent_file` checks for an existing non-symlink at the destination before writing. If present, it skips with a warning (matching the existing convention from Step 3 of `init.sh` for `CLAUDE.md` collisions). Consumer-authored content is never overwritten.
- **Migration on a project whose harness list was already migrated:** the 0.4.0 migration's mechanical block is idempotent (see `FR-harness-agnostic-migration-idempotent`). Every branch short-circuits when the destination state is already correct.
- **Migration encounters consumer-authored subagent files:** when `.claude/agents/bootstrap-analyzer` or `.claude/agents/bootstrap-generator` is a regular file (not a pdeq-managed symlink), the migration leaves the file in place and prints a one-line warning. Same pattern as the 0.3.0 migration's customized-command-file handling. Implements `FR-harness-agnostic-migration-removes-subagents` / `AC-harness-agnostic-migration-warns-customized`.

## Performance Considerations

Negligible. The installer's per-file work scales with `lanes × harnesses + commands × claude-or-cursor-harnesses-enabled`, which is bounded by tens of files for any realistic install. The dominant cost remains submodule clone time, which this change does not affect.

## Security Considerations

- **Symlink targets are constructed from the harness adapter table and the submodule's tracked file list.** Neither comes from untrusted user input. The relative-path resolution is identical in shape to the existing `init.sh` Step 6, which is already audited.
- **The migration's mechanical block runs `rm` on `.claude/agents/bootstrap-*` symlinks.** It restricts `rm` to entries that are confirmed symlinks (`[ -L ... ]`) — regular files are left in place per the policy above. This bounds the migration's blast radius to pdeq-installed artifacts.

## Implementation Plan

Ordered so each step is independently reviewable and each builds on the previous. Steps 1–3 happen in the pdeq repo before the 0.4.0 tag; step 4 ships in the same commit as the tag.

1. **Schema first** — add the `harnesses` field to `pdeq.schema.json` with the v1 enum. No behavioral change yet, but downstream code can begin to assume the field's shape and editors get autocomplete immediately. Implements `FR-harness-agnostic-config`, `FR-harness-agnostic-v1-harness-set`.
2. **Submodule layout rename** — rename `CLAUDE.md` → `AGENTS.md` at the root and every lane; move `.claude/commands/pdeq-*.md` → `pdeq-rules/commands/pdeq-*.md`; delete `.claude/agents/bootstrap-analyzer/` and `.claude/agents/bootstrap-generator/`; fold their prompts into `pdeq-rules/commands/pdeq-bootstrap.md`; update internal cross-references inside the prose so no `CLAUDE.md` or `.claude/commands/` references remain. This is the bulk of the diff and lives entirely in the pdeq repo. Implements `FR-harness-agnostic-canonical-agents-file`, `FR-harness-agnostic-content-portable`, `FR-harness-agnostic-no-import-in-canonical`, `FR-harness-agnostic-bootstrap-inline`, `FR-harness-agnostic-no-subagent-files`, `FR-harness-agnostic-commands-source-path`.
3. **Installer adapter table + helpers** — add the harness adapter table, the two `_materialize_*` helpers, and the `--harnesses` flag to `scripts/init.sh`. Rewrite Steps 3, 4, and 6 of `init.sh` to call the helpers per-enabled-harness. Read `harnesses` from `pdeq.json` when present, fall back to flag value, fall back to `["claude"]`. Implements `FR-harness-agnostic-per-harness-install`, `FR-harness-agnostic-claude-import`, `FR-harness-agnostic-symlink-include`, `FR-harness-agnostic-commands-per-harness`, `FR-harness-agnostic-multiple-per-install`, `FR-harness-agnostic-unknown-rejected`, `FR-harness-agnostic-harness-change-reinstall`, `FR-harness-agnostic-removed-harness-cleaned`, `FR-harness-agnostic-skill-claude-only`, `NFR-harness-agnostic-installer-reporting`, `NFR-harness-agnostic-symlink-portability`.
4. **Migration file** — author `migrations/0.4.0.md` (see "Migration mechanical transform" below). Bump `VERSION` to `0.4.0`. The pre-commit migrations gate (`scripts/audit-migrations.sh`) enforces that a breaking version bump ships with its migration file. Implements `FR-harness-agnostic-migration`, `FR-harness-agnostic-hard-cutover`, `FR-harness-agnostic-migration-default-harness`, `FR-harness-agnostic-migration-idempotent`, `FR-harness-agnostic-migration-removes-subagents`.
5. **Docs + self-host update** — update `README.md` and `.claude/skills/pdeq/SKILL.md` to describe pdeq as multi-harness and to list the v1 supported harnesses. Update pdeq's own `pdeq.json` to declare `harnesses: ["claude", "codex"]` so the self-host is itself the first multi-harness install. Implements `NFR-harness-agnostic-docs-multi-harness`.

### Migration mechanical transform (0.4.0)

The migration's mechanical block operates entirely on the consumer's git root. It performs the following idempotent steps in order:

1. **Read consumer's `harnesses` list** — if `pdeq.json` lacks the field, treat as `["claude"]` (per `FR-harness-agnostic-migration-default-harness`). Validate each entry against the v1 enum; bail with the standard schema-mismatch error if any entry is unknown.
2. **For each lane location** (`<git_root>` for the root, plus each of `product/`, `design/`, `engineering/`, `qa/`, `roadmap/` under `specsRoot`):
   - Identify the existing `CLAUDE.md` at the location. If it is a pdeq-managed `@import` one-liner pointing at `.pdeq/.../CLAUDE.md`, rewrite the import target to `.pdeq/.../AGENTS.md` (when `claude` is in the harness list) or remove it (when `claude` is not).
   - For every non-Claude harness in the list, create the harness's agent-file as a symlink to the corresponding `AGENTS.md` inside the submodule. Branch on `[ -e "$target" ]` and skip if a file already exists, with the same warning-and-skip pattern the 0.3.0 migration uses.
3. **Re-point command symlinks** — for every entry under `.claude/commands/pdeq-*.md` that is a symlink, rewrite the target from `.pdeq/.claude/commands/pdeq-<name>.md` to `.pdeq/pdeq-rules/commands/pdeq-<name>.md`. This is required because the source files moved inside the submodule.
4. **Remove deleted subagent symlinks** — at `.claude/agents/bootstrap-analyzer` and `.claude/agents/bootstrap-generator`, if the entry is a symlink, `rm` it. If it is a regular file, leave it and print the one-line warning.
5. **Write `harnesses` to `pdeq.json`** when the field is absent, defaulting to `["claude"]`. The pdeq.json mutation goes through the same minimal-edit path the existing migrations use.

The migration file's `scope` is `default` (specsRoot + `pdeq.json`) plus an explicit declaration of `.claude/commands/**` and `.claude/agents/**` per `FR-migrations-scoped-writes`, since those paths sit at the git root rather than under `specsRoot`.

## Code Map

| Slug | Planned location | Status |
|---|---|---|
| FR-harness-agnostic-config | pdeq.schema.json | planned |
| FR-harness-agnostic-v1-harness-set | pdeq.schema.json | planned |
| FR-harness-agnostic-multiple-per-install | scripts/init.sh | planned |
| FR-harness-agnostic-unknown-rejected | scripts/init.sh; pdeq.schema.json | planned |
| FR-harness-agnostic-canonical-agents-file | AGENTS.md; product/AGENTS.md; design/AGENTS.md; engineering/AGENTS.md; qa/AGENTS.md; roadmap/AGENTS.md | planned |
| FR-harness-agnostic-content-portable | AGENTS.md; product/AGENTS.md; design/AGENTS.md; engineering/AGENTS.md; qa/AGENTS.md; roadmap/AGENTS.md | planned |
| FR-harness-agnostic-no-import-in-canonical | AGENTS.md; product/AGENTS.md; design/AGENTS.md; engineering/AGENTS.md; qa/AGENTS.md; roadmap/AGENTS.md | planned |
| FR-harness-agnostic-per-harness-install | scripts/init.sh | planned |
| FR-harness-agnostic-claude-import | scripts/init.sh | planned |
| FR-harness-agnostic-symlink-include | scripts/init.sh | planned |
| FR-harness-agnostic-commands-per-harness | scripts/init.sh | planned |
| FR-harness-agnostic-commands-source-path | pdeq-rules/commands/pdeq-bootstrap.md; pdeq-rules/commands/pdeq-impact.md; pdeq-rules/commands/pdeq-kickoff.md; pdeq-rules/commands/pdeq-migrate.md; pdeq-rules/commands/pdeq-status.md; pdeq-rules/commands/pdeq-visualize.md | planned |
| FR-harness-agnostic-bootstrap-inline | pdeq-rules/commands/pdeq-bootstrap.md | planned |
| FR-harness-agnostic-no-subagent-files | — | planned |
| FR-harness-agnostic-skill-claude-only | scripts/init.sh | planned |
| FR-harness-agnostic-migration | migrations/0.4.0.md | planned |
| FR-harness-agnostic-hard-cutover | migrations/0.4.0.md | planned |
| FR-harness-agnostic-migration-default-harness | migrations/0.4.0.md | planned |
| FR-harness-agnostic-migration-idempotent | migrations/0.4.0.md | planned |
| FR-harness-agnostic-migration-removes-subagents | migrations/0.4.0.md | planned |
| FR-harness-agnostic-harness-change-reinstall | scripts/init.sh | planned |
| FR-harness-agnostic-removed-harness-cleaned | scripts/init.sh | planned |
| NFR-harness-agnostic-no-new-deps | scripts/init.sh; migrations/0.4.0.md | planned |
| NFR-harness-agnostic-installer-reporting | scripts/init.sh | planned |
| NFR-harness-agnostic-symlink-portability | scripts/init.sh; migrations/0.4.0.md | planned |
| NFR-harness-agnostic-docs-multi-harness | README.md; .claude/skills/pdeq/SKILL.md | planned |

`FR-harness-agnostic-no-subagent-files` has no planned code location — it is a *negative* requirement (a set of files that do not exist). The audit verifies absence via the migration's removal step; coverage is implicit in the migration's correctness, not in any standing source file.
