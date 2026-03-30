# PDEQ

A Claude Code AI agent framework for structured software development across four lanes: **P**roduct, **D**esign, **E**ngineering, **Q**A.

Specs drive code. Requirements are fully traceable from definition to test. Each functional area stays in its lane.

---

## Quick Install

```bash
# From your project root
git submodule add git@github.com:ldstreet/pdeq.git .pdeq
bash .pdeq/scripts/init.sh
```

Or, if you already have PDEQ cloned locally:

```bash
bash /path/to/pdeq/scripts/init.sh --pdeq-url /path/to/pdeq
```

Then open Claude Code and run `/kickoff` to start your first feature.

**Adding PDEQ to an existing codebase?** See [docs/bootstrap.md](docs/bootstrap.md) or run `/bootstrap` in Claude Code.

---

## How It Works

### Core Philosophy

**Markdown first, code second.** Spec files are the source of truth. Changes flow product → design → engineering → QA → code. Never the reverse.

**Lane discipline.** Product says *what*. Design says *how it looks*. Engineering says *how it's built*. QA says *how it's verified*. No area prescribes another's domain.

**Traceability.** Every requirement (`FR-`, `NFR-`, `AC-`) is tracked from product spec to test case via `index.md`. A pre-commit hook enforces this.

**Living specs.** Spec files represent current state. When a feature changes, update the existing file — don't create a new one.

### Folder Structure

```
your-project/
├── .pdeq/                  # PDEQ submodule (framework agent files)
├── product/                # Requirements, user stories, acceptance criteria
│   └── CLAUDE.md           # → @../.pdeq/product/CLAUDE.md
├── design/
│   └── <platform>/         # UI/UX specs, one subfolder per platform
├── engineering/
│   ├── <platform>/         # Architecture docs and technical specs
│   └── apps/<platform>/    # Source code
├── qa/
│   └── <platform>/         # Test plans and coverage matrices
├── .claude/commands/       # Slash commands (symlinked from .pdeq)
├── scripts/                # Audit and utility scripts (symlinked from .pdeq)
├── CLAUDE.md               # @.pdeq/CLAUDE.md + project-specific overrides
├── index.md                # Traceability index — slug → file map
├── glossary.md             # Shared vocabulary
└── decisions.md            # Architectural decision log
```

---

## Getting Started

### New project (greenfield)

```bash
cd your-project
git submodule add git@github.com:ldstreet/pdeq.git .pdeq
bash .pdeq/scripts/init.sh
```

`init.sh` creates the folder structure, wires up `@` imports in each `CLAUDE.md`, and symlinks the commands and scripts. It's idempotent — safe to run again if something was skipped.

### Existing project

```bash
cd your-project
git submodule add git@github.com:ldstreet/pdeq.git .pdeq
bash .pdeq/scripts/init.sh --code-root src --platforms web --interactive
```

Then run `/bootstrap` in Claude Code to analyze your existing code and generate draft specs. See [docs/bootstrap.md](docs/bootstrap.md) for the full walkthrough.

### Nested install (monorepo package or feature subfolder)

```bash
cd packages/my-service
bash /path/to/pdeq/scripts/init.sh \
  --pdeq-url git@github.com:ldstreet/pdeq.git \
  --nested ../.. \
  --label my-service \
  --code-root src \
  --platforms cli
```

This installs PDEQ into the current subfolder, points it at the real git root (`../..`), and generates `pdeq.json`. Scripts and `.claude/commands/` are symlinked from the git root so Claude Code can find them.

### Receiving updates

PDEQ is pinned per-project via the submodule commit. To opt into a newer version:

```bash
git submodule update --remote .pdeq
git add .pdeq && git commit -m "update pdeq framework"
```

---

## Slash Commands

Open Claude Code in your project and use:

| Command | What it does |
|---|---|
| `/kickoff [description]` | Full feature kickoff: triages scope → product spec → design spec → engineering spec + QA plan in parallel → traceability + consistency checks |
| `/bootstrap [--dry-run] [--feature name]` | Import an existing codebase: analyzes code → generates draft specs → updates index.md → prints review checklist |
| `/impact [slug or feature]` | Shows every artifact that would need to change if a requirement is modified |
| `/status` | Project dashboard: feature coverage across all four lanes, slug coverage, traceability gaps |

---

## The Slug System

All requirements and test cases use permanent slug-based IDs:

| Prefix | Used for | Example |
|---|---|---|
| `FR-` | Functional requirements | `FR-auth-email-login` |
| `NFR-` | Non-functional requirements | `NFR-auth-login-latency` |
| `AC-` | Acceptance criteria | `AC-auth-invalid-password` |
| `TC-` | Test cases | `TC-auth-login-happy` |

Format: `<PREFIX>-<feature>-<descriptive-slug>`

Slugs are **permanent** — never renamed or reused after creation. The `scripts/audit-traceability.sh` pre-commit hook enforces that every slug defined in `product/` appears in `index.md` and that every downstream reference resolves.

---

## Multi-Platform Support

Define your platforms in `CLAUDE.md`. Each platform gets its own subfolder in `design/`, `engineering/`, and `qa/`:

```
design/web/auth.md         # Web UI spec
design/mobile/auth.md      # Mobile UI spec
engineering/web/auth.md    # Web technical spec
qa/web/auth.md             # Web test plan
```

`product/` specs are platform-neutral — they describe *what* the feature does, not *how* it looks or is built. If a platform has unique product requirements, create a supplement at `product/<platform>/auth.md`.

---

## The Engineering-QA Loop

After engineering implements a feature:

1. QA executes test cases (automated + manual), updating the coverage matrix
2. QA reports failures: TC slug, observed behavior, expected behavior
3. Engineering investigates and fixes — updating specs first if behavior changed
4. QA re-verifies
5. Repeat until all tests pass
6. Design confirms implementation matches design spec; Product confirms all AC are met

---

## Configuration (pdeq.json)

For non-standard installs (nested, monorepo, separate code root), create `pdeq.json` at the PDEQ install root. `init.sh` generates this automatically when you pass flags.

| Field | Type | Default | Description |
|---|---|---|---|
| `specsRoot` | string | `"."` | Path from `pdeq.json` to the directory containing `product/`, `design/`, etc. |
| `codeRoot` | string | `"."` | Path to source code root (used by `/bootstrap`) |
| `platforms` | string[] | — | Platform IDs — subfolders in `design/`, `engineering/`, `qa/` |
| `pdeqDir` | string | `".pdeq"` | Path to the `.pdeq` submodule, relative to git root |
| `nested.repoRoot` | string | — | Path up to the actual git root |
| `nested.label` | string | — | Component name shown in agent context |

Full schema: [`pdeq.schema.json`](pdeq.schema.json)

---

## Scripts

| Script | What it does |
|---|---|
| `scripts/audit-traceability.sh` | Verifies every slug in `product/` is in `index.md`, every downstream reference resolves, and every path in `index.md` exists |
| `scripts/audit-lanes.sh` | Checks product specs for design/engineering bleed (pixel values, library names, etc.) |
| `scripts/merge-decisions.sh` | Merges `decisions-pending.md` into `decisions.md` at commit time |
| `scripts/init.sh` | Installs PDEQ into a project (submodule + `@` imports + symlinks + pdeq.json) |
| `scripts/bootstrap.sh` | Validates bootstrap preconditions and resolves paths before `/bootstrap` runs |
