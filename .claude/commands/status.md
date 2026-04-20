# Project Status Dashboard

Scan all four functional folders, the `roadmap/` folder, and the traceability index to build a status report.

## Step 1: Inventory Features

Scan `product/` for all feature spec files (excluding CLAUDE.md). Each file represents a feature. Collect the filenames.

Also scan `roadmap/` (excluding CLAUDE.md and `_overview.md`) for feature files with pending forward-looking ideas. A roadmap entry may reference a shipped feature (fast follow / V2 backlog) or an unshipped feature (pre-kickoff vision).

## Step 2: Check Coverage Per Feature

For each feature found in `product/`, check whether a corresponding file exists in:
- `design/` (same filename)
- `engineering/` (same filename)
- `qa/` (same filename)
- `roadmap/` (same filename — optional, indicates pending future work)

## Step 3: Slug Coverage

For each feature, count:
- How many slugs are defined in the product spec (FR-*, NFR-*, AC-*)
- How many of those slugs appear in the design spec
- How many appear in the engineering spec
- How many have test cases in the QA spec
- How many are in `index.md`

Roadmap files are not slug-tracked — skip slug counting for them.

## Step 4: Run Audit

Run `./scripts/audit-traceability.sh` and capture the results.

## Step 5: Present Dashboard

```
## Project Status

### Feature Coverage

| Feature | Product | Design | Engineering | QA | Index | Roadmap |
|---|---|---|---|---|---|---|
| auth | ✓ (8 slugs) | ✓ (8/8) | ✓ (6/8) | ✓ (7/8) | 8/8 | 3 items |
| onboarding | ✓ (5 slugs) | ✗ missing | ✗ missing | ✗ missing | 3/5 | — |

### Roadmap (unshipped)

Features with roadmap entries but no product spec yet (pre-kickoff vision):
- [List: roadmap/<feature>.md — one-line summary]

### Summary
- X features defined
- Y fully covered (all four stages)
- Z partially covered
- R features with roadmap entries
- N traceability issues

### Gaps
- [List specific missing specs or uncovered slugs]

### Audit Results
[Output from audit-traceability.sh]
```

If there are no features yet, just say the project is empty and ready for its first `/kickoff`.
