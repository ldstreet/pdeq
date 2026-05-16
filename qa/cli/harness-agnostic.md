---
product-hash: ce08243bf9b234ad469f976f112637e8e8aa0218660bc7ea4a097dac79428e46
product-slugs: [AC-harness-agnostic-bootstrap-no-subagent, AC-harness-agnostic-codex-install, AC-harness-agnostic-codex-no-commands, AC-harness-agnostic-default-claude, AC-harness-agnostic-installer-output, AC-harness-agnostic-migration-end-to-end, AC-harness-agnostic-migration-idempotent, AC-harness-agnostic-migration-warns-customized, AC-harness-agnostic-multi-install, AC-harness-agnostic-no-new-deps, AC-harness-agnostic-pi-install, AC-harness-agnostic-pi-no-commands, AC-harness-agnostic-remove-harness, AC-harness-agnostic-self-host-migrates, AC-harness-agnostic-unknown-init, AC-harness-agnostic-unknown-schema, FR-harness-agnostic-bootstrap-inline, FR-harness-agnostic-canonical-agents-file, FR-harness-agnostic-claude-import, FR-harness-agnostic-commands-per-harness, FR-harness-agnostic-commands-source-path, FR-harness-agnostic-config, FR-harness-agnostic-content-portable, FR-harness-agnostic-hard-cutover, FR-harness-agnostic-harness-change-reinstall, FR-harness-agnostic-migration, FR-harness-agnostic-migration-default-harness, FR-harness-agnostic-migration-idempotent, FR-harness-agnostic-migration-removes-subagents, FR-harness-agnostic-multiple-per-install, FR-harness-agnostic-no-import-in-canonical, FR-harness-agnostic-no-subagent-files, FR-harness-agnostic-per-harness-install, FR-harness-agnostic-removed-harness-cleaned, FR-harness-agnostic-skill-claude-only, FR-harness-agnostic-symlink-include, FR-harness-agnostic-unknown-rejected, FR-harness-agnostic-v1-harness-set, NFR-harness-agnostic-docs-multi-harness, NFR-harness-agnostic-installer-reporting, NFR-harness-agnostic-no-new-deps, NFR-harness-agnostic-symlink-portability, NFR-migrations-idempotency]
---
# Harness-Agnostic Install — Test Plan

> Based on requirements in `../../product/harness-agnostic.md`
> Based on technical spec in `../../engineering/cli/harness-agnostic.md`

## What We're Testing

The 0.4.0 transition of pdeq from a Claude-Code-only install to a multi-harness install, covering: fresh installs for each supported harness, multi-harness installs, the 0.4.0 migration applied to existing 0.3.x consumer projects, the bootstrap workflow operating without subagent definition files, harness-list edits after install, and the no-new-dependency guarantee. All test cases run against the `cli` platform — pdeq's own scripts and installer, not consumer-application code.

## Coverage Matrix

| Requirement | Test Cases | Status |
|---|---|---|
| `AC-harness-agnostic-default-claude` | `TC-harness-agnostic-default-claude-resolved` | Not started |
| `AC-harness-agnostic-codex-install` | `TC-harness-agnostic-codex-install-files`, `TC-harness-agnostic-codex-symlink-content` | Not started |
| `AC-harness-agnostic-pi-install` | `TC-harness-agnostic-pi-install-files`, `TC-harness-agnostic-pi-symlink-content` | Not started |
| `AC-harness-agnostic-multi-install` | `TC-harness-agnostic-multi-install-both-files`, `TC-harness-agnostic-multi-install-canonical-edit-propagates` | Not started |
| `AC-harness-agnostic-unknown-init` | `TC-harness-agnostic-init-unknown-rejected` | Not started |
| `AC-harness-agnostic-unknown-schema` | `TC-harness-agnostic-schema-unknown-rejected` | Not started |
| `AC-harness-agnostic-codex-no-commands` | `TC-harness-agnostic-codex-no-commands-dir` | Not started |
| `AC-harness-agnostic-pi-no-commands` | `TC-harness-agnostic-pi-no-commands-dir` | Not started |
| `AC-harness-agnostic-bootstrap-no-subagent` | `TC-harness-agnostic-bootstrap-no-subagent-files`, `TC-harness-agnostic-bootstrap-prompts-inlined` | Not started |
| `AC-harness-agnostic-migration-end-to-end` | `TC-harness-agnostic-migrate-cutover`, `TC-harness-agnostic-migrate-bumps-version` | Not started |
| `AC-harness-agnostic-migration-idempotent` | `TC-harness-agnostic-migrate-rerun-noop` | Not started |
| `AC-harness-agnostic-migration-warns-customized` | `TC-harness-agnostic-migrate-customized-subagent-warn` | Not started |
| `AC-harness-agnostic-no-new-deps` | `TC-harness-agnostic-install-no-extra-toolchain` | Not started |
| `AC-harness-agnostic-remove-harness` | `TC-harness-agnostic-remove-harness-cleanup`, `TC-harness-agnostic-remove-harness-preserves-authored` | Not started |
| `AC-harness-agnostic-installer-output` | `TC-harness-agnostic-installer-names-harness-per-line` | Not started |
| `AC-harness-agnostic-self-host-migrates` | `TC-harness-agnostic-self-host-migrate-clean` | Not started |

