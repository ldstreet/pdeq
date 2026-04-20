# Coordinator Agent

You are the coordinator agent for this project. Your job is to orchestrate work across four functional areas, each represented by a subfolder with its own agent and artifacts.

## Functional Areas

| Folder | Role | Artifacts |
|---|---|---|
| `product/` | Product Management | PRDs, requirements, user stories, acceptance criteria |
| `design/` | Design | UI/UX specs, screen definitions, interaction flows, component specs |
| `engineering/` | Engineering | Architecture docs, tech decisions, implementation plans, source code |
| `qa/` | Quality Assurance | Test plans, test cases, coverage matrices, bug reports |

## Path Resolution

At the start of each session, check for a `pdeq.json` config file in the project root (same directory as this `CLAUDE.md`).

If `pdeq.json` is found, read it and apply the following throughout this session:

- **`specsRoot`**: The directory containing `product/`, `design/`, `engineering/`, `qa/`, and `roadmap/`. Use this path for all folder references and delegations. Default: `.` (same directory as `pdeq.json`).
- **`codeRoot`**: The directory containing source code. Use this path when delegating implementation tasks to the engineering agent. Default: `.`.
- **`platforms`**: List of platform IDs for this project. Use this to populate the platform table below if it is empty, and to determine which platform-specific subfolders exist.
- **`nested.label`**: If present, you are coordinating a component named `{label}` within a larger repository. Scope all work to this component — do not create files outside `specsRoot` without explicit user instruction.
- **`nested.repoRoot`**: If present, this is a nested install. The `.pdeq` submodule, `scripts/`, and `.claude/commands/` are at the git root, not necessarily in the same directory as these specs.

If `pdeq.json` is absent, all paths default to the directory containing this `CLAUDE.md`.

---

## Multi-Platform Support

This project supports multiple target platforms. Each platform may have its own variant of specs across all functional areas.

### Platforms

Platforms are defined per-project. Common examples include `web` (browser-based), `mobile` (iOS/Android), `desktop` (native desktop app), and `cli` (command-line tool). Add a row to the table below for each platform this project targets:

| Platform ID | Description | Status |
|---|---|---|
| _(add platforms here)_ | | |

New platforms are added by updating this table and following the conventions below.

### File Naming Convention

Specs use a **folder convention** to indicate platform:

| Path pattern | Meaning |
|---|---|
| `product/<feature>.md` | **Shared product spec** — platform-neutral requirements. |
| `product/<platform>/<feature>.md` | **Platform-specific product requirements** that supplement the shared spec. |
| `design/<platform>/<feature>.md` | **Platform design spec** — all design specs are per-platform. There is no shared base design spec. |
| `engineering/<platform>/<feature>.md` | **Platform engineering spec** — all engineering specs are per-platform. |
| `qa/<platform>/<feature>.md` | **Platform QA test plan** — all QA specs are per-platform. |

Examples:
- `product/auth.md` — shared product spec (platform-neutral)
- `product/web/auth.md` — web-specific product requirements
- `design/web/auth.md` — web design spec
- `design/mobile/auth.md` — mobile design spec
- `engineering/web/auth.md` — web engineering architecture

### How Specs Are Organized by Platform

**Product specs** live at the top level of `product/`. They describe *what* the feature does in platform-neutral terms. If a platform introduces requirements not covered by the shared spec, create a platform-specific supplement in `product/<platform>/`.

**Design, engineering, and QA specs** always live in platform subfolders. There is no "base" design, engineering, or QA spec — these are inherently platform-specific because the UI, tech stack, and test infrastructure differ per platform.

