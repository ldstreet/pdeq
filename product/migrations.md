# Migrations

## Overview

Pdeq evolves over time. Some of those changes are additive and harmless — adding a new folder or a new optional field. Others are breaking: a slug format changes, a config key is renamed, a required file moves. Without an explicit mechanism, consumer projects silently drift out of conformance with their pinned pdeq version whenever they bump the submodule.

The migrations feature gives pdeq a first-class upgrade contract. Each pdeq release that introduces a breaking change ships a matching migration — a versioned, author-written transformation that brings a consumer's specs and config into conformance with the new version. Consumers track which pdeq version their project currently conforms to, bump the submodule when they are ready, and explicitly run a migration command to apply pending changes. Pdeq dogfoods this mechanism on its own specs via a bootstrap chain, so the framework can be used to manage itself.

## User Stories

- As a **consumer-project maintainer**, I want to safely upgrade my pinned pdeq version so that bumping the submodule doesn't silently break my tooling or leave my specs in a half-conformant state.
- As a **consumer-project maintainer**, I want to preview what a migration will change before it runs so that I can review the diff before committing.
- As a **consumer-project maintainer**, I want a single command that bumps pdeq and applies any pending migrations in one flow so that I don't have to remember separate steps, restart my session to pick up new tooling, or know about internal commands like the migration runner by name.
- As a **pdeq maintainer**, I want to author explicit migrations for breaking changes so that consumers have a deterministic upgrade path rather than relying on diff-guessing.
- As a **pdeq maintainer**, I want the repo itself to block breaking-version commits that lack migrations so that no breaking change can ship without an upgrade path.
- As a **pdeq maintainer**, I want pdeq's own specs to be managed by the previous pdeq version so that the framework proves it can manage itself.

## Requirements

### Version Tracking

Consumer projects record which pdeq version their specs and config currently conform to. This is the anchor the migration system reads to determine what work is pending.

- **Recorded pdeq version** `FR-migrations-version-field`: A consumer project records its currently-conformant pdeq version in the project config. This value is a semver string drawn from the same pdeq release lineage the project is pinned to.
- **Version visible to tooling** `FR-migrations-version-readable`: Any pdeq command that behaves differently by version can read the recorded pdeq version without additional user input.
- **Absent version treated as pre-migrations** `FR-migrations-absent-version`: A project with no recorded pdeq version is treated as predating the migrations feature, and the migration command reports this clearly before taking action.

### Authoring Migrations

Migrations are written by pdeq maintainers, one per pdeq version that introduces a breaking change. They are not auto-generated from diffs.

- **One migration per breaking version** `FR-migrations-one-per-version`: Each pdeq version that introduces a breaking change has exactly one associated migration. Non-breaking versions have no migration.
- **Deterministic ordering** `FR-migrations-ordered`: Migrations have a well-defined total order tied to the pdeq release lineage, so the migration runner can apply them in sequence without ambiguity.
- **Mechanical transform block** `FR-migrations-mechanical-block`: Every migration may include a mechanical transform — a deterministic step that applies the same change to every applicable file without human judgment (for example, renaming, moving, or rewriting by rule).
- **Semantic transform block** `FR-migrations-semantic-block`: Every migration may optionally include a semantic transform — a block that supplies file context and instructions to an AI agent, used when per-item judgment is required and a deterministic rule cannot express the change.
- **Mechanical before semantic** `FR-migrations-order-within`: Within a single migration, the mechanical transform is applied before the semantic transform so that deterministic work is never overwritten by judgment-based work.
- **Author-written only** `FR-migrations-author-written`: The migration system does not attempt to derive migrations from diffs between pdeq versions. Migrations are authored explicitly.

### Running Migrations

The consumer explicitly invokes the migration command after bumping the pdeq submodule. The command is the only supported way to advance a project's recorded pdeq version.