## Test Cases

Test cases are grouped by scenario. Each runs against a temporary directory created by the test harness, with a freshly-cloned (or symlinked) pdeq submodule pinned at the version under test.

### Default-Harness Behavior

Verifies that consumer projects without an explicit `harnesses` field behave as if `claude` were declared, so 0.3.x consumers see no behavioral change beyond the file-layout normalization at migration time.

#### Default harness list is Claude `TC-harness-agnostic-default-claude-resolved`
- **Type**: Integration
- **Covers**: `AC-harness-agnostic-default-claude`, `FR-harness-agnostic-config`, `FR-harness-agnostic-migration-default-harness`
- **Preconditions**: A consumer project initialized via `init.sh` with no `--harnesses` flag and no pre-existing `pdeq.json`.
- **Steps**:
  1. Run `init.sh` against the temporary directory.
  2. Read the generated `pdeq.json`.
  3. Inspect the per-lane files materialized.
- **Expected Result**: `pdeq.json` either omits `harnesses` or contains `["claude"]`. Per-lane `CLAUDE.md` files exist; per-lane `AGENTS.md` files do not (since claude is the only enabled harness).

### Single-Harness Fresh Install — Codex

Verifies a consumer who initializes with only `codex` gets a working Codex CLI install with no Claude-specific artifacts.

#### Codex install creates AGENTS.md at every lane `TC-harness-agnostic-codex-install-files`
- **Type**: Integration
- **Covers**: `AC-harness-agnostic-codex-install`, `FR-harness-agnostic-per-harness-install`, `FR-harness-agnostic-symlink-include`
- **Preconditions**: Fresh temporary directory; pdeq submodule available.
- **Steps**:
  1. Run `init.sh --harnesses codex`.
  2. List files at the project root and at each of `product/`, `design/`, `engineering/`, `qa/`, `roadmap/`.
- **Expected Result**: An `AGENTS.md` exists at the project root and at each lane folder. No `CLAUDE.md` exists at any of those locations. The `AGENTS.md` files are symlinks pointing at the corresponding `AGENTS.md` inside the `.pdeq/` submodule.

#### Codex AGENTS.md resolves to canonical content `TC-harness-agnostic-codex-symlink-content`
- **Type**: Integration
- **Covers**: `AC-harness-agnostic-codex-install`, `FR-harness-agnostic-canonical-agents-file`
- **Preconditions**: Output of `TC-harness-agnostic-codex-install-files`.
- **Steps**:
  1. Cat the project-root `AGENTS.md`.
  2. Cat `.pdeq/AGENTS.md` directly.
  3. Compare.
- **Expected Result**: Byte-identical content. The symlink resolves transparently.

### Single-Harness Fresh Install — Pi

#### Pi install creates AGENTS.md at every lane `TC-harness-agnostic-pi-install-files`
- **Type**: Integration
- **Covers**: `AC-harness-agnostic-pi-install`, `FR-harness-agnostic-symlink-include`
- **Preconditions**: Fresh temporary directory; pdeq submodule available.
- **Steps**:
  1. Run `init.sh --harnesses pi`.
  2. List files at the project root and at each lane.