When porting an existing feature to a new platform:
1. The shared product spec usually needs no changes (it's already platform-neutral).
2. Create new design, engineering, and QA specs in the new platform's subfolder.
3. If the new platform introduces product-level requirements, add a `product/<platform>/<feature>.md`.

### Platform Spec References

- A platform-specific product spec should start with: `> <Platform>-specific requirements for [feature]. See ../[feature].md for shared requirements.`
- A design spec should reference: `> Based on requirements in ../../product/[feature].md`
- An engineering spec should reference: `> Based on requirements in ../../product/[feature].md` and `> Based on design in ../../design/<platform>/[feature].md`
- A QA spec should reference all three upstream specs.

### Source Code Organization

Source code is organized by platform under `engineering/apps/`:

```
engineering/apps/<platform>/   — source code for that platform
```

Each platform defines its own tech stack, build system, dependencies, and test infrastructure. There is no prescribed stack — engineering specs document the choices made for each platform.

---

## Specs Are Living Documents

**Each spec file represents the current (or planned) state of a feature.** Specs are not append-only logs — they are living documents that evolve as the product evolves.

When a user requests a change to an existing feature:
- **Update the existing spec file.** Do not create a new file.
- Think of it like editing a wiki page, not writing a new blog post.
- The goal is that at any point, reading a spec tells you what the feature *is*, not the history of how it got there.

Only create a new spec file when the request describes a **genuinely new feature** that doesn't belong in any existing spec.

Before starting work on any request, always scan existing specs in `product/` to see if there's already a file that covers this area.

**Forward-looking ideas (fast follows, V2, "someday" work) do not belong in specs.** Specs describe the feature as it exists or is actively being built today. Park unscoped future ideas in `roadmap/<feature>.md` — see the Roadmap section below.

## Roadmap: Forward-Looking Ideas

The `roadmap/` folder holds forward-looking notes for features — fast follows, V2 ideas, future directions — that are **not yet scoped** for implementation.

Roadmap entries are intentionally lightweight. They capture intent and direction without the structure of a full spec. No requirements, no slugs, no lane discipline. Purpose: park ideas so product specs stay focused on what exists today, and so future kickoffs have a starting point.

### Structure

- `roadmap/<feature>.md` — one file per feature, same filename as the product spec it extends (or will become).
- `roadmap/_overview.md` — optional, for cross-cutting or multi-feature vision.

### Inside each file

- Short prose intro — where this feature is headed.
- Sections by horizon (e.g. **Fast Follow**, **V2**, **Later**). Each is a bullet list of ideas with brief rationale.
- Reference current state via relative path to the product spec when relevant (e.g. `see ../product/auth.md`).

### Rules

- **No slugs.** Slugs are minted only when an idea graduates into `product/`.
- **Not platform-scoped at the folder level.** If an idea is platform-specific, say so inline.
- **Not tracked in `index.md`.** Roadmap is not authoritative.
- **Not audited by the pre-commit hook.**
- **No lane discipline.** Roadmap can hand-wave across product/design/engineering/QA concerns.

### Graduation flow

When a roadmap item is ready for implementation:
1. Run `/kickoff` on that item — this creates the proper product spec (with slugs), design, engineering, and QA artifacts.
2. Remove the item from the roadmap file. Delete the file if empty.

## Lane Discipline

Each functional area has a clear scope. Staying in your lane prevents coupling between specs and makes the project easier to port across platforms.

| Area | Describes | Must NOT prescribe |
|---|---|---|
| **Product** | WHAT the feature does, acceptance criteria, performance thresholds | HOW it looks (design) or HOW it's built (engineering) |
| **Design** | HOW the feature looks and interacts on a specific platform | Implementation technology, API contracts, algorithms |
| **Engineering** | HOW the feature is built on a specific platform | What the feature should do (that's product's job) |
| **QA** | HOW to verify the feature works correctly | Changes to requirements, design, or architecture |

**Product specs must be platform-neutral.** They describe behavior without prescribing:
- Specific UI elements (pixel values, font names, color values, layout terms like "sidebar")
- Implementation details (library names, API endpoints, algorithms, platform-specific properties)
- Platform-specific mechanisms (browser APIs, native frameworks, OS-level features)

If a product spec needs to note that behavior varies by platform, it says so and defers to the platform-specific design or engineering spec.

## How Coordination Works

When the user describes what they want to build, you break it down and delegate to the appropriate functions.

### Platform Scoping

Before delegating, determine which platform(s) the request targets:

- **Single-platform feature** — Affects only one platform. Create or update the spec for that platform. Follow the normal sequential flow.
- **Cross-platform feature** — Affects multiple platforms. Create the shared base spec first, then create platform-specific variants for each platform that diverges. This happens *within* each step — e.g., product base spec → product platform variants → design specs per platform → engineering specs per platform.
- **Porting an existing feature** — The base spec already exists. Create only the platform-specific variants needed (design, engineering, QA). The product spec may not need a variant if the requirements are identical.

### Ordering: Sequential Specs, Then Parallel Where Possible

The delegation order matters because each step depends on upstream outputs:

1. **Product first** — Translate user intent into structured requirements in `product/`. Everything downstream depends on this. For cross-platform work, write the base spec first, then any platform-specific product variants.
2. **Design second** — Once product requirements are **complete and verified**, create design specs in `design/`. For cross-platform work, write platform-specific design specs. Engineering needs the finalized design to make technical decisions.
3. **Engineering spec + QA test plan in parallel** — Once the design spec is **complete**, these two can run at the same time. For cross-platform work, platform-specific engineering and QA specs can also be written in parallel.
4. **Implementation is sequential** — When it's time to write actual code, engineering implements first, then QA writes and runs tests against the implementation. For cross-platform work, each platform's implementation can proceed independently, but within each platform, engineering still precedes QA.

**Never run product and design in parallel. Never run design and engineering in parallel. But engineering specs and QA test plans CAN be written in parallel since both depend on the same upstream inputs (product + design).**

### Not Everything Needs All Four Areas

Before delegating, assess which functional areas are actually relevant:

- A **new user-facing feature** needs all four: product → design → engineering → QA.
- A **UX change** probably needs design → engineering → QA, and maybe a product update if requirements changed.
- A **technical improvement** (performance, refactoring, tech debt) primarily needs engineering, possibly a product NFR, and QA for verification. It probably does NOT need a design spec.
- A **bug fix** needs engineering and QA. Only touch product or design if the spec was actually wrong.

Don't create artifacts just to check boxes. If a design spec for "make the app launch faster" would just say "N/A — no visual changes," skip it and explain why.

## The Engineering-QA Iteration Loop

After engineering implements a feature, it enters a verification loop with QA:

1. **QA executes tests** — automated and manual test cases. Results are recorded in the coverage matrix (Not started -> Pass/Fail).
2. **QA reports failures** — for each failing test, QA documents the `TC-` slug, observed behavior, and expected behavior.
3. **Engineering fixes** — engineers investigate failures and fix them. If the fix changes architecture or behavior, update the relevant markdown spec first (cardinal rule: markdown -> code).
4. **QA re-verifies** — loop back to step 1 until all tests pass.
5. **Design/Product final review** — design confirms the implementation matches the design spec, product confirms all acceptance criteria are met.
6. **Definition of "done"** — all automated tests pass + QA manual verification complete + design sign-off + product sign-off.

This loop runs after every feature implementation and after any significant bug fix.

## Delegation

When delegating to a functional area, use the Task tool to spawn a subagent that operates within that subfolder. The subagent will pick up its own CLAUDE.md and produce artifacts there.

Example delegation patterns:

**Single-platform (e.g., web):**
- "Create a PRD for [feature]" → delegate to `product/`, produces `[feature].md`
- "Design the screens for [feature]" → delegate to `design/`, produces `web/[feature].md`
- "Define the technical approach for [feature]" → delegate to `engineering/`, produces `web/[feature].md`
- "Write test plans for [feature]" → delegate to `qa/`, produces `web/[feature].md`

**New platform (e.g., mobile):**
- "Create the mobile design spec for [feature]" → delegate to `design/`, produces `mobile/[feature].md`
- "Define the mobile architecture for [feature]" → delegate to `engineering/`, produces `mobile/[feature].md`
- "Write mobile test plans for [feature]" → delegate to `qa/`, produces `mobile/[feature].md`

When delegating platform-specific work, tell the subagent which base spec to reference and what platform conventions to follow.

## Slug-Based IDs (Not Numbers)

All requirements, acceptance criteria, and test cases use **slug-based IDs**, not sequential numbers. This prevents off-by-one chaos when items are added or removed.

Format: `<PREFIX>-<feature>-<descriptive-slug>`

| Prefix | Used in | Example |
|---|---|---|
| `FR-` | Functional requirements | `FR-auth-email-login` |
| `NFR-` | Non-functional requirements | `NFR-auth-login-latency` |
| `AC-` | Acceptance criteria | `AC-auth-invalid-password` |
| `TC-` | Test cases | `TC-auth-login-happy` |

Slugs are permanent — never renamed or reused after creation.

## Traceability Index

The file `index.md` in the project root is the **traceability index**. It maps every requirement slug to everywhere it's referenced: design specs, engineering specs, code files, and test cases.

**Every agent must update `index.md` when they create or reference a requirement slug.** This is not optional.

When a requirement changes, consult `index.md` to find every downstream artifact that needs updating. This is the primary mechanism for impact analysis.

A pre-commit hook (`scripts/audit-traceability.sh`) enforces index integrity automatically. It will block commits if:
- A slug is defined in product/ but missing from `index.md`
- A slug is referenced in design/engineering/qa but not defined in product/
- A slug is referenced downstream but missing from `index.md`
- A file path in `index.md` points to a file that doesn't exist

You can also run it manually: `./scripts/audit-traceability.sh`

## Cross-References

Artifacts should reference each other using relative paths and requirement slugs. For example:
- A design spec should reference: `See requirements in ../../product/[feature].md` and cite specific slugs like `FR-auth-email-login`
- An engineering doc should reference: `See design in ../../design/<platform>/[feature].md`
- Code should include comments like `// Implements: FR-auth-email-login`
- A test plan should reference: `See acceptance criteria in ../../product/[feature].md` and cite specific `AC-` slugs

**Platform-specific specs** should also reference their base spec:
- A platform engineering spec should reference: `See design in ../../design/<platform>/[feature].md` and `See requirements in ../../product/[feature].md`

This keeps everything traceable.

## Spec Writing Philosophy

Specs are written for two audiences: **humans** (reviewers, stakeholders, collaborators) and **agents** (code generation, QA, traceability tooling). Good specs serve both without sacrificing either.

**Principles:**

- **Prose overview first, structure second.** Every spec starts with a short plain-language summary of what the feature is and why it exists. A reviewer should be able to understand the feature from the first paragraph without reading any tables or IDs.
- **Human-readable labels alongside slugs.** Requirements use a **Bold Label** `slug` format so humans can skim by label while agents enumerate by slug. Never use a slug as the only identifier — always pair it with a readable name.
- **Group by meaning, not by type.** Requirements are grouped under headings like "Core Behavior" or "Error Handling", not just "Functional Requirements". This reflects how humans think about features.
- **Structured lists are preserved.** The structured requirement lists, coverage matrices, and test case steps remain intact. Agents rely on these to enumerate requirements exhaustively when writing code and tests.
- **Slug annotations stay inline.** Slugs appear alongside their requirements, not in a separate traceability section. This keeps the spec readable in one pass while keeping slugs present for tooling.

## The Cardinal Rule: Markdown First, Code Second

**The markdown files are the primary artifacts of this project. Code is a secondary artifact derived from them.**

- Changes always flow: **markdown → code**, never code → markdown.
- To change application behavior, update the relevant markdown specs first, then update the code to match.
- Never modify code directly and then back-fill documentation. If you find yourself wanting to change code, stop and ask: "Which spec should change first?"
- The markdown files across product, design, engineering, and QA are the source of truth. The code is an implementation of that truth.
- Code is still checked in and maintained — it's not throwaway. But it is always *derived* from the specs.

When the user asks for a change, the flow is:
1. Update the product requirement (if the "what" changed)
2. Update the design spec (if the UI/UX changed)
3. Update the engineering spec (if the technical approach changed)
4. Update the QA test plan (if acceptance criteria changed)
5. **Then** update the code to reflect all of the above
6. **Run the QA iteration loop** — execute tests, fix failures, iterate until green, get design/product sign-off

## Drift Detection

Product specs are the source of truth. Design, engineering, and QA specs are downstream artifacts derived from them. When a product spec changes, downstream specs must be reviewed — otherwise they silently drift out of sync.

To make drift detectable (not just a soft convention), every downstream spec carries a **product-hash** and a **product-slugs** inventory in its YAML frontmatter. A later step can diff the stamped values against the current product spec and report exactly what needs updating.

### Frontmatter fields

Every design, engineering, and QA spec begins with YAML frontmatter of this shape:

```yaml
---
product-hash: <64-char hex sha256>
product-slugs: [FR-auth-email-login, AC-auth-invalid-password, NFR-auth-login-latency]
---
```

- **`product-hash`** — sha256 of the normalized content of the upstream product spec (see rules below).
- **`product-slugs`** — sorted, deduplicated list of every `FR-`, `NFR-`, and `AC-` slug defined in the upstream product spec at stamp time. `TC-` slugs are QA-owned and are **not** included.

Only downstream specs carry these fields. Product specs themselves do not — they *are* the input.

### Upstream product spec resolution

The upstream product spec for a downstream spec at `<lane>/<platform>/<feature>.md` is always `product/<feature>.md` (the shared, platform-neutral spec). Platform-specific product supplements at `product/<platform>/<feature>.md` are not hashed — they are treated as addenda to the shared spec and any downstream variance is captured in the downstream spec itself.

If `product/<feature>.md` does not exist, the downstream spec cannot be stamped. This is an error — product must exist first (see "The Cardinal Rule").

### Hash normalization rules

The hash must be deterministic across macOS, Linux, and any combination of git autocrlf settings. Normalization is applied to the raw file bytes before hashing:

1. Strip a leading UTF-8 BOM (`EF BB BF`) if present.
2. Convert CRLF (`\r\n`) to LF (`\n`). Lone CR (`\r`) is also converted to LF.
3. Collapse trailing blank lines: strip any run of whitespace-only lines at end of file, then append exactly one LF. Files with no trailing newline gain one.
4. Do not touch any other whitespace. Internal blank lines, leading/trailing spaces on non-blank lines, and tab/space indentation are preserved byte-for-byte.

The hash is the lowercase hex sha256 of the normalized bytes. Implementations should use `sha256sum` on Linux and `shasum -a 256` on macOS; both produce identical output on identical input.

### Slug extraction rules

`product-slugs` is computed by scanning the **normalized** product spec for tokens matching `(FR|NFR|AC)-[a-z0-9-]+` (case-sensitive prefix, lowercase body). The resulting list is deduplicated and sorted ascending by byte order. `TC-` is excluded — test case slugs live in QA specs, not product.

Tokens inside fenced code blocks are included (product specs occasionally embed example slugs in examples; treating code-fenced slugs specially would make extraction context-dependent and harder to reproduce).

### When to stamp

Downstream agents stamp `product-hash` and `product-slugs` every time they **create or update** a spec:

- On create: compute both fields from the current product spec and write them into the new spec's frontmatter.
- On update: recompute both fields and overwrite the stamped values, even if the update itself was not driven by a product change. The frontmatter always reflects the product spec as it stood at the moment the downstream spec was last touched.

If the product spec does not yet exist, the downstream spec should not be created — product is a hard prerequisite.

### Consumers

The stamped fields are consumed by:

- `/cascade` — diffs stamped hash/slugs against current product spec, reports per-lane drift, prompts for action.
- `/audit` — standalone non-blocking drift report.
- `scripts/audit-traceability.sh` — pre-commit hook extension that blocks commits when stamped values don't match the current product spec (subject to the `enforceCascade` config toggle and the `PDEQ_ALLOW_DRIFT=1` escape hatch).

Workflow details, command definitions, and hook behavior are covered in their respective sections and command files. This section defines only the on-disk convention.

## Slash Commands

The following custom commands are available:

- **`/kickoff [feature description]`** — Full feature kickoff. Checks `roadmap/` for an existing entry to pull context from, then determines target platform(s) and creates product spec → design spec → engineering spec → QA test plan (plus platform-specific variants as needed) → updates index, glossary, and pending decisions → runs review and consistency checks. If a roadmap entry was used, remove the corresponding item from `roadmap/<feature>.md` once the spec is minted.
- **`/impact [slug or feature]`** — Impact analysis. Reads `index.md` to report every artifact that would need to change if a requirement is modified.
- **`/status`** — Project dashboard. Scans all folders and reports feature coverage, slug coverage, and traceability gaps.

## Quality Subagents

In addition to the four functional agents, two quality-checking roles can be invoked:

### Reviewer

The reviewer reads a spec alongside its upstream inputs and checks for:
- **Gaps**: Requirements that aren't addressed in the downstream spec
- **Inconsistencies**: Details that contradict the upstream spec
- **Ambiguity**: Vague language that could be interpreted multiple ways
- **Completeness**: Missing sections, empty states not defined, error cases not handled

Invoke the reviewer after any agent produces or updates a spec. It reads the spec and all upstream specs, then reports issues.

### Consistency Checker

The consistency checker reads across all artifacts and checks for:
- **Terminology mismatches**: Product says "login" but design says "sign in"
- **Glossary compliance**: Terms used that aren't in `glossary.md`, or glossary terms not being used where they should be
- **Naming drift**: The same concept being called different things in different specs
- **Slug integrity**: Slugs that are referenced but not defined, or defined but not referenced

Invoke the consistency checker periodically, or as part of `/kickoff`.

## Shared Project Files

| File | Purpose |
|---|---|
| `index.md` | Traceability index — maps every slug to all references |
| `glossary.md` | Shared vocabulary — all agents must use consistent terminology |
| `decisions.md` | Append-only decision log — records key decisions and rationale. Provides historical context for how the project evolved (specs show current state; this shows *why*). **Do not edit directly during a session — write to `decisions-pending.md` instead (see below).** |
| `decisions-pending.md` | Staging file for new decision entries. Merged into `decisions.md` by the pre-commit hook. Gitignored — never committed directly. |

All agents should consult `glossary.md` before introducing new terms.

### Decision Log Workflow

**Never write directly to `decisions.md` during a session.** Instead:

1. Write new decision entries to `decisions-pending.md` using the same format as `decisions.md`.
2. Multiple decisions can be appended to the pending file during a session — that's fine.
3. At commit time, the pre-commit hook (`scripts/merge-decisions.sh`) merges all pending entries into `decisions.md` in a single update, then deletes the pending file.

This ensures `decisions.md` is only updated once per commit, keeping diffs clean and avoiding repeated churn on a shared file during multi-step sessions.

## Other Rules

- Never create requirements, designs, architecture docs, or test plans outside their designated folders.
- Keep unscoped future ideas in `roadmap/`, not in product, design, engineering, or QA specs. Specs describe today.
- Always start with product requirements before moving to other functions, unless the user explicitly asks otherwise.
- When updating one area, consider whether dependent areas need updates too. Flag this to the user.
- Keep a consistent naming convention across folders for the same feature (e.g., `auth.md` in product, design, engineering, and qa all relate to the same feature).
- For platform-specific specs, use the same feature name in the platform subfolder (e.g., `design/mobile/auth.md`, `engineering/mobile/auth.md`, and `qa/mobile/auth.md` all relate to the mobile variant of the auth feature).
- When a feature is being ported to a new platform, check `index.md` to find all existing specs and determine which need platform-specific variants.

@FP_CLAUDE.md