- **Explicit invocation** `FR-migrations-explicit-run`: The migration process runs only when the consumer explicitly invokes it. Bumping the submodule, cloning the repo, or running unrelated pdeq commands never triggers a migration automatically.
- **Pending detection** `FR-migrations-pending-detection`: The migration command compares the recorded pdeq version to the pdeq version currently pinned in the submodule and identifies which migrations, if any, are pending.
- **Ordered application** `FR-migrations-ordered-application`: When multiple migrations are pending, they are applied in version order, oldest first, with no gaps skipped.
- **Version bump on success** `FR-migrations-version-bump`: After all pending migrations apply successfully, the consumer's recorded pdeq version is updated to match the pinned submodule version.
- **Non-breaking version advance** `FR-migrations-nonbreaking-advance`: When the pinned version advances past the recorded version across one or more non-breaking releases (no matching migration files exist in the pending window), the migration command advances the recorded version directly to match the pinned version without running any migration, in a single clean operation.
- **No-op when current** `FR-migrations-noop-when-current`: Running the migration command on a project whose recorded version already matches the pinned version makes no changes to any file.
- **Dry-run preview** `FR-migrations-dry-run`: The migration command supports a dry-run mode that reports the set of pending migrations and what each would change, without modifying any file.
- **Idempotency** `FR-migrations-idempotent`: Applying a migration to content that has already been migrated produces no change. Re-running the migration command after a successful run is a safe no-op.
- **Scoped writes** `FR-migrations-scoped-writes`: A migration modifies only files inside the consumer's specs root and the project config file, unless the migration explicitly declares a broader scope up front.

### Upgrade Entrypoint

Bumping pdeq and migrating are two halves of the same user-facing action. Consumers should be able to upgrade their project without learning multiple commands, juggling submodule mechanics, or restarting their tooling session to see the new pdeq version's commands. This group covers the unified upgrade flow that wraps the underlying submodule bump and migration run.

- **Unified update command** `FR-migrations-update-command`: Pdeq exposes a single, discoverable command that consumers run to upgrade their pinned pdeq version. The command's name should be obvious to a maintainer who knows pdeq exists but does not know its internals.
- **Update bumps the pinned version** `FR-migrations-update-bumps-pin`: The update command advances the consumer's pinned pdeq reference to the latest pdeq version available on the consumer's tracked release lineage, without requiring the consumer to invoke the underlying version-control mechanism directly.
- **Update chains into migration** `FR-migrations-update-chains`: After successfully bumping the pinned version, the update command applies any migrations made pending by the bump, or offers to do so, in the same invocation. The consumer never has to know the migration command exists as a separate step.
- **In-session command availability** `FR-migrations-update-in-session`: After the update command finishes, any new or changed pdeq commands shipped by the new version are usable in the same session that ran the update. The consumer is not required to restart their tooling session to invoke them.
- **No-op when already current** `FR-migrations-update-noop`: Running the update command when the pinned pdeq reference is already at the latest available version on the tracked lineage makes no version-control changes and runs no migration. The command reports that the project is already up to date.
- **Recoverable failure during bump** `FR-migrations-update-bump-failure`: If advancing the pinned pdeq reference fails (for example, due to a network or version-control error), the project is left in a state the consumer can inspect, fix, and re-run from. The recorded pdeq version is not advanced and no migration is applied. The failure is reported with enough detail for the consumer to act.
- **Dry-run preview of update** `FR-migrations-update-dry-run`: The update command supports a dry-run mode that reports what version the pin would advance to and which migrations would then become pending, without modifying the pinned reference, the recorded version, or any file.

### Enforcement

Pdeq's own repository enforces that breaking versions ship with migrations. This is a safeguard on the pdeq side, not the consumer side.

- **Breaking-change gate** `FR-migrations-breaking-gate`: Within the pdeq repo, a commit that bumps the pdeq version as a breaking change and modifies framework files cannot land unless a matching migration file is present in the same commit.
- **No false positives on additive changes** `FR-migrations-no-false-positive`: The enforcement gate does not block commits that are documentation-only, non-framework, or non-breaking. Consumers should be able to land fixes and doc updates without authoring a migration.
- **Version lineage integrity** `FR-migrations-lineage-integrity`: The migration system rejects operation against pdeq versions that do not come from the consumer's pinned release lineage, so forks with independent version histories do not silently apply each other's migrations.

### Dogfood / Bootstrap

Pdeq manages its own specs using a previous stable pdeq version, proving the framework can evolve itself safely.

- **Self-hosted framework** `FR-migrations-bootstrap-chain`: The pdeq repo's own specs are managed by a pinned previous-stable pdeq version, not by the in-development version.
- **Self-migration on release** `FR-migrations-self-migration`: When pdeq ships a new version, the pdeq maintainers use the same migration command, against the same migration file, to bring pdeq's own specs into conformance with the new version before the release is tagged.

