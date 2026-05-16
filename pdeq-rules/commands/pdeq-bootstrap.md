# Bootstrap: $ARGUMENTS

<!-- Implements: FR-harness-agnostic-bootstrap-inline, FR-harness-agnostic-no-subagent-files -->

The user wants to bootstrap PDEQ on an existing codebase.

Parse `$ARGUMENTS` for flags:
- `--dry-run` — analyze only, do not write any spec files
- `--feature <name>` — scope the bootstrap to a single feature area

This command runs entirely from one agent role: you play the **analyzer** role first (Step 2), then the **generator** role (Step 4). Harnesses that support spawning named subagents internally may delegate either role to a subtask if they prefer; the workflow works either way and does not require any subagent definition file to be present.

---

## Step 0: Load Configuration

Read `pdeq.json` if it exists. Extract:
- `specsRoot` (default: `.`)
- `codeRoot` (default: `.`)
- `platforms` (default: `[]`)
- `nested.label` (if present, use as context for agent messages)

If `pdeq.json` is missing:
- Check whether `product/`, `design/`, `engineering/`, `qa/` directories exist. If not, tell the user to run `scripts/init.sh` first.
- Proceed with all paths defaulting to `.`

Inform the user of the resolved configuration:
```
Code root:   {codeRoot}
Specs root:  {specsRoot}
Platforms:   {platforms or "none configured"}
Dry run:     {yes/no}
```

Ask the user to confirm before proceeding.

---

## Step 0.5: Offer Git Hook Install

Pdeq's pre-commit audit and commit-msg migrations gate only fire if
`core.hooksPath` points at the pdeq hooks directory. Check current state
and offer to wire hooks now so drift is caught from the next commit onward.

1. Run `git config --get core.hooksPath` (at the git root).
2. Determine the expected hooks path:
   - Consumer install: `.pdeq/hooks` (relative to git root)
   - Self-host: `hooks` (relative to git root)
3. Compare:
   - If the current value equals the expected path: print
     `✓ pdeq git hooks already installed at <path>` and continue.
   - If `core.hooksPath` is unset: prompt the user:
     > Install pdeq git hooks? They run the traceability audit, merge
     > decisions, and enforce the migrations gate automatically at commit
     > time. You can skip per-commit with `PDEQ_SKIP_HOOKS=1 git commit …`.
     > [Y/n]
     On `Y` (or empty), run `git config core.hooksPath <expected>` and
     print a confirmation. On `n`, continue without installing and print
     a reminder that the audit can still be invoked manually.
   - If `core.hooksPath` is set to some *other* path: print
     `⚠ core.hooksPath is currently '<value>' — not changing. Move or
     chain your existing hook config to use pdeq hooks if desired.` and
     continue.

This step is idempotent: re-running bootstrap on an already-wired repo
does nothing.

---

## Step 1: Check for Existing Analysis

Check whether `{specsRoot}/bootstrap-analysis.md` exists.

**If it exists:** Ask the user:
> `bootstrap-analysis.md` already exists. Would you like to:
> 1. Use the existing analysis (skip to spec generation)
> 2. Re-run the analyzer (overwrites existing analysis)

**If it does not exist:** Proceed to Step 2.

---

## Step 2: Play the Analyzer Role

Now play the **bootstrap analyzer** role. Read the codebase at `codeRoot` and produce a structured list of requirements, organized by feature area, with confidence levels and source citations. You do **not** write spec files in this step — that happens in Step 4. The output of this step is a single intermediate analysis document at `{specsRoot}/bootstrap-analysis.md`.

### What to analyze

Read the codebase looking for these signals, in rough priority order:

| Signal | What to extract |
|---|---|
| README files | Feature descriptions, usage examples, configuration options |
| Test names and test files | Test names often map 1:1 to acceptance criteria (`it('should reject invalid email')` → `AC-ex-invalid-email`) |
| Function/method signatures | Public APIs imply functional requirements |
| Docstrings and inline docs | Direct requirement statements |
| Comments starting with `TODO`, `FIXME`, `NOTE`, `SPEC:` | Known gaps and intended behavior |
| OpenAPI / protobuf / TypeScript interfaces | API contracts imply functional and non-functional requirements |
| Error messages and validation logic | Each distinct error path implies an acceptance criterion |
| Config and feature flags | Each flag implies a product requirement |
| Package/module names and file structure | Imply feature groupings and boundaries |

### How to group requirements

Group discovered requirements by **feature area** — a feature area corresponds to a single spec file (e.g., `auth`, `billing`, `notifications`). Use these heuristics:

- **Directory/module names**: `src/auth/` → feature area `auth`
- **Domain nouns in function names**: `createUser`, `validateSession` → feature area `auth`
- **Test file names**: `auth.test.ts`, `billing_spec.rb` → feature areas `auth`, `billing`
- **README sections**: use section headings as feature area names

If requirements don't fit a named feature, place them in a `core` feature area.

### Output format

Write your output to `{specsRoot}/bootstrap-analysis.md` using this exact structure:

