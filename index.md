# Traceability Index

This file maps every requirement slug to all files that define or reference it. It is the single source of truth for requirement traceability across the project.

**Slug types:**
- `FR-` — Functional requirements (defined in `product/`)
- `NFR-` — Non-functional requirements (defined in `product/`)
- `AC-` — Acceptance criteria (defined in `product/`)
- `TC-` — Test cases (defined in `qa/`)

**Agent rule:** Every agent must update this file when they create or reference a slug. This is not optional.

**Validation:** The `scripts/audit-traceability.sh` script validates this index. It will report errors if a slug is defined but missing from the index, referenced but not defined, or if a file path listed here does not exist. Run it manually at any time: `./scripts/audit-traceability.sh`

---

## Index

| Slug | Type | Defined In | Referenced In |
|------|------|------------|---------------|
| FR-migrations-version-field | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md, pdeq.schema.json, VERSION |
| FR-migrations-version-readable | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |
| FR-migrations-absent-version | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |
| FR-migrations-one-per-version | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |
| FR-migrations-ordered | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |
| FR-migrations-mechanical-block | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |
| FR-migrations-semantic-block | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |
| FR-migrations-order-within | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |
| FR-migrations-author-written | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |
| FR-migrations-explicit-run | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |
| FR-migrations-pending-detection | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |
| FR-migrations-ordered-application | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |
| FR-migrations-version-bump | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |
| FR-migrations-nonbreaking-advance | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |
| FR-migrations-noop-when-current | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |
| FR-migrations-dry-run | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |
| FR-migrations-idempotent | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |
| FR-migrations-scoped-writes | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |
| FR-migrations-breaking-gate | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |
| FR-migrations-no-false-positive | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |
| FR-migrations-lineage-integrity | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |
| FR-migrations-bootstrap-chain | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |
| FR-migrations-self-migration | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |
| FR-migrations-atomic-bump | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |
| FR-migrations-failure-report | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |
| FR-migrations-recoverable-partial | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |
| FR-migrations-unknown-version | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |
| FR-migrations-missing-file-refused | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |
| NFR-migrations-idempotency | NFR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |
| NFR-migrations-determinism | NFR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |
| NFR-migrations-scope-minimalism | NFR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |
| NFR-migrations-enforcement-precision | NFR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |
| AC-migrations-noop-when-current | AC | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |
| AC-migrations-ordered-apply | AC | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |
| AC-migrations-no-bump-on-failure | AC | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |
| AC-migrations-dry-run-accurate | AC | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |
| AC-migrations-gate-blocks | AC | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |
| AC-migrations-gate-allows-nonbreaking | AC | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |
| AC-migrations-semantic-context | AC | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |
| AC-migrations-idempotent-rerun | AC | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |
| AC-migrations-absent-reported | AC | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |
| AC-migrations-lineage-refused | AC | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |
| AC-migrations-scope-respected | AC | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |
| AC-migrations-self-migration-runs | AC | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |
| AC-migrations-nonbreaking-advance | AC | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |
| AC-migrations-missing-file-refused | AC | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |
| TC-migrations-status-line-printed | TC | qa/cli/migrations.md | |
| TC-migrations-status-line-at-latest | TC | qa/cli/migrations.md | |
| TC-migrations-version-field-read | TC | qa/cli/migrations.md | |
| TC-migrations-absent-version-state | TC | qa/cli/migrations.md | |
| TC-migrations-absent-version-no-writes | TC | qa/cli/migrations.md | |
| TC-migrations-newer-recorded-refused | TC | qa/cli/migrations.md | |
| TC-migrations-foreign-lineage-refused | TC | qa/cli/migrations.md | |
| TC-migrations-noop-at-latest | TC | qa/cli/migrations.md | |
| TC-migrations-noop-no-writes | TC | qa/cli/migrations.md | |
| TC-migrations-pending-detection-single | TC | qa/cli/migrations.md | |
| TC-migrations-pending-detection-multi | TC | qa/cli/migrations.md | |
| TC-migrations-pending-detection-none | TC | qa/cli/migrations.md | |
| TC-migrations-multi-order | TC | qa/cli/migrations.md | |
| TC-migrations-ordered-pending-list | TC | qa/cli/migrations.md | |
| TC-migrations-version-bump-success | TC | qa/cli/migrations.md | |
| TC-migrations-dry-run-no-writes | TC | qa/cli/migrations.md | |
| TC-migrations-dry-run-output-shape | TC | qa/cli/migrations.md | |
| TC-migrations-dry-run-semantic-skipped | TC | qa/cli/migrations.md | |
| TC-migrations-dry-run-matches-real-run | TC | qa/cli/migrations.md | |
| TC-migrations-dry-run-file-list-exhaustive | TC | qa/cli/migrations.md | |
| TC-migrations-rerun-is-noop | TC | qa/cli/migrations.md | |
| TC-migrations-mechanical-idempotent | TC | qa/cli/migrations.md | |
| TC-migrations-semantic-idempotent | TC | qa/cli/migrations.md | |
| TC-migrations-non-breaking-no-file | TC | qa/cli/migrations.md | |
| TC-migrations-one-file-per-version | TC | qa/cli/migrations.md | |
| TC-migrations-file-required | TC | qa/cli/migrations.md | |
| TC-migrations-no-auto-trigger | TC | qa/cli/migrations.md | |
| TC-migrations-mechanical-runs | TC | qa/cli/migrations.md | |
| TC-migrations-mechanical-absent-marker | TC | qa/cli/migrations.md | |
| TC-migrations-semantic-runs | TC | qa/cli/migrations.md | |
| TC-migrations-semantic-absent-marker | TC | qa/cli/migrations.md | |
| TC-migrations-mechanical-before-semantic | TC | qa/cli/migrations.md | |
| TC-migrations-atomic-bump-on-mechanical-fail | TC | qa/cli/migrations.md | |
| TC-migrations-atomic-bump-on-semantic-fail | TC | qa/cli/migrations.md | |
| TC-migrations-failure-report-names-migration | TC | qa/cli/migrations.md | |
| TC-migrations-failure-report-names-block | TC | qa/cli/migrations.md | |
| TC-migrations-failure-report-recovery-steps | TC | qa/cli/migrations.md | |
| TC-migrations-partial-recoverable-state | TC | qa/cli/migrations.md | |
| TC-migrations-resume-after-fix | TC | qa/cli/migrations.md | |
| TC-migrations-no-skip-gaps | TC | qa/cli/migrations.md | |
| TC-migrations-scope-default-enforced | TC | qa/cli/migrations.md | |
| TC-migrations-scope-broader-declared | TC | qa/cli/migrations.md | |
| TC-migrations-scope-semantic-context-confined | TC | qa/cli/migrations.md | |
| TC-migrations-semantic-context-receives-files | TC | qa/cli/migrations.md | |
| TC-migrations-untouched-files-unchanged | TC | qa/cli/migrations.md | |
| TC-migrations-gate-blocks-missing-file | TC | qa/cli/migrations.md | |
| TC-migrations-gate-passes-with-file | TC | qa/cli/migrations.md | |
| TC-migrations-gate-docs-only | TC | qa/cli/migrations.md | |
| TC-migrations-gate-nonframework | TC | qa/cli/migrations.md | |
| TC-migrations-gate-trailer-override | TC | qa/cli/migrations.md | |
| TC-migrations-self-migration-same-command | TC | qa/cli/migrations.md | |
| TC-migrations-self-migration-advances-version | TC | qa/cli/migrations.md | |
| TC-migrations-output-glyphs | TC | qa/cli/migrations.md | |
| TC-migrations-determinism-two-runs | TC | qa/cli/migrations.md | |
| TC-migrations-unknown-format-error | TC | qa/cli/migrations.md | |
| TC-migrations-grep-friendly | TC | qa/cli/migrations.md | |
| TC-migrations-nonbreaking-advance | TC | qa/cli/migrations.md | |
| TC-migrations-missing-file-refused | TC | qa/cli/migrations.md | |