- **Expected Result**: Same shape as `TC-harness-agnostic-codex-install-files`. `AGENTS.md` symlinks present; no `CLAUDE.md` files.

#### Pi AGENTS.md resolves to canonical content `TC-harness-agnostic-pi-symlink-content`
- **Type**: Integration
- **Covers**: `AC-harness-agnostic-pi-install`, `FR-harness-agnostic-canonical-agents-file`
- **Preconditions**: Output of `TC-harness-agnostic-pi-install-files`.
- **Steps**: Cat the project-root `AGENTS.md`; cat `.pdeq/AGENTS.md`; compare.
- **Expected Result**: Byte-identical content.

### Multi-Harness Install

#### Multi-harness install materializes union `TC-harness-agnostic-multi-install-both-files`
- **Type**: Integration
- **Covers**: `AC-harness-agnostic-multi-install`, `FR-harness-agnostic-multiple-per-install`, `FR-harness-agnostic-claude-import`, `FR-harness-agnostic-symlink-include`
- **Preconditions**: Fresh temporary directory; pdeq submodule available.
- **Steps**:
  1. Run `init.sh --harnesses claude,codex`.
  2. List files at every lane.
- **Expected Result**: Both `CLAUDE.md` and `AGENTS.md` exist at the project root and at each lane folder. The `CLAUDE.md` files are one-line `@import` references; the `AGENTS.md` files are symlinks.

#### Editing canonical content propagates to both harness views `TC-harness-agnostic-multi-install-canonical-edit-propagates`
- **Type**: Integration
- **Covers**: `AC-harness-agnostic-multi-install`, `FR-harness-agnostic-canonical-agents-file`
- **Preconditions**: Output of `TC-harness-agnostic-multi-install-both-files`. (Run in a writable copy of the pdeq submodule — the test must not mutate the actual repo.)
- **Steps**:
  1. Append a recognizable sentinel line to `.pdeq/product/AGENTS.md` in the test scratch copy.
  2. Cat the consumer's `product/AGENTS.md` (which symlinks to the canonical).
  3. Resolve and cat the file that the consumer's `product/CLAUDE.md` `@import`s.
- **Expected Result**: Both reads return the sentinel. Both harness "views" reflect a single edit.

### Validation — Unknown Harness Identifier

#### `init.sh` rejects unknown harness `TC-harness-agnostic-init-unknown-rejected`
- **Type**: Integration
- **Covers**: `AC-harness-agnostic-unknown-init`, `FR-harness-agnostic-unknown-rejected`
- **Preconditions**: Fresh temporary directory.
- **Steps**:
  1. Run `init.sh --harnesses claude,bogus`.
  2. Capture exit code and stderr.
  3. List the temporary directory contents.
- **Expected Result**: Exit code is non-zero. Stderr names `bogus` as the unrecognized identifier and lists the recognized set (`claude`, `codex`, `pi`). No `pdeq.json`, no `CLAUDE.md`, no `AGENTS.md` was created — the install failed before performing partial work.

#### `pdeq.json` schema rejects unknown harness `TC-harness-agnostic-schema-unknown-rejected`
- **Type**: Unit
- **Covers**: `AC-harness-agnostic-unknown-schema`, `FR-harness-agnostic-unknown-rejected`
- **Preconditions**: A `pdeq.json` containing `"harnesses": ["claude", "bogus"]` and the `pdeq.schema.json` from the version under test.
- **Steps**:
  1. Validate `pdeq.json` against `pdeq.schema.json` using any JSON-schema validator (`ajv`, `python -m jsonschema`, or equivalent).
- **Expected Result**: Validation fails. The error message identifies the `harnesses` field and names `bogus` as the offending value.

### Slash-Command Surface

#### Codex install does not create a commands directory `TC-harness-agnostic-codex-no-commands-dir`
- **Type**: Integration
- **Covers**: `AC-harness-agnostic-codex-no-commands`, `FR-harness-agnostic-commands-per-harness`
- **Preconditions**: Fresh temporary directory.
- **Steps**:
  1. Run `init.sh --harnesses codex`.
  2. Check for `.claude/commands/`, `.codex/commands/`, or any other commands directory created by pdeq.