```markdown
# Bootstrap Analysis

Generated: {date}
Code root: {codeRoot}

## Summary

- {N} feature areas discovered
- {N} functional requirements extracted
- {N} acceptance criteria extracted
- {N} non-functional requirements extracted
- {N} gaps identified (things the code does but that are underdocumented)

## Feature Areas

### {feature-area-name}

**Source paths:** `src/auth/`, `tests/auth.test.ts`

#### Functional Requirements

| Proposed slug | Description | Confidence | Source |
|---|---|---|---|
| `FR-ex-email-login` | Users can log in with email and password | high | `src/auth/login.ts:42` |
| `FR-ex-oauth-google` | Users can authenticate via Google OAuth | medium | `src/auth/oauth.ts:12` |

#### Acceptance Criteria

| Proposed slug | Description | Confidence | Source |
|---|---|---|---|
| `AC-ex-invalid-password` | Login fails with clear error when password is wrong | high | `tests/auth.test.ts:88` |

#### Non-Functional Requirements

| Proposed slug | Description | Confidence | Source |
|---|---|---|---|
| `NFR-ex-login-latency` | Login response < 500ms under normal load | medium | `src/auth/login.ts:15 (comment)` |

#### Gaps

- Password reset flow: code exists (`src/auth/reset.ts`) but no tests or docs found
- Session expiry: referenced in config but behavior not documented

---

(repeat for each feature area)

## Cross-Cutting Requirements

Requirements that span multiple feature areas (auth, logging, error handling, etc.):

| Proposed slug | Description | Confidence | Source |
|---|---|---|---|
| `NFR-ex-api-latency` | All API responses < 200ms p95 | low | inferred from load test config |

## Items Needing Human Review

List anything that was ambiguous, contradictory, or requires a product decision:

- `{feature}`: {description of ambiguity}
```

### Confidence levels

| Level | Meaning |
|---|---|
| `high` | Directly stated in docs, README, or test name — unambiguous |
| `medium` | Inferred from code structure or comments — likely correct but needs human confirmation |
| `low` | Guessed from patterns or naming — definitely needs human review |

### Slug proposals

Propose slugs following PDEQ conventions: `<PREFIX>-<feature>-<descriptive-slug>`

- Use lowercase, hyphens only, no underscores
- Be descriptive but concise (`FR-ex-email-login` not `FR-auth-login-with-email-and-password`)
- Mark as proposed — the generator role and human reviewer will assign final slugs

### Constraints for this role

- **Read-only**: You only read files. You do not modify any source code or existing specs.
- **No hallucination**: Only extract what you can directly point to in the code. If you're unsure, use `low` confidence.
- **Scope**: Stay within `codeRoot`. Do not analyze files outside this path.
- **Dry run support**: If invoked with `--dry-run`, append `(dry run — no files written)` to the summary and write to stdout only.

### Finishing the analyzer role

1. Write `bootstrap-analysis.md` to `{specsRoot}/bootstrap-analysis.md`
2. Print a one-paragraph summary to the user: how many feature areas found, total requirements extracted, major gaps identified.

---

## Step 3: Present Analysis Summary

Read `{specsRoot}/bootstrap-analysis.md` and present a summary to the user:

- Number of feature areas discovered
- Total requirements extracted (by type: FR, NFR, AC)
- Number of high / medium / low confidence items
- Items needing human review
- Gaps identified

Ask the user to confirm before generating specs:
> Ready to generate draft specs for {N} feature areas ({M} total requirements). Proceed?

If the user requests changes to the analysis before generating specs, update `bootstrap-analysis.md` accordingly (or ask them to edit it manually) before continuing.

**If `--dry-run` was requested:** Stop here. Print the analysis summary and tell the user: "Dry run complete. No files were written. Review `bootstrap-analysis.md` and re-run without `--dry-run` to generate specs."

---

## Step 4: Play the Generator Role

Now play the **bootstrap generator** role. Read `{specsRoot}/bootstrap-analysis.md` (produced by Step 2) and write draft PDEQ spec files.

### Job

For each feature area in `bootstrap-analysis.md`, produce:

1. A **product spec** at `{specsRoot}/product/{feature}.md`
2. A **platform engineering spec** at `{specsRoot}/engineering/{platform}/{feature}.md` for each platform in `pdeq.json` (or each platform with relevant code in the analysis)

Then:
3. Update `{specsRoot}/index.md` with all generated slugs
4. Write `{specsRoot}/bootstrap-summary.md` — a human-readable report of what was generated

### Input

Read `{specsRoot}/bootstrap-analysis.md`. This file contains:
- Feature areas with proposed slugs, descriptions, confidence levels, and source citations
- Cross-cutting requirements
- Gaps and items needing human review

Also read `pdeq.json` if present to determine `specsRoot`, `codeRoot`, and `platforms`.

### Product spec template

For each feature area, create `{specsRoot}/product/{feature}.md`:

