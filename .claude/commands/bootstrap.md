# Bootstrap: $ARGUMENTS

The user wants to bootstrap PDEQ on an existing codebase.

Parse `$ARGUMENTS` for flags:
- `--dry-run` — analyze only, do not write any spec files
- `--feature <name>` — scope the bootstrap to a single feature area

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

## Step 2: Run the Bootstrap Analyzer

Spawn a subagent using the bootstrap-analyzer agent instructions at `.claude/agents/bootstrap-analyzer/CLAUDE.md`.

Tell the analyzer:
- `codeRoot`: the resolved code root path
- `specsRoot`: the resolved specs root path
- `--dry-run`: pass through if the user requested dry run
- `--feature <name>`: pass through if the user scoped to a feature

**For large codebases** (more than ~50 source files): offer to bootstrap one feature at a time. Ask the user:
> This codebase looks large. Would you like to bootstrap everything at once, or start with a specific feature area?

Wait for the analyzer to complete and produce `{specsRoot}/bootstrap-analysis.md`.

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

## Step 4: Run the Bootstrap Generator

Spawn a subagent using the bootstrap-generator instructions at `.claude/agents/bootstrap-generator/CLAUDE.md`.

Tell the generator:
- `specsRoot`: the resolved specs root path
- `codeRoot`: the resolved code root path
- `platforms`: from pdeq.json or ask the user
- Path to `bootstrap-analysis.md`
- Any feature scoping (`--feature <name>`)

The generator will:
1. Create draft product specs in `{specsRoot}/product/`
2. Create draft engineering specs in `{specsRoot}/engineering/{platform}/`
3. Update `{specsRoot}/index.md`
4. Write `{specsRoot}/bootstrap-summary.md`

Wait for the generator to complete.

**If any existing spec would be overwritten:** The generator must skip it and log the conflict in `bootstrap-summary.md`. Never overwrite existing specs.

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
6. Run /kickoff to design and implement any of these features end-to-end
```