- **Expected Result**: No commands directory was created by pdeq for the codex harness. (`.claude/commands/` may exist if it was already present in the consumer project for unrelated reasons, but pdeq did not create it.)

#### Pi install does not create a commands directory `TC-harness-agnostic-pi-no-commands-dir`
- **Type**: Integration
- **Covers**: `AC-harness-agnostic-pi-no-commands`, `FR-harness-agnostic-commands-per-harness`
- **Preconditions**: Fresh temporary directory.
- **Steps**: Same shape as `TC-harness-agnostic-codex-no-commands-dir`, with `--harnesses pi`.
- **Expected Result**: No commands directory created by pdeq for the pi harness.

### Bootstrap Without Subagent Files

#### No subagent files in submodule `TC-harness-agnostic-bootstrap-no-subagent-files`
- **Type**: Unit
- **Covers**: `AC-harness-agnostic-bootstrap-no-subagent`, `FR-harness-agnostic-no-subagent-files`
- **Preconditions**: Pdeq submodule pinned at the version under test.
- **Steps**:
  1. Check for the existence of `.claude/agents/bootstrap-analyzer/` and `.claude/agents/bootstrap-generator/` inside the submodule.
- **Expected Result**: Neither directory exists.

#### Bootstrap command embeds analyzer + generator prompts `TC-harness-agnostic-bootstrap-prompts-inlined`
- **Type**: Unit
- **Covers**: `AC-harness-agnostic-bootstrap-no-subagent`, `FR-harness-agnostic-bootstrap-inline`
- **Preconditions**: Pdeq submodule pinned at the version under test.
- **Steps**:
  1. Read `pdeq-rules/commands/pdeq-bootstrap.md`.
  2. Search for a section that captures the analyzer role and a section that captures the generator role.
- **Expected Result**: The file contains both role descriptions inline. The agent reading the command file has everything it needs to execute the workflow without a separate subagent definition.

### 0.4.0 Migration on Existing 0.3.x Project

#### Migration brings 0.3.x consumer to 0.4.0 layout `TC-harness-agnostic-migrate-cutover`
- **Type**: Integration
- **Covers**: `AC-harness-agnostic-migration-end-to-end`, `FR-harness-agnostic-migration`, `FR-harness-agnostic-hard-cutover`, `FR-harness-agnostic-migration-default-harness`
- **Preconditions**: A consumer project freshly initialized at pdeq 0.3.x (no `harnesses` field, `.claude/agents/bootstrap-*` symlinks present, `.claude/commands/pdeq-*.md` symlinks targeting `.pdeq/.claude/commands/...`). The pdeq submodule is then bumped to 0.4.0.
- **Steps**:
  1. Run `/pdeq-migrate` (or invoke `scripts/migrate.sh` directly).
  2. Inspect `pdeq.json`, per-lane files, `.claude/commands/`, and `.claude/agents/`.
- **Expected Result**: `pdeq.json` now contains `harnesses: ["claude"]`. Per-lane `CLAUDE.md` files remain present (claude is the default). `.claude/commands/pdeq-*.md` symlinks now resolve to `.pdeq/pdeq-rules/commands/pdeq-*.md`. The `.claude/agents/bootstrap-analyzer` and `.claude/agents/bootstrap-generator` symlinks have been removed.

#### Migration advances recorded version to 0.4.0 `TC-harness-agnostic-migrate-bumps-version`
- **Type**: Integration
- **Covers**: `AC-harness-agnostic-migration-end-to-end`
- **Preconditions**: Output of `TC-harness-agnostic-migrate-cutover`.
- **Steps**: Read `pdeq.json`'s `pdeqVersion` field.
- **Expected Result**: Value is `0.4.0`.

