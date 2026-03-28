# Project Status Dashboard

Scan all four functional folders and the traceability index to build a status report.

## Step 1: Inventory Features

Scan `product/` for all feature spec files (excluding CLAUDE.md). Each file represents a feature. Collect the filenames.

## Step 2: Check Coverage Per Feature

For each feature found in product/, check whether a corresponding file exists in:
- `design/` (same filename)
- `engineering/` (same filename)
- `qa/` (same filename)

## Step 3: Slug Coverage

For each feature, count:
- How many slugs are defined in the product spec (FR-*, NFR-*, AC-*)
- How many of those slugs appear in the design spec
- How many appear in the engineering spec
- How many have test cases in the QA spec
- How many are in `index.md`

## Step 4: Run Audit

Run `./scripts/audit-traceability.sh` and capture the results.

## Step 5: Present Dashboard

```
## Project Status

### Feature Coverage

| Feature | Product | Design | Engineering | QA | Index |
|---|---|---|---|---|---|
| auth | ✓ (8 slugs) | ✓ (8/8) | ✓ (6/8) | ✓ (7/8) | 8/8 |
| onboarding | ✓ (5 slugs) | ✗ missing | ✗ missing | ✗ missing | 3/5 |

### Summary
- X features defined
- Y fully covered (all four stages)
- Z partially covered
- N traceability issues

### Gaps
- [List specific missing specs or uncovered slugs]

### Audit Results
[Output from audit-traceability.sh]
```

If there are no features yet, just say the project is empty and ready for its first `/kickoff`.
