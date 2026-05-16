# Harness-Agnostic Install

## Overview

Pdeq today is shipped as a Claude Code framework — its agent-orienting prose lives in `CLAUDE.md` files, its slash commands live under `.claude/commands/`, and its installer wires everything for a Claude Code consumer. Maintainers who want to drive a pdeq-managed project from a different coding agent (Codex CLI, Pi, etc.) cannot do so without manually mirroring files into the harness's expected paths, and pdeq self-host is locked to whichever harness the maintainer is running today.

This feature decouples pdeq from any one harness. A consumer declares which coding-agent harnesses they use, and pdeq's installer materializes the right surface area at the right paths for each — using the cross-harness `AGENTS.md` convention as the canonical agent-instructions file, with Claude Code-specific files generated as a thin compatibility layer when Claude is among the enabled harnesses. v1 supports Claude Code, Codex CLI, and Pi. Other harnesses can be added later by extending an internal adapter table; the install mechanism does not change.

This is a breaking change to the consumer file layout and ships at pdeq 0.4.0 with a hard cutover via `/pdeq-migrate`. There is no soft-transition window, no parallel old-and-new file shape, and no symlink-back compatibility shims past the migration step itself.

## User Stories

- As a **pdeq maintainer**, I want to drive pdeq self-host work from any coding agent (not just Claude Code) so that I am not locked into one tool while developing the framework itself.
- As a **consumer-project maintainer using Codex or Pi**, I want pdeq to install correctly into my project so that my agent reads the pdeq instructions natively and I get the same lane discipline, traceability, and slug system that Claude Code consumers get.
- As a **consumer-project maintainer who switches harnesses**, I want to add or remove a harness from my project's pdeq install without re-running `init.sh` or hand-editing files so that swapping or trying a new agent has near-zero overhead.
- As a **consumer-project maintainer on Claude Code today**, I want my existing project to keep working after upgrading to pdeq 0.4.0 so that the breaking layout change is applied for me, in one step, with no manual file shuffling.
- As a **pdeq maintainer**, I want the install requirements to stay limited to git and bash so that consumers don't have to install a new toolchain (Rust, Node, Python) to use pdeq.

## Requirements

### Harness Selection

Consumer projects declare which coding-agent harnesses they use. The declaration drives every installer decision about which files to materialize at which paths.

- **Harness list in config** `FR-harness-agnostic-config`: A consumer project records its enabled harnesses in the project config as a list. Each list entry is a recognized harness identifier. The list defaults to a Claude-only configuration when omitted, so existing 0.3.x consumers upgrade without explicit opt-in.
- **v1 supported harnesses** `FR-harness-agnostic-v1-harness-set`: At v1, the recognized harness identifiers are `claude` (Claude Code), `codex` (Codex CLI), and `pi` (Pi). Adding a new harness identifier later does not require a breaking version bump — it requires only an entry in pdeq's internal adapter table and, where applicable, a new file-shape rule.
- **Multiple harnesses per install** `FR-harness-agnostic-multiple-per-install`: A consumer may enable more than one harness simultaneously. Pdeq materializes the union of every enabled harness's required files; nothing prevents a project from being usable from both Claude Code and Codex at the same time.
- **Unknown harness rejected** `FR-harness-agnostic-unknown-rejected`: An unrecognized harness identifier in the config is rejected by the installer and the schema validator with a clear message naming the offending identifier and listing the recognized set, so silent typos do not produce empty installs.

### Canonical Agent-Instructions File

The agent-orienting prose pdeq ships moves to a single canonical filename that every supported harness can read, eliminating the need for per-harness duplication of the same content.

- **Canonical AGENTS.md at every lane** `FR-harness-agnostic-canonical-agents-file`: Inside the pdeq submodule, the agent-orienting prose at the framework root and at each functional-area lane (`product/`, `design/`, `engineering/`, `qa/`, `roadmap/`) is named `AGENTS.md` rather than `CLAUDE.md`. There is exactly one canonical file per location; no duplicate-content per-harness variants exist in the submodule.
- **AGENTS.md is platform-neutral content** `FR-harness-agnostic-content-portable`: The content of `AGENTS.md` makes no assumption about which harness will read it. References to harness-specific tooling (e.g., "Claude Code's `Task` tool") are removed or rewritten in harness-neutral terms ("delegate to a subagent," "spawn a subtask").
- **No Claude-specific import syntax in canonical content** `FR-harness-agnostic-no-import-in-canonical`: The canonical `AGENTS.md` files in the submodule do not use Claude Code's `@import` syntax internally. Cross-file inclusion within the canonical content is handled by ordinary prose references ("see `product/AGENTS.md`"), not by an import directive that only one harness understands.

### Per-Harness Materialization at Install Time

