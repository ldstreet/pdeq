# Kickoff: $ARGUMENTS

The user has described what they want: **$ARGUMENTS**

Follow this sequence exactly. Steps are sequential unless noted otherwise. **Maximize parallelism** — launch independent tasks simultaneously wherever the dependency graph allows.

---

## Step 0: Triage — Decide What's Needed

Before doing anything, analyze the request and decide:

### A) Which platform(s) are in scope?

Determine the target platform(s) for this request:
- **Single-platform** — Affects only one platform. Create or update specs for that platform using the naming convention defined in AGENTS.md.
- **Cross-platform** — Affects multiple platforms. Create/update the base spec (shared behavior), then create/update platform-specific variants where behavior diverges.
- **Porting** — An existing feature being brought to a new platform. Base specs exist; create only platform-specific variants.

If the request doesn't specify a platform, ask the user. For the current project, the active platforms are listed in the "Multi-Platform Support" section of AGENTS.md.

### B) Which existing spec does this belong to?

Read the files in `product/` (excluding AGENTS.md and CLAUDE.md) to see what specs already exist. Determine whether this request:
- **Modifies an existing feature** → Update the existing spec file(s). Do NOT create a new file.
- **Adds a genuinely new feature** → Create a new spec file only if this is truly a distinct feature that doesn't belong in any existing spec.

Specs are **living documents** that represent the product as it is (or will be). Think of each spec as the single source of truth for that feature area. Modifications, enhancements, and refinements go into the existing spec — they do not spawn new files.

When porting to a new platform, the base spec already exists — check if a platform-specific variant already exists too.

### B.1) Check the roadmap

Scan `roadmap/` (excluding AGENTS.md and CLAUDE.md) for an entry that matches this request. Two cases matter:

- **Request matches a roadmap item** (e.g., user says "let's do the fast-follow for auth that we noted") — Read `roadmap/<feature>.md` to pull in the captured intent before delegating to product. The roadmap entry is context, not a spec — the product agent still writes proper requirements with slugs.
- **Request matches an existing feature with a roadmap file** — Even if the user doesn't reference it, skim the roadmap for related future ideas that might inform scope decisions.

Track which roadmap item(s) this kickoff graduates. You'll remove them in Step 4.

### C) Which functional areas are actually needed?

Not every request requires all four areas. Decide which are relevant:

| Request type | Product | Design | Engineering | QA |
|---|---|---|---|---|
| New user-facing feature | Yes | Yes | Yes | Yes |
| UX/UI change to existing feature | Maybe (if requirements change) | Yes | Yes | Yes |
| Technical/performance improvement | Maybe (add NFR if needed) | No (unless UX is affected) | Yes | Yes (performance tests) |
| Bug fix | No (unless requirements were wrong) | No (unless design was wrong) | Yes | Yes |
| Refactoring / tech debt | No | No | Yes | Maybe |
| Porting existing feature to new platform | Maybe (if platform-specific reqs) | Yes (if UI differs) | Yes | Yes |

**Be honest about what's needed.** A request like "make it launch faster" is primarily an engineering concern. Product might add a brief NFR ("app should launch within Xms"), but it doesn't need a design spec. Don't create artifacts just to check boxes.

Announce your triage decision to the user before proceeding:
- Which platform(s) are targeted
- Which spec file(s) will be created or updated (including platform-specific variants)
- Which functional areas will be involved and why
- Which functional areas are being skipped and why
- Which roadmap item(s), if any, will be graduated and removed

---

## Step 1: Product Requirements

**Only if triage determined product work is needed.**

Delegate to the product agent (operating in `product/`). Be explicit about whether this is a **new spec**, an **update to an existing spec**, or a **platform-specific variant**:

- **Updating an existing spec**: Tell the agent which file to update, what sections need changes, and what to add/modify. The agent should read the existing file first and make targeted edits — not rewrite the whole file.
- **New spec**: Have it create a new PRD markdown file following the template in `product/AGENTS.md`.
- **Platform-specific variant**: Tell the agent which base spec to reference and have it create a platform-specific variant file (following the naming convention in AGENTS.md) that covers only platform-specific requirements and divergences. The variant must reference the base spec and not duplicate shared requirements.

