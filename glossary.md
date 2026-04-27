# Glossary

This file defines shared vocabulary for the project. All agents must use consistent terminology. Before introducing a new domain concept or term, check here first. If the term is not present, add it so all agents use the same language.

**Format for entries:**

**Term** — definition

---

## Terms

**Bootstrap chain** — The arrangement by which the pdeq repository manages its own specs using a pinned previous-stable pdeq version rather than the in-development version. Lets pdeq evolve itself using its own tooling without chicken-and-egg risk.

**Breaking change** — A change to pdeq that requires consumer projects to run a migration to stay in conformance. Additive or internal-only changes are not breaking; changes to slug formats, required config keys, required file layouts, or other consumer-visible contracts are.

**Code Map** — The section in a platform-specific engineering spec that lists planned code locations for every requirement slug the spec covers. Captures implementation intent at planning time and is kept current as files move, split, or merge during implementation.

**Inline marker** — A short comment placed at the implementation site in code that cites one or more requirement slugs (e.g. `FR-auth-email-login`) the surrounding block realizes. The authoritative link between a requirement and its implementation; lives with the code rather than in a separate mapping file.

**In-session command availability** — The contract that any new or modified pdeq slash command shipped by a freshly-bumped pdeq version is invocable in the same coding-agent session that ran the upgrade, without requiring a session restart. Realized by the symlink sync step of `/pdeq-update` plus the harness's on-demand command-file lookup.

**Mechanical transform** — The deterministic portion of a migration. Applies the same rule to every applicable file without human judgment — for example, a rename, a move, or a rule-based rewrite. Runs before the semantic transform within a single migration.

**Migration** — A versioned, author-written transformation that brings a consumer project's specs and configuration into conformance with a newer pdeq version. One migration per pdeq version that introduces a breaking change.

**Orphan marker** — An inline marker that cites a slug not defined in any current product spec. Usually indicates either a typo in the marker or a requirement that was removed from the product spec without the code being updated. Orphan markers are rejected by the traceability audit.

**Semantic transform** — The optional judgment-based portion of a migration. A prompt block supplied with relevant file context, executed by an AI agent when per-item judgment is required and no deterministic rule can express the change. Runs after the mechanical transform within a single migration.

**Symlink sync** — The idempotent operation that reconciles a consumer project's `<git-root>/scripts/` and `<git-root>/.claude/commands/` symlinks against the current contents of the `.pdeq/` submodule: creating symlinks for newly-shipped files and (with `--prune`) removing dangling symlinks for files deleted upstream. Implemented in `scripts/sync-symlinks.sh` and called by both `init.sh` and `/pdeq-update`.

**Traceability audit** — The pre-commit pipeline (`scripts/audit-traceability.sh`) that validates the traceability index against product specs, downstream specs, and code. Reconciles slug definitions, Code Map planned paths, and inline markers; blocks commits on drift subject to the documented escape hatch.

**Pdeq command prefix** — The naming convention by which every pdeq-installed slash command begins with the `pdeq-` prefix (`/pdeq-kickoff`, `/pdeq-status`, `/pdeq-migrate`, etc.). Lets a consumer discover the full pdeq command surface by typing `/pdeq` in their slash-command palette and prevents collision with bare-verb commands a consumer's own project or other tooling may ship. See `product/cli-conventions.md` for the contract.

**Upgrade entrypoint** — The unified consumer-facing surface for getting on a newer pdeq version. Realized by the `/pdeq-update` slash command, which advances the pinned `.pdeq/` submodule reference, runs symlink sync, and chains into `/pdeq-migrate` so the recorded version catches up — all in one invocation. Distinct from `/pdeq-migrate`, which advances the recorded version against an already-bumped pin and serves as the recovery verb on partial-run failure.