The installer translates the harness list into a concrete set of files in the consumer's project, choosing the right filename and the right inclusion mechanism for each harness.

- **Per-harness install** `FR-harness-agnostic-per-harness-install`: At every location where pdeq would otherwise place an agent-instructions file (project root and each lane folder under `specsRoot`), the installer materializes one file per enabled harness, named according to that harness's convention (e.g., `CLAUDE.md` for `claude`, `AGENTS.md` for `codex` and `pi`). Each materialized file points at the same canonical content — no duplicated prose.
- **Claude inclusion via @import** `FR-harness-agnostic-claude-import`: When `claude` is enabled, the consumer's `CLAUDE.md` files are one-line `@import` references to the canonical `AGENTS.md` inside the submodule. This preserves the existing Claude Code behavior where the consumer can append project-specific instructions below the import.
- **Non-Claude inclusion via symlink** `FR-harness-agnostic-symlink-include`: When a non-Claude harness is enabled, the consumer's harness-named file (e.g., `AGENTS.md` for Codex and Pi) is a symbolic link pointing at the canonical `AGENTS.md` inside the submodule. The harness reads the file's content transparently through the symlink.
- **Per-harness slash commands** `FR-harness-agnostic-commands-per-harness`: When a harness supports markdown-defined slash commands (Claude Code does; Codex CLI and Pi do not at v1), the installer mirrors pdeq's slash-command source files into that harness's expected commands directory. Harnesses that do not support markdown slash commands receive no commands directory; the consumer invokes pdeq workflows in those harnesses by asking the agent in prose ("kickoff a feature for X").
- **Slash-command source path** `FR-harness-agnostic-commands-source-path`: The source-of-truth location for pdeq's slash commands inside the submodule is named such that it does not imply a single harness owns it. The installer reads from this neutral source when materializing per-harness command directories.

### Bootstrap Without Subagent Files

The bootstrap workflow today depends on Claude Code-specific subagent definition files. To work in any harness, the bootstrap workflow expresses the same logic without requiring the harness to support a separate subagent file format.

- **Bootstrap inline prompts** `FR-harness-agnostic-bootstrap-inline`: The bootstrap workflow's prompts (analyzer + generator) live inside the bootstrap slash command itself rather than in separate per-subagent files. The command instructs the running agent to play the analyzer role, then the generator role, in sequence; it does not depend on the harness's ability to load a named subagent definition. Harnesses that do support subagent definitions (e.g., Claude Code) may still spawn subagents internally, but the command does not require it.
- **No standalone subagent files shipped** `FR-harness-agnostic-no-subagent-files`: The pdeq submodule does not ship any harness-specific subagent definition files (e.g., `.claude/agents/*`). All workflow logic is captured in the slash-command source files or in the canonical `AGENTS.md` prose, both of which any supported harness can read.

### Consumer-Project Skill (Claude-only)

Pdeq ships a Claude Code "skill" file that helps Claude Code surface pdeq commands in onboarding flows. This file is intentionally Claude-specific and is not part of the cross-harness contract.

- **Skill stays Claude-specific** `FR-harness-agnostic-skill-claude-only`: The Claude Code skill file is materialized only when `claude` is among the enabled harnesses. Other harnesses do not receive an equivalent file, and pdeq does not attempt to unify "skill" semantics across harnesses at v1.

### Migration to 0.4.0

Existing consumer projects on pdeq 0.3.x have the old file layout (`CLAUDE.md` in the submodule, `.claude/commands/` as the only command path, `.claude/agents/bootstrap-*` subagent files). The 0.4.0 migration cuts over to the new layout in one explicit step.

- **Migration runs at 0.4.0** `FR-harness-agnostic-migration`: The pdeq 0.4.0 migration brings a consumer's project from the 0.3.x layout to the 0.4.0 layout. It renames the consumer's per-lane `CLAUDE.md` import files to the path-shape required by the consumer's enabled harness list, removes references to the deleted `.claude/agents/bootstrap-*` files, and (re-)creates per-harness symlinks to match the harness list recorded in the consumer's config. The migration is invoked by the existing `/pdeq-migrate` flow; it requires no special command.
- **Hard cutover, no compatibility shims** `FR-harness-agnostic-hard-cutover`: After the 0.4.0 migration runs, the old file layout (bare `.claude/agents/bootstrap-*` files; `CLAUDE.md` files at lane locations when `claude` is not in the harness list; `.claude/commands/` directory when `claude` is not in the harness list) does not persist as a parallel valid state. There is no transitional period where both old and new layouts work.
- **Default harness list applied during migration** `FR-harness-agnostic-migration-default-harness`: When a 0.3.x consumer's config has no `harnesses` field at migration time, the migration treats the harness list as `["claude"]` so existing Claude Code consumers see no behavioral change beyond the file-layout normalization.
- **Migration is idempotent** `FR-harness-agnostic-migration-idempotent`: Re-running the 0.4.0 migration on an already-migrated project produces no further file changes. This is a property already required of all migrations by `NFR-migrations-idempotency` and is restated here for clarity in the harness-agnostic context.
- **Migration removes deleted subagent files** `FR-harness-agnostic-migration-removes-subagents`: The migration removes any consumer-installed symlinks at `.claude/agents/bootstrap-analyzer` and `.claude/agents/bootstrap-generator` that were created by a pre-0.4.0 `init.sh`. Consumer-authored content at those paths is left untouched and the migration prints a one-line warning naming the file, consistent with the policy used by the 0.3.0 migration for customized command files.