```markdown
# {Feature Name}

> **Draft** — Generated by /pdeq-bootstrap on {date}. Requirements marked `<!-- bootstrap: review-needed -->` need human verification.

## Overview

{1-2 sentence description of what this feature does, inferred from the analysis.}

## Functional Requirements

### {Requirement group}

**FR-{feature}-{slug}** <!-- bootstrap: review-needed -->
{Description of what the system does.}

**FR-{feature}-{slug-2}** <!-- bootstrap: review-needed -->
{Description.}

## Non-Functional Requirements

**NFR-{feature}-{slug}** <!-- bootstrap: review-needed -->
{Description of performance, reliability, or quality expectation.}

## Acceptance Criteria

**AC-{feature}-{slug}** <!-- bootstrap: review-needed -->
{Testable statement of expected behavior.}

## Open Questions

{List items from the analysis "Items Needing Human Review" section that apply to this feature.}
```

**Lane discipline**: Product specs must be platform-neutral. Do not include:
- UI element names, pixel values, colors, layout terms
- Library names, API endpoint paths, algorithm names
- OS-specific APIs or platform-specific mechanisms

If a discovered requirement would violate lane discipline, either generalize it or leave it out with a note.

### Engineering spec template

For each feature area and each relevant platform, create `{specsRoot}/engineering/{platform}/{feature}.md`:

```markdown
# {Feature Name} — {Platform} Engineering

> Based on requirements in `../../product/{feature}.md`
> **Draft** — Generated by /pdeq-bootstrap on {date}. Review before treating as authoritative.

## Overview

{Brief summary of the technical approach as inferred from the code.}

## Source Locations

| Component | Path |
|---|---|
| {component name} | `{path relative to codeRoot}` |

## Key Abstractions

{List major functions, classes, interfaces discovered during analysis, with brief descriptions.}

## Implementation Notes

{Anything inferred from comments, TODOs, or code structure worth calling out.}

## Open Technical Questions

{List TODOs, FIXMEs, and low-confidence technical findings from the analysis.}
```

### index.md updates

For every slug you write to a spec file, add it to `{specsRoot}/index.md` in this format:

```markdown
| FR-ex-email-login | product/auth.md | — | — | — |
```

Columns: `slug | product file | design file | engineering file | QA file`

Use `—` for files that don't exist yet.

### bootstrap-summary.md

Write `{specsRoot}/bootstrap-summary.md`:

```markdown
# Bootstrap Summary

Generated: {date}

## Files Created

| File | Slugs Generated | Needs Review |
|---|---|---|
| product/auth.md | 4 FR, 2 NFR, 3 AC | 6 items |
| engineering/web/auth.md | — | 2 items |

## Slugs Generated

{Full list of all slugs written, one per line}

## Items Requiring Human Review

These were generated with medium or low confidence, or flagged as ambiguous:

### product/auth.md

- **FR-ex-oauth-google**: Inferred from file presence (`src/auth/oauth.ts`), but no tests found. Confirm this is a supported flow.

### (etc.)

## Gaps Identified

Things the code appears to do but that produced no spec entries (too ambiguous to auto-generate):

- {gap description} — see `{source file}`

## Next Steps

1. Open each spec file and review `<!-- bootstrap: review-needed -->` items
2. Remove the bootstrap marker when you've verified each requirement
3. Run `./scripts/audit-traceability.sh` to verify index integrity
4. Run `./scripts/audit-lanes.sh` to check for lane violations in product specs
5. Commit the generated specs when you're satisfied
6. Run `/pdeq-kickoff` on any new features you want to design and implement end-to-end
```

### Safety rules for the generator role

- **Never overwrite existing specs.** If `product/auth.md` already exists, skip it and note it in the summary. Never append to existing specs either — changing an existing spec is a human decision.
- **Mark everything as draft.** Every generated requirement gets `<!-- bootstrap: review-needed -->` so humans can audit.
- **Slug conflicts:** If a proposed slug from the analysis already exists in `index.md`, skip it and note the conflict in the summary.
- **Dry run:** If invoked with `--dry-run`, print what would be created but write nothing. Show a file list and slug list to stdout.

### Spec quality requirements

Before finishing, verify:
- All product specs pass `audit-lanes.sh` (no tech bleed). If violations exist, generalize the language rather than deleting the requirement.
- All slugs follow `FR-`/`NFR-`/`AC-` format with `{feature}-{slug}` naming.
- `index.md` is valid — run `audit-traceability.sh` (or mentally walk it).

---

## Step 5: Quality Checks

Run both audit scripts and report results:

```bash
./scripts/audit-traceability.sh
./scripts/audit-lanes.sh
```

If either audit fails, list the failures clearly. Do not block the user from proceeding — bootstrap output is explicitly draft — but call out any issues that need fixing before the specs can be committed.

---

## Step 6: Print Bootstrap Summary

Read and display `{specsRoot}/bootstrap-summary.md` in full.

Then print the following next steps:

```
Next steps:
1. Review each spec file and resolve <!-- bootstrap: review-needed --> items
2. Remove the bootstrap marker from each item you've verified
3. Run ./scripts/audit-traceability.sh to check index integrity
4. Run ./scripts/audit-lanes.sh to check for lane violations
5. Commit the generated specs when you're satisfied
6. Run /pdeq-kickoff to design and implement any of these features end-to-end
```