#### Re-running the migration is a no-op `TC-harness-agnostic-migrate-rerun-noop`
- **Type**: Integration
- **Covers**: `AC-harness-agnostic-migration-idempotent`, `FR-harness-agnostic-migration-idempotent`, `NFR-migrations-idempotency`
- **Preconditions**: Output of `TC-harness-agnostic-migrate-cutover`. Capture a recursive snapshot of the consumer project (file paths, sizes, symlink targets, content hashes).
- **Steps**:
  1. Run `/pdeq-migrate` again.
  2. Snapshot the consumer project again.
  3. Diff the two snapshots.
- **Expected Result**: Empty diff. No files added, removed, modified, or re-targeted.

#### Customized subagent file warned and left alone `TC-harness-agnostic-migrate-customized-subagent-warn`
- **Type**: Integration
- **Covers**: `AC-harness-agnostic-migration-warns-customized`, `FR-harness-agnostic-migration-removes-subagents`
- **Preconditions**: A 0.3.x consumer project where `.claude/agents/bootstrap-analyzer` (or `bootstrap-generator`) has been replaced by a regular file (consumer customization). Pdeq submodule then bumped to 0.4.0.
- **Steps**:
  1. Capture the file's content hash.
  2. Run `/pdeq-migrate`; capture stderr.
  3. Re-read the file; re-hash.
- **Expected Result**: The file still exists with identical content (hash unchanged). Stderr contains a one-line warning naming the file. The other (non-customized) subagent symlink was removed as expected.

### No-New-Dependency Guarantee

#### Install completes without additional toolchain `TC-harness-agnostic-install-no-extra-toolchain`
- **Type**: Integration
- **Covers**: `AC-harness-agnostic-no-new-deps`, `NFR-harness-agnostic-no-new-deps`
- **Preconditions**: A container or chroot that has `git` and `bash` available but no `cargo`, `rustc`, `node`, `npm`, `python`, `go`, or any other language toolchain on `PATH`.
- **Steps**:
  1. Clone the consumer project and the pdeq submodule.
  2. Run `init.sh --harnesses claude,codex,pi`.
  3. Run `/pdeq-migrate` if applicable.
  4. Inspect exit codes and process traces (e.g. with `strace -f -e execve` on Linux).
- **Expected Result**: Both commands complete successfully. The process trace shows only `git`, `bash`, `ln`, `sed`, `awk`, `grep`, `mkdir`, `mv`, `rm`, and other POSIX utilities being invoked — no language toolchain binary is executed.

### Removing a Harness Post-Install

#### Removing a harness removes its files `TC-harness-agnostic-remove-harness-cleanup`
- **Type**: Integration
- **Covers**: `AC-harness-agnostic-remove-harness`, `FR-harness-agnostic-removed-harness-cleaned`, `FR-harness-agnostic-harness-change-reinstall`
- **Preconditions**: A consumer project installed with `harnesses: ["claude", "codex"]`. Both `CLAUDE.md` and `AGENTS.md` files exist at every lane.
- **Steps**:
  1. Edit `pdeq.json` to set `harnesses: ["claude"]`.
  2. Re-run the installer's harness-materialization step (e.g. `init.sh --reconcile-harnesses` or equivalent — exact flag named by engineering).
  3. List files at every lane.
- **Expected Result**: `CLAUDE.md` files remain. `AGENTS.md` symlinks (the ones pdeq materialized for codex) have been removed at every lane.

#### Removing a harness does not touch consumer-authored files `TC-harness-agnostic-remove-harness-preserves-authored`
- **Type**: Integration
- **Covers**: `AC-harness-agnostic-remove-harness`, `FR-harness-agnostic-removed-harness-cleaned`
- **Preconditions**: A consumer project installed with `harnesses: ["claude", "codex"]`. The consumer has replaced one of the pdeq-managed `AGENTS.md` symlinks with a regular file containing their own content.
- **Steps**:
  1. Capture the file's content hash.
  2. Edit `pdeq.json` to set `harnesses: ["claude"]`.
  3. Re-run the installer's harness-materialization step.
  4. Re-read the consumer-authored file; re-hash.
- **Expected Result**: The consumer-authored file is preserved (hash unchanged). The installer leaves regular files alone, just as it does at first-install time. The other pdeq-managed `AGENTS.md` symlinks at lanes the consumer did not author are removed.

### Installer Output