### Re-Adding or Removing Harnesses Post-Install

A consumer who later wants to enable a new harness (or disable one) does so by editing their config and re-running the relevant installer step, not by bumping pdeq.

- **Harness list change is a re-install operation** `FR-harness-agnostic-harness-change-reinstall`: Adding or removing a harness from the `harnesses` list takes effect on the next run of the installer's harness-materialization step. The same step is idempotent: re-running it without changing the list produces no file changes.
- **Removed harness leaves no stale files** `FR-harness-agnostic-removed-harness-cleaned`: When a consumer removes a harness from their config and re-runs the installer's harness-materialization step, files that the installer had previously materialized for that harness (and no other harness) are removed. Files that were authored by the consumer, or that serve a harness still in the list, are not removed.

### Non-Functional Requirements

- **No new install dependencies** `NFR-harness-agnostic-no-new-deps`: The installer continues to require only `git` and `bash`. No language toolchain (Rust, Node, Python, Go) and no new binary becomes a hard install dependency at v1. Adding a new harness to the adapter table later may not introduce such a dependency without explicit product approval.
- **Installer reports per-harness actions** `NFR-harness-agnostic-installer-reporting`: The installer's output makes clear which file is being materialized for which harness, so a consumer can audit at a glance that their harness list was honored.
- **Symlink targets are portable** `NFR-harness-agnostic-symlink-portability`: Symlinks the installer creates use relative paths so the install survives the consumer cloning the project to a different absolute location. This matches the symlink convention `init.sh` already uses for scripts and command files.
- **Documentation reflects multi-harness reality** `NFR-harness-agnostic-docs-multi-harness`: User-facing documentation (README, the consumer-project skill copy where applicable) describes pdeq as a multi-harness framework, not as Claude Code-specific. Specific harnesses are named only when relevant (e.g., for invocation examples).

## Acceptance Criteria

These cover the observable outcomes QA will test directly.

