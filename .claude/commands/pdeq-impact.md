# Impact Analysis: $ARGUMENTS

The user wants to understand the impact of changing a requirement. The input is: **$ARGUMENTS**

This could be a slug (like `FR-auth-email-login`), a feature name (like "auth"), or a description of a change.

## Step 1: Identify the Slugs

If the user provided a specific slug, use that. If they provided a feature name or description, search `product/` to find the relevant slugs.

List all slugs that would be affected.

## Step 2: Read the Traceability Index

Read `index.md` and find every entry for the affected slugs. For each slug, collect:
- Where it's defined (product spec)
- Where it's referenced in design
- Where it's referenced in engineering (specs and code)
- Where it's covered in QA

## Step 3: Read the Affected Files

For each file listed in the index entries, read it and identify the specific sections that reference the affected slugs.

## Step 4: Report

Present a clear impact report:

```
## Impact Report: [slug or feature]

### Directly Affected
- product/[file].md — [which sections]
- design/[file].md — [which sections]
- engineering/[file].md — [which sections]
- engineering/src/[path] — [which code]
- qa/[file].md — [which test cases]

### Potentially Affected
- [anything that might be indirectly impacted]

### Recommended Update Order
1. Update product spec
2. Update design spec
3. Update engineering spec
4. Update QA test plan
5. Update code
6. Update index.md
```

If no index entries exist for the slug, say so — it means the index is incomplete and should be fixed.
