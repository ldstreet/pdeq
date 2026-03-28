# PDEQ

A Claude Code AI agent framework for structured software development across four lanes: **P**roduct, **D**esign, **E**ngineering, **Q**A.

PDEQ enforces a methodology where specs drive code, requirements are fully traceable from definition to test, and each functional area stays in its lane. It works for any software project and supports multi-platform products out of the box.

---

## Core Philosophy

**Markdown first, code second.** Spec files are the source of truth. Changes flow product → design → engineering → QA → code. Never the reverse.

**Lane discipline.** Product says *what*. Design says *how it looks*. Engineering says *how it's built*. QA says *how it's verified*. No area prescribes another's domain.

**Traceability.** Every requirement (`FR-`, `NFR-`, `AC-`) is tracked from product spec to test case via `index.md`. A pre-commit hook enforces this.

**Living specs.** Spec files represent current state. When a feature changes, update the existing file — don't create a new one.

---

## Folder Structure

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
│   ├── kickoff.md
│   ├── impact.md
│   └── status.md
├── scripts/                # Audit and utility scripts (symlinked from .pdeq)
├── CLAUDE.md               # @.pdeq/CLAUDE.md + project-specific overrides
├── index.md                # Traceability index — slug → file map
├── glossary.md             # Shared vocabulary
└── decisions.md            # Architectural decision log
```

---

## Getting Started

### New project (recommended)

```bash
cd your-project
git submodule add https://github.com/yourname/pdeq .pdeq
bash .pdeq/scripts/init.sh
```

`init.sh` creates the folder structure, wires up `@` imports in each `CLAUDE.md`, and symlinks the commands and scripts. It's idempotent — safe to run again if something was skipped.

### Manual install

Copy the CLAUDE.md files and `.claude/commands/` into your project and substitute `@../.pdeq/` paths with the actual content, or keep a local copy you update manually.

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

When porting an existing feature to a new platform, the product spec stays unchanged. Create new design, engineering, and QA specs in the new platform's subfolder.

---

## The Engineering-QA Loop

After engineering implements a feature:

1. QA executes test cases (automated + manual), updating the coverage matrix
2. QA reports failures: TC slug, observed behavior, expected behavior
3. Engineering investigates and fixes — updating specs first if behavior changed
4. QA re-verifies
5. Repeat until all tests pass
6. Design confirms implementation matches design spec; Product confirms all AC are met

All tests passing + QA sign-off + design sign-off + product sign-off = done.

---

## Scripts

| Script | What it does |
|---|---|
| `scripts/audit-traceability.sh` | Verifies every slug in `product/` is in `index.md`, every downstream reference resolves, and every path in `index.md` exists |
| `scripts/audit-lanes.sh` | Checks product specs for design/engineering bleed (pixel values, library names, etc.) |
| `scripts/merge-decisions.sh` | Merges `decisions-pending.md` into `decisions.md` at commit time |
| `scripts/init.sh` | Installs PDEQ into a project (submodule + `@` imports + symlinks) |