### Error Handling

Migrations can fail. When they do, the project is left in a state the consumer can recover from without losing work.

- **Atomic version bump** `FR-migrations-atomic-bump`: If any pending migration fails, the recorded pdeq version is not advanced past the last fully-applied migration.
- **Failure reporting** `FR-migrations-failure-report`: A failed migration reports which migration failed, at what step, and what the consumer needs to do to recover.
- **Recoverable partial state** `FR-migrations-recoverable-partial`: On failure, the project is left either rolled back to its pre-migration state or in a state the consumer can inspect, fix, and re-run from. Silent partial application without reporting is not acceptable.
- **Unknown version handling** `FR-migrations-unknown-version`: If the recorded pdeq version is newer than the pinned submodule version, or belongs to an unknown lineage, the migration command refuses to run and reports the mismatch.
- **Missing migration for breaking pinned version** `FR-migrations-missing-file-refused`: When the pinned version lineage declares a version within the pending window as breaking but no migration file for that version is present, the migration command refuses to run and reports the missing file with the exact path expected. The runner never silently skips a pending breaking version.

### Non-Functional Requirements

- **Idempotency guarantee** `NFR-migrations-idempotency`: Every migration is idempotent by construction. Re-running any migration against already-migrated content must not corrupt the content or advance the version further than intended.
- **Deterministic ordering** `NFR-migrations-determinism`: The order in which migrations apply is fully determined by pdeq release lineage. Two consumers upgrading from the same version to the same version apply the same migrations in the same order.
- **Scope minimalism** `NFR-migrations-scope-minimalism`: The migration command touches the smallest possible set of files required to bring the project into conformance. It does not reformat, reorder, or rewrite files that the migration does not explicitly target.
- **Enforcement precision** `NFR-migrations-enforcement-precision`: The pdeq repo's breaking-change enforcement must not block routine non-breaking commits. Its false-positive rate on docs-only and bugfix-only commits must be zero.

## Acceptance Criteria

These cover the behavior QA will test directly. They are the testable observable outcomes of the requirements above.

- [ ] **No-op at latest** `AC-migrations-noop-when-current`: Running the migration command on a project whose recorded pdeq version equals the pinned submodule version makes no file changes and reports that no migrations are pending.
- [ ] **Ordered application** `AC-migrations-ordered-apply`: Running the migration command on a project two or more versions behind applies every pending migration in version order and advances the recorded version to match the pinned version.
- [ ] **No version bump on failure** `AC-migrations-no-bump-on-failure`: When a pending migration fails, the recorded pdeq version is not advanced past the last fully-applied migration, and the failure is reported to the user.
- [ ] **Dry-run preview accuracy** `AC-migrations-dry-run-accurate`: Dry-run mode reports the exact set of migrations that a real run would apply, and leaves the working tree unchanged.
- [ ] **Breaking commit blocked without migration** `AC-migrations-gate-blocks`: In the pdeq repo, an attempt to commit a breaking pdeq-version bump together with framework changes but without a matching migration file is rejected by the enforcement gate.
- [ ] **Non-breaking commit not blocked** `AC-migrations-gate-allows-nonbreaking`: In the pdeq repo, commits that are docs-only, non-framework, or non-breaking are not blocked by the enforcement gate and require no migration file.
- [ ] **Semantic block receives file context** `AC-migrations-semantic-context`: A semantic transform block receives the relevant files as context to the executing agent, so its prompt can act on actual project content rather than placeholders.
- [ ] **Idempotent re-run** `AC-migrations-idempotent-rerun`: Running the migration command twice in a row on the same project produces no additional file changes on the second run.
- [ ] **Absent version reported** `AC-migrations-absent-reported`: Running the migration command on a project without a recorded pdeq version reports this state explicitly before taking any action.
- [ ] **Lineage mismatch refused** `AC-migrations-lineage-refused`: Running the migration command when the recorded version is newer than the pinned version, or belongs to a foreign lineage, refuses to run and reports the mismatch.
- [ ] **Scope respected** `AC-migrations-scope-respected`: A migration that does not declare broader scope does not modify files outside the consumer's specs root or project config.
- [ ] **Self-migration on release** `AC-migrations-self-migration-runs`: When pdeq releases a new version, applying its own migration against pdeq's own specs completes cleanly and advances the pdeq repo's recorded version.
- [ ] **Non-breaking advance applied** `AC-migrations-nonbreaking-advance`: When the pinned version is newer than the recorded version and no migration files exist in the pending window, running the migration command advances the recorded version to match the pinned version and reports that no migrations ran.
- [ ] **Missing breaking-version file refused** `AC-migrations-missing-file-refused`: When the pinned version lineage declares a version in the pending window as breaking but its migration file is missing, the migration command exits non-zero, names the missing file path, and leaves the recorded version unchanged.
- [ ] **Update bumps and migrates in one flow** `AC-migrations-update-end-to-end`: Running the update command on a project whose pinned pdeq version is behind the latest available on its lineage advances the pin and applies (or offers to apply) the resulting pending migrations in the same invocation, without the consumer running any other command.
- [ ] **Update no-op at latest** `AC-migrations-update-noop`: Running the update command when the pinned pdeq reference is already at the latest available version on the tracked lineage makes no changes and reports that the project is already up to date.
- [ ] **New commands usable without session restart** `AC-migrations-update-in-session`: After the update command finishes, a slash command introduced or modified by the newly-pinned pdeq version can be invoked successfully in the same session that ran the update.
- [ ] **Bump failure is recoverable and reported** `AC-migrations-update-bump-failure`: When advancing the pinned pdeq reference fails, the update command reports the failure with actionable detail, leaves the recorded pdeq version unchanged, runs no migration, and a subsequent re-run after the underlying issue is resolved completes successfully.
- [ ] **Update dry-run accuracy** `AC-migrations-update-dry-run`: Update dry-run reports the target pinned version and the set of migrations that a real run would make pending, and leaves the pinned reference, the recorded version, and the working tree unchanged.