- [ ] **Default harness list is Claude** `AC-harness-agnostic-default-claude`: A consumer project whose `pdeq.json` omits the `harnesses` field is treated by every pdeq tool (installer, migration, audit) as if `harnesses: ["claude"]` were declared.
- [ ] **Codex-only install reads pdeq prose natively** `AC-harness-agnostic-codex-install`: A consumer project freshly initialized with `harnesses: ["codex"]` has an `AGENTS.md` at the project root and at each lane folder under `specsRoot`. Each `AGENTS.md` resolves through to the same canonical content shipped by the pdeq submodule. No `CLAUDE.md` files exist at those locations.
- [ ] **Pi install reads pdeq prose natively** `AC-harness-agnostic-pi-install`: A consumer project freshly initialized with `harnesses: ["pi"]` has an `AGENTS.md` at the project root and at each lane folder under `specsRoot`, resolving to the same canonical content. No `CLAUDE.md` files exist at those locations.
- [ ] **Multi-harness install materializes union** `AC-harness-agnostic-multi-install`: A consumer project freshly initialized with `harnesses: ["claude", "codex"]` has both `CLAUDE.md` and `AGENTS.md` at the project root and at each lane folder. Both files resolve to the same canonical content (Claude via `@import`, Codex via symlink). Editing the canonical file is reflected when either harness reads its respective file.
- [ ] **Unknown harness rejected on init** `AC-harness-agnostic-unknown-init`: Running `init.sh` with `--harnesses claude,bogus` exits non-zero, names `bogus` as the unrecognized identifier, and lists the recognized set. No partial install is left behind.
- [ ] **Unknown harness rejected by schema** `AC-harness-agnostic-unknown-schema`: A `pdeq.json` whose `harnesses` field contains an unrecognized identifier fails JSON-schema validation with a message that names the offending identifier.
- [ ] **Codex install has no commands directory** `AC-harness-agnostic-codex-no-commands`: A consumer project freshly initialized with `harnesses: ["codex"]` has no markdown-slash-command directory created by pdeq for the codex harness. The consumer can still invoke pdeq workflows via prose (this is documentation-tested, not file-tested).
- [ ] **Pi install has no commands directory** `AC-harness-agnostic-pi-no-commands`: A consumer project freshly initialized with `harnesses: ["pi"]` has no markdown-slash-command directory created by pdeq for the pi harness.
- [ ] **Bootstrap works without subagent files** `AC-harness-agnostic-bootstrap-no-subagent`: After pdeq 0.4.0 install, the bootstrap slash command (`/pdeq-bootstrap` in Claude Code, prose invocation in other harnesses) executes the analyzer-then-generator workflow successfully without depending on any file under `.claude/agents/`.
- [ ] **Migration on existing 0.3.x project** `AC-harness-agnostic-migration-end-to-end`: Running the 0.4.0 migration on an existing 0.3.x consumer project (no `harnesses` field in `pdeq.json`) results in the 0.4.0 layout: per-lane `CLAUDE.md` files still exist (claude is the default harness), `.claude/agents/bootstrap-*` symlinks are removed, and the recorded pdeq version advances to `0.4.0`.
- [ ] **Migration is idempotent** `AC-harness-agnostic-migration-idempotent`: Re-running the 0.4.0 migration on an already-migrated project produces no file changes and no error.
- [ ] **Migration leaves customized subagent files alone** `AC-harness-agnostic-migration-warns-customized`: When a consumer's `.claude/agents/bootstrap-analyzer` or `.claude/agents/bootstrap-generator` is a regular file (consumer customization) rather than a pdeq-managed symlink, the migration leaves the file in place and prints a one-line warning naming the file.
- [ ] **No new install dependency** `AC-harness-agnostic-no-new-deps`: A consumer who has only `git` and `bash` available (no Rust, Node, Python, or Go toolchain) can complete `init.sh` and `/pdeq-migrate` against pdeq 0.4.0 without installing additional tooling.
- [ ] **Removed harness cleans up files** `AC-harness-agnostic-remove-harness`: A consumer project on `harnesses: ["claude", "codex"]` that edits the config to `harnesses: ["claude"]` and re-runs the installer's harness-materialization step ends up with `CLAUDE.md` files intact and `AGENTS.md` files (the codex-only ones) removed at every lane location. Files at locations where the consumer had authored their own `AGENTS.md` are not touched.
- [ ] **Installer output names the harness per file** `AC-harness-agnostic-installer-output`: The installer's per-file log lines identify which harness drove the materialization (e.g., "Created product/AGENTS.md (harness: codex)"), so a consumer reading the install output can audit harness coverage.
- [ ] **Self-host migrates** `AC-harness-agnostic-self-host-migrates`: When pdeq's own repo bumps its pinned `.pdeq/` to 0.4.0 and runs `/pdeq-migrate` against its own specs, the migration completes cleanly and advances pdeq's recorded version. The pdeq self-host install is the test case for the canonical layout.

## Open Questions

- **Skill files for non-Claude harnesses**: Pi has its own "skill" / "extension" concept; Codex CLI does not. Whether to ever ship harness-specific skill equivalents is deferred. v1 ships the Claude skill only when `claude` is enabled and ships nothing equivalent for other harnesses.
- **Configurable canonical-content directory name**: The new neutral name for the slash-command source directory inside the submodule (today `.claude/commands/`) is left to engineering. A working assumption is `pdeq-rules/commands/` per the design conversation, but the exact path is an engineering concern as long as it is harness-neutral and stable.
- **Future harness additions**: Cursor, Goose, Gemini, Copilot, AMP, and Cline are explicitly out of scope for v1. Each has a known file convention (per the `block/ai-rules` mapping table) and would be cheap to add later, but doing so is gated on actual user demand. Track in `roadmap/harness-agnostic.md` if and when a request appears.
- **Native Pi extension for slash commands**: Pi's slash-command surface is TypeScript-based, not markdown-based. Shipping a native Pi extension that surfaces `/pdeq-*` commands inside Pi is deferred. v1 documents that Pi consumers invoke pdeq workflows in prose. Track in roadmap if Pi adoption justifies the extension work.

## Dependencies

- **Migration system (`product/migrations.md`):** the 0.3.x → 0.4.0 cutover is delivered as a standard migration file (`migrations/0.4.0.md`). The migration system itself does not change for this feature; only a new migration file is authored.
- **Config schema (`pdeq.schema.json`):** gains a `harnesses` field with the v1 enumeration of recognized identifiers.
- **CLI conventions (`product/cli-conventions.md`):** the `pdeq-` prefix convention is unchanged. The slash-command source location moves from `.claude/commands/` to a harness-neutral directory inside the submodule, but the prefix and discoverability contract is unaffected.
- **Glossary:** introduces the terms *Harness*, *Harness adapter table*, *Canonical agent-instructions file*, and *Harness materialization*. See `../glossary.md`.