For cross-platform work, always do the base spec first, then platform variants **in parallel** (e.g., launch platform-A and platform-B variant agents simultaneously — they don't depend on each other).

Ensure all requirement slugs follow the format: `FR-<feature>-<slug>`, `NFR-<feature>-<slug>`, `AC-<feature>-<slug>`

Before moving on, read back the product spec and verify it's complete. If the user's description was vague, the product agent should list open questions — present those to the user and resolve them before continuing.

**Do not proceed to Step 2 until this step is fully complete and verified.**

---

## Step 2: Design Spec

**Only if triage determined design work is needed. Wait for Step 1 to complete first.**

Read the product spec from Step 1 (or the existing product spec if Step 1 was skipped). Delegate to the design agent (operating in `design/`):

- **Updating an existing spec**: Tell the agent which file to update and what changed in the product spec. The agent should make targeted updates — not rewrite.
- **New spec**: Have it create a design spec following `design/AGENTS.md`.
- **Platform-specific variant**: Tell the agent which base design spec to reference and have it create a platform-specific variant. The variant covers platform-specific UI/UX (e.g., native controls, platform conventions) and references the base spec for shared behavior.

For cross-platform work, do the base design spec first, then platform variants **in parallel**.

The design spec must address every requirement and user story. Reference specific requirement slugs.

**Do not proceed to Step 3 until this step is fully complete.**

---

## Step 3: Engineering Spec + QA Test Plan (parallel)

**Wait for Step 2 to complete first (or Step 1 if design was skipped).**

These two can run **in parallel** because both depend on the same upstream inputs (product spec + design spec) and neither depends on the other at the spec level.

### Engineering Spec

Read the product spec and design spec (whichever exist). Delegate to the engineering agent (operating in `engineering/`):

- **Updating an existing spec**: Tell the agent which file to update, what changed upstream, and what technical approach needs revisiting.
- **New spec**: Have it create a technical spec following `engineering/AGENTS.md`.
- **Platform-specific variant**: Tell the agent which base engineering spec to reference and have it create a platform-specific variant. The variant covers platform-specific architecture (e.g., different UI frameworks, native APIs vs web APIs) and references the base spec for shared patterns.

Tell the engineering agent explicitly:

- **Populate the Code Map section.** Every platform engineering spec must include a `## Code Map` table with one row per functional requirement. If no code exists yet, use `—` for the location and Status `planned`. If a requirement is deliberately deferred, Status `unimplemented` (exempts it from coverage warnings). See the template in `engineering/AGENTS.md`.
- **Stamp `product-hash` and `product-slugs` frontmatter.** Recompute both from the current product spec every time the engineering spec is created or updated.

Do NOT write code at this stage — only the technical spec.

### QA Test Plan

**Only if triage determined QA work is needed.**

Read the product spec and design spec. Delegate to the QA agent (operating in `qa/`):

- **Updating an existing test plan**: Tell the agent which file to update, what changed, and which test cases need adding/modifying.
- **New test plan**: Have it create a test plan following `qa/AGENTS.md`.
- **Platform-specific variant**: Tell the agent which base test plan to reference and have it create a platform-specific variant. The variant covers platform-specific test cases and tooling, and references the base plan for shared test logic.

Test cases must cover every acceptance criterion. Reference specific slugs.

**Note:** When it later comes time to *implement* (write actual code and tests), that must be sequential — engineering implements first, then QA writes/runs tests against the implementation. But at the spec-writing stage, they can work simultaneously. For cross-platform work, platform-specific engineering and QA variants can also be written in parallel.

---

## Step 4: Post-Processing + Quality Checks (parallel)

**Wait for Step 3 to complete.**

Maximize parallelism here — launch all independent tasks simultaneously using multiple Task calls in one message:

### Parallel batch — launch ALL of these at the same time:

1. **Update traceability index** — Update `index.md` at the project root. For any new slugs, add entries linking to all referencing files. For modified slugs, update the references.

2. **Update glossary** — Review the artifacts created or modified. If any new domain terms were introduced, add them to `glossary.md`. If none were introduced, skip this.

3. **Log decisions** — If any significant decisions were made during this kickoff (technology choices, scope decisions, design patterns), append them to `decisions-pending.md` (not `decisions.md` directly — the pre-commit hook merges pending entries at commit time). If no significant decisions were made, skip this.

4. **Reviewer pass** — Read all artifacts that were created or modified and check for gaps, inconsistencies, or mismatches between them. Report any issues found.

5. **Consistency pass** — Check that terminology is consistent across all artifacts and matches `glossary.md`.

6. **Graduate roadmap items** — If this kickoff consumed any roadmap entry (per Step 0 B.1), remove the graduated item(s) from `roadmap/<feature>.md`. Delete the file entirely if no items remain.

### After the parallel batch completes:

Run `./scripts/audit-traceability.sh` to verify the index is correct. This must wait for the index update (task 1) to finish.

---

## Step 5: Summary

Present a summary to the user:
- What was **created** (new files)
- What was **updated** (existing files, with a summary of changes)
- What was **skipped** and why
- Any issues found during review or consistency checks
- Traceability audit result (pass/fail)

Then print a reminder about inline markers:

> **Next when you implement this feature:** add `// Implements: <slug>`
> markers (or the language-appropriate form — `#` for shell/Python,
> `<!-- ... -->` for Markdown, etc.) at the smallest enclosing unit
> that realizes each functional requirement. The pre-commit audit
> will pick them up and populate the `Code` column in `index.md`
> automatically. See the root `AGENTS.md` §Requirement ↔ Code Mapping
> for the full syntax table.
