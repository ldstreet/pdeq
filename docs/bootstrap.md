# Adding PDEQ to an Existing Project

This guide covers using PDEQ with a codebase that already exists — you have source code, and you want to add spec-driven development without restructuring anything.

---

## Install Scenarios

### Scenario A: Root install with code in a subdirectory

Your project looks like this:

```
my-project/
├── .git/
├── src/            ← your existing code
├── tests/
└── README.md
```

Install PDEQ at the root and point it at your `src/` directory:

```bash
cd my-project
git submodule add https://github.com/yourname/pdeq .pdeq
bash .pdeq/scripts/init.sh --code-root src --platforms web
```

This creates:
- `product/`, `design/`, `engineering/`, `qa/` at the root
- `pdeq.json` with `codeRoot` = `"src"` and `platforms` = `["web"]`
- `CLAUDE.md`, `index.md`, `glossary.md`, `decisions.md`
- Symlinked `scripts/` and `.claude/commands/`

### Scenario B: Nested install inside a feature subfolder

Your project looks like this:

```
my-project/
├── .git/
├── features/
│   └── auth/
│       ├── src/    ← code for this feature module
│       └── ...
└── ...
```

Install PDEQ inside the `auth` folder:

```bash
cd my-project/features/auth
bash /path/to/pdeq/scripts/init.sh \
  --pdeq-url https://github.com/yourname/pdeq \
  --nested ../..       \   # path up to my-project/ (the git root)
  --label auth         \   # human name for this component
  --code-root src      \   # where code lives relative to this folder
  --platforms ios
```

After init, the layout is:

```
my-project/
├── .git/
├── .pdeq/              ← submodule added at git root
├── .claude/commands/   ← symlinks at git root so Claude Code can find them
├── scripts/            ← symlinks at git root
└── features/
    └── auth/
        ├── src/
        ├── product/    ← specs are here
        ├── design/
        ├── engineering/
        ├── qa/
        ├── CLAUDE.md
        └── pdeq.json   ← { nested: { repoRoot: "../..", label: "auth" }, codeRoot: "src" }
```

### Scenario C: Monorepo package install

Your monorepo looks like this:

```
monorepo/
├── .git/
└── packages/
    └── api/
        ├── src/    ← the API service code
        └── ...
```

Install PDEQ at `packages/api/pdeq/`:

```bash
cd monorepo/packages/api
mkdir pdeq && cd pdeq
bash /path/to/pdeq/scripts/init.sh \
  --pdeq-url https://github.com/yourname/pdeq \
  --nested ../../..   \   # path up to monorepo/ (the git root)
  --label api-service \
  --code-root ../src  \
  --platforms cli
```

Result:

```
monorepo/
├── .git/
├── .pdeq/              ← submodule at git root
├── .claude/commands/   ← symlinks at git root
├── scripts/            ← symlinks at git root
└── packages/
    └── api/
        ├── src/
        └── pdeq/
            ├── product/
            ├── design/
            ├── engineering/
            ├── qa/
            ├── CLAUDE.md
            └── pdeq.json
```

---

## The Bootstrap Workflow

Once PDEQ is installed (any scenario above), run:

```
/bootstrap
```

in Claude Code. This runs a 6-step process:

### Step 1: Load config

Reads `pdeq.json` to determine `codeRoot`, `specsRoot`, and platforms. You'll see a confirmation:

```
Code root:   /my-project/src
Specs root:  /my-project
Platforms:   web
Dry run:     no
```

Confirm to proceed.

### Step 2: Analyze the codebase

The bootstrap-analyzer reads your code and produces `bootstrap-analysis.md`. It looks for:

- README files and inline documentation
- Test names (often map directly to acceptance criteria)
- Function signatures and docstrings
- `TODO`, `FIXME`, `NOTE`, `SPEC:` comments
- API contracts (OpenAPI, TypeScript interfaces, protobufs)
- Error messages and validation logic
- Config keys and feature flags

Each discovered requirement gets:
- A proposed slug (`FR-auth-email-login`)
- A confidence level (`high` / `medium` / `low`)
- A source citation (`src/auth/login.ts:42`)

### Step 3: Review and confirm

Claude shows you a summary of what was found — feature areas, requirement counts, gaps — and asks for confirmation before writing any files.

You can also run in dry-run mode to see the analysis without generating specs:

```
/bootstrap --dry-run
```

Or scope to a single feature if your codebase is large:

```
/bootstrap --feature auth
```

### Step 4: Generate draft specs

The bootstrap-generator creates product and engineering spec files:

- `product/auth.md` — functional requirements, NFRs, acceptance criteria
- `engineering/web/auth.md` — technical approach inferred from code
- Updates `index.md` with all generated slugs

**It never overwrites existing specs.** If you already have `product/auth.md`, the generator skips it and logs the skip in the summary.

All generated requirements are marked `<!-- bootstrap: review-needed -->` so you can audit them.

### Step 5: Audit

The bootstrap command runs `audit-traceability.sh` and `audit-lanes.sh` and reports any issues. Generated specs are explicitly draft, so failures are reported but don't block you.

### Step 6: Summary

You get a `bootstrap-summary.md` with:
- Files created
- All slugs generated
- Items requiring human review
- Gaps the analyzer couldn't document

---

## After Bootstrap

1. **Open each generated spec** and work through the `<!-- bootstrap: review-needed -->` markers.
   - If a requirement is correct: remove the marker.
   - If a requirement is wrong or incomplete: fix it before removing the marker.
   - If a requirement doesn't belong: delete it.

2. **Run audits** to verify everything is clean:
   ```bash
   ./scripts/audit-traceability.sh
   ./scripts/audit-lanes.sh
   ```

3. **Commit the generated specs** once you're satisfied they're ready to serve as the source of truth for ongoing development.

4. **Run `/kickoff`** for any feature you want to design and implement end-to-end using the full PDEQ workflow.

---

## pdeq.json Reference

| Field | Type | Default | Description |
|---|---|---|---|
| `specsRoot` | string | `"."` | Relative path from `pdeq.json` to the directory containing `product/`, `design/`, etc. |
| `codeRoot` | string | `"."` | Relative path to source code root (for `/bootstrap` analysis) |
| `platforms` | string[] | `[]` | List of platform IDs corresponding to subfolders in `design/`, `engineering/`, `qa/` |
| `pdeqDir` | string | `".pdeq"` | Path to the `.pdeq` submodule, relative to the git root |
| `nested.repoRoot` | string | — | Path from the `pdeq.json` location up to the actual git root |
| `nested.label` | string | — | Human-readable component name shown in agent context messages |

Full schema with validation: [`pdeq.schema.json`](../pdeq.schema.json)

---

## /bootstrap Command Reference

```
/bootstrap                    Fully interactive bootstrap
/bootstrap --dry-run          Analyze only, no files written
/bootstrap --feature <name>   Bootstrap a single feature area only
```

The command:
1. Reads `pdeq.json` for path configuration
2. Checks for an existing `bootstrap-analysis.md` and offers to reuse it
3. Spawns the bootstrap-analyzer against `codeRoot`
4. Presents a summary and asks for confirmation
5. Spawns the bootstrap-generator to write draft specs
6. Runs `audit-traceability.sh` and `audit-lanes.sh`
7. Prints `bootstrap-summary.md`

The command **never overwrites existing spec files**. It skips any file that already exists and logs the skip in the summary.