## Open Questions

- **Version pre-feature baseline:** What version string should represent "predates migrations" when a legacy project first adopts the feature? Design/engineering need to pick a convention (for example, a sentinel like `0.0.0` versus absent-field handling).
- **Partial-failure recovery policy:** When a migration fails mid-run, should the default behavior be automatic rollback to the last clean state, or leave the filesystem as-is and require manual intervention? Either is acceptable from a product standpoint; engineering should pick one and document it.
- **Scope override mechanism:** The spec requires that a migration may declare broader scope than specs-plus-config. How that broader scope is declared (and reviewed) is deferred to engineering.
- **Multiple pdeq installs per repo:** For repos with more than one pdeq install (e.g., nested), does the migration command operate on one install at a time or attempt to coordinate across installs? Out of scope for v1 unless a user need appears.
- **Update command name:** What is the user-facing name of the unified upgrade entrypoint? Candidates discussed include extending the existing `pdeq` flow, a dedicated `/update` (or `/pdeq-update`), or another obvious form. Design picks the exact name. *Resolved by design (`design/cli/migrations.md` → "Upgrade Entrypoint UX → Command name decision"): the command is `/pdeq-update`. Rationale: the `pdeq-` prefix namespaces pdeq commands for discoverability and clarity in projects that have many slash commands, anticipating a future convention where all pdeq slash commands carry the `pdeq-` prefix. Burying the bump under a `/pdeq-migrate --bump` flag would violate `FR-migrations-update-command`.*
- **Auto-run vs. prompt for chained migration:** When the update command finishes the version bump and detects pending migrations, should it apply them automatically, prompt the consumer to confirm, or make this configurable? Either is acceptable from a product standpoint; design/engineering should pick a default and document it. *Resolved by design (`design/cli/migrations.md` → Surface 12): auto-run. Once the consumer has typed `/pdeq-update`, they have already opted in to the upgrade; a confirmation prompt would split one decision into two. Recovery on mid-migration failure goes through the existing `/pdeq-migrate` failure surface.*
- **Update failure-handling parity with migration:** Should the update command's failure-recovery behavior (rollback vs. leave-as-is on bump failure) be aligned with the migration command's partial-failure recovery policy, or chosen independently? Resolve alongside the partial-failure recovery question above.

## Dependencies

- **Config schema (`pdeq.schema.json`):** must grow a `pdeqVersion` field to carry the recorded version.
- **Submodule mechanism:** relies on the existing pdeq submodule symlinks for access to migration files and scripts.
- **Glossary:** introduces the terms *Migration*, *Mechanical transform*, *Semantic transform*, *Breaking change*, and *Bootstrap chain* — see `../glossary.md`.