#### Each install line names the driving harness `TC-harness-agnostic-installer-names-harness-per-line`
- **Type**: Integration
- **Covers**: `AC-harness-agnostic-installer-output`, `NFR-harness-agnostic-installer-reporting`
- **Preconditions**: Fresh temporary directory.
- **Steps**:
  1. Run `init.sh --harnesses claude,codex`.
  2. Capture stdout.
- **Expected Result**: Every line that announces materializing an agent-instructions file or a slash command names the harness in parentheses (e.g., `Created product/AGENTS.md (harness: codex)`). A reader can audit harness coverage by skimming the output.

### Pdeq Self-Host

#### Pdeq's own repo migrates cleanly `TC-harness-agnostic-self-host-migrate-clean`
- **Type**: Integration
- **Covers**: `AC-harness-agnostic-self-host-migrates`, `FR-migrations-self-migration` (cross-reference)
- **Preconditions**: A clone of the pdeq repository with `.pdeq/` pinned at the in-development 0.4.0 commit (the bootstrap chain).
- **Steps**:
  1. Run `/pdeq-migrate` against pdeq's own specs.
  2. Inspect `pdeq.json`'s `pdeqVersion`.
  3. Run the traceability audit.
- **Expected Result**: The migration completes cleanly. `pdeqVersion` advances to `0.4.0`. Traceability audit passes.

## Edge Cases & Error Scenarios

### Empty harness list

- **Trigger**: A consumer sets `harnesses: []` in `pdeq.json`.
- **Expected behavior**: The schema permits an empty array (no `minItems` constraint at v1). The installer materializes no agent files and no slash-command directories. The consumer's project is technically pdeq-managed for specs and migrations, but no harness can read the pdeq prose. The installer warns at the end of its run that the harness list is empty and pdeq prose is not discoverable to any agent. *(Not a hard failure — supporting this case lets a consumer temporarily disable harness materialization while debugging.)*
- **Test case**: deferred. Captured as an open question; not blocking v1.

### Pre-0.4.0 consumer with a pre-existing AGENTS.md at the root

- **Trigger**: A consumer has an `AGENTS.md` at their project root that they authored (unrelated to pdeq) before migrating to 0.4.0.
- **Expected behavior**: The migration's mechanical block follows the same regular-file-vs-symlink check used for the customized-command-file case: if `AGENTS.md` is a regular file, it is not touched and a one-line warning is printed naming the file. The consumer can either merge the content or rename their file out of the way.
- **Test case**: `TC-harness-agnostic-migrate-preexisting-agents-file` *(out of scope for v1 — consumers using `AGENTS.md` for unrelated purposes are rare; address only if it surfaces.)*

### Submodule pinned at a pdeq version below the recorded version

- **Trigger**: A consumer's recorded `pdeqVersion` is `0.4.0` but the `.pdeq/` submodule is somehow back at `0.3.5`.
- **Expected behavior**: Covered by the existing `FR-migrations-unknown-version` / `AC-migrations-lineage-refused` machinery. The migration refuses to run. No harness-agnostic-specific behavior; tested in `qa/cli/migrations.md`.
- **Test case**: covered upstream.

## Regression Considerations

- **`/pdeq-update` end-to-end**: the 0.3.x → 0.4.0 hop is the first migration that re-points command symlinks inside the submodule. `TC-migrations-update-happy` (in `qa/cli/migrations.md`) should be re-run against this transition specifically — symlink re-pointing was previously untested by the update flow.
- **`scripts/audit-traceability.sh`**: the audit's marker scan iterates over files in the submodule. After the layout rename, the scan must still find markers in their new locations (e.g., `pdeq-rules/commands/pdeq-bootstrap.md`). The audit's exclusion list does not need new entries — the new path is not gitignored — but a confirmation run on the freshly-restructured pdeq self-host is the simplest check.
- **Pre-commit hook**: `core.hooksPath` is set by `init.sh` Step 10 to `$PDEQ_PATH/hooks`. This path does not change in 0.4.0, so existing wiring continues to work without re-installation.
- **Skill loading in Claude Code**: `.claude/skills/pdeq/SKILL.md` is unmoved. Claude Code's skill discovery continues to find it.
