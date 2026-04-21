---
target-version: X.Y.Z
breaking: true
summary: One-line description shown in /migrate output after the em-dash.
scope: default
---

# Migration X.Y.Z — Short title

<!--
Template for authoring a pdeq migration file.

Copy this file to `migrations/<version>.md`, where `<version>` matches
`target-version` above and is the pdeq version this migration advances
a project to (semver MAJOR.MINOR.PATCH, no pre-release).

Parsed sections are H2 headings with the exact vocabulary:
`Context`, `Mechanical`, `Semantic` (with H3 `Files` / `Prompt`),
`Notes`. Any other heading is prose and ignored by the runner.

Delete these HTML comments before committing.
-->

## Context

Short prose for humans. Explain why this migration exists, what changed
in pdeq, and what the consumer should expect to see in their diff. The
runner ignores this section.

## Mechanical

One fenced `shell` block per operation. The runner executes these
sequentially via the Bash tool. Every block MUST be idempotent —
re-running against already-migrated content is a no-op, not a
double-apply.

```shell
# Describe what this block does. Guard writes so the block is safe to
# re-run. Example idempotency patterns:
#   * grep before writing (skip if already applied)
#   * sed in-place with a pattern that only matches pre-migration content
#   * awk that detects already-migrated structure and exits 0
echo "replace me"
```

Delete this section entirely if the migration has nothing mechanical
to do (semantic-only migrations are legal but rare — most breaking
changes have at least one file edit).

## Semantic

Optional. Omit this entire section — heading and all — if no semantic
pass is needed. Do not leave an empty `## Semantic` heading.

### Files

Glob-style list of files the agent is given as context. The runner
loads exactly these and no others.

- `product/**/*.md`
- `design/**/*.md`
- `engineering/**/*.md`
- `qa/**/*.md`

### Prompt

Verbatim instructions to the agent. The prompt MUST:

1. Describe what to look for.
2. Describe what to change.
3. Describe what NOT to change.
4. Instruct the agent to make NO change on files that are already
   conformant — silence means "already conformant." This preserves
   idempotency on re-runs.
5. Instruct the agent to end with exactly one summary line:
   `updated N of M files`.

## Notes

Optional. Author's notes: edge cases encountered while writing the
migration, rationale for non-obvious choices, links to the PR that
introduced the breaking change. Ignored by the runner.
