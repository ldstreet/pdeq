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

| Slug | Type | Defined In | Referenced In | Code |
|------|------|------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| FR-migrations-version-field | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md, pdeq.schema.json, VERSION | scripts/init.sh:543 |
| FR-migrations-version-readable | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md, scripts/migrate.sh | scripts/migrate.sh:82, scripts/migrate.sh:95 |
| FR-migrations-absent-version | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md | scripts/migrate.sh:82 |
| FR-migrations-one-per-version | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md, scripts/migrate.sh | scripts/migrate.sh:110 |
| FR-migrations-ordered | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md, scripts/migrate.sh | scripts/migrate.sh:110 |
| FR-migrations-mechanical-block | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md, scripts/migrate.sh | scripts/migrate.sh:155 |
| FR-migrations-semantic-block | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md, scripts/migrate.sh | scripts/migrate.sh:155 |
| FR-migrations-order-within | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md | pdeq-rules/commands/pdeq-migrate.md:1 |
| FR-migrations-author-written | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md | migrations/0.4.0.md:8, migrations/TEMPLATE.md:8 |
| FR-migrations-explicit-run | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md | pdeq-rules/commands/pdeq-migrate.md:1 |
| FR-migrations-pending-detection | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md, scripts/migrate.sh | scripts/migrate.sh:110 |
| FR-migrations-ordered-application | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md | pdeq-rules/commands/pdeq-migrate.md:1 |
| FR-migrations-version-bump | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md, scripts/migrate.sh | scripts/migrate.sh:219 |
| FR-migrations-nonbreaking-advance | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md, scripts/migrate.sh | scripts/migrate.sh:301 |
| FR-migrations-noop-when-current | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md, scripts/migrate.sh | scripts/migrate.sh:110 |
| FR-migrations-dry-run | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md | pdeq-rules/commands/pdeq-migrate.md:1 |
| FR-migrations-idempotent | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md | migrations/0.4.0.md:8, migrations/TEMPLATE.md:8 |
| FR-migrations-scoped-writes | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md, scripts/migrate.sh | scripts/migrate.sh:354 |
| FR-migrations-breaking-gate | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md | scripts/audit-migrations.sh:23 |
| FR-migrations-no-false-positive | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md | scripts/audit-migrations.sh:23 |
| FR-migrations-lineage-integrity | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md, scripts/migrate.sh | scripts/migrate.sh:272 |
| FR-migrations-bootstrap-chain | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |  |
| FR-migrations-self-migration | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md | pdeq-rules/commands/pdeq-migrate.md:1 |
| FR-migrations-atomic-bump | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md, scripts/migrate.sh | scripts/migrate.sh:219 |
| FR-migrations-failure-report | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md | pdeq-rules/commands/pdeq-migrate.md:1 |
| FR-migrations-recoverable-partial | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md | scripts/migrate.sh:219 |
| FR-migrations-unknown-version | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md, scripts/migrate.sh | scripts/migrate.sh:272 |
| FR-migrations-missing-file-refused | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md, scripts/migrate.sh | scripts/migrate.sh:301 |
| FR-migrations-update-command | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |  |
| FR-migrations-update-bumps-pin | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |  |
| FR-migrations-update-chains | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |  |
| FR-migrations-update-in-session | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |  |
| FR-migrations-update-noop | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |  |
| FR-migrations-update-bump-failure | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |  |
| FR-migrations-update-dry-run | FR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |  |
| NFR-migrations-idempotency | NFR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |  |
| NFR-migrations-determinism | NFR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md, scripts/migrate.sh |  |
| NFR-migrations-scope-minimalism | NFR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md, scripts/migrate.sh |  |
| NFR-migrations-enforcement-precision | NFR | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |  |
| AC-migrations-noop-when-current | AC | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md, scripts/migrate.sh |  |
| AC-migrations-ordered-apply | AC | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |  |
| AC-migrations-no-bump-on-failure | AC | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md, scripts/migrate.sh |  |
| AC-migrations-dry-run-accurate | AC | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |  |
| AC-migrations-gate-blocks | AC | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |  |
| AC-migrations-gate-allows-nonbreaking | AC | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |  |
| AC-migrations-semantic-context | AC | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |  |
| AC-migrations-idempotent-rerun | AC | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md, scripts/migrate.sh |  |
| AC-migrations-absent-reported | AC | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |  |
| AC-migrations-lineage-refused | AC | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md, scripts/migrate.sh |  |
| AC-migrations-scope-respected | AC | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md, scripts/migrate.sh |  |
| AC-migrations-self-migration-runs | AC | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |  |
| AC-migrations-nonbreaking-advance | AC | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md, scripts/migrate.sh |  |
| AC-migrations-missing-file-refused | AC | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md, scripts/migrate.sh |  |
| AC-migrations-update-end-to-end | AC | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |  |
| AC-migrations-update-noop | AC | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |  |
| AC-migrations-update-in-session | AC | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |  |
| AC-migrations-update-bump-failure | AC | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |  |
| AC-migrations-update-dry-run | AC | product/migrations.md | design/cli/migrations.md, engineering/cli/migrations.md, qa/cli/migrations.md |  |
| TC-migrations-status-line-printed | TC | qa/cli/migrations.md |  |  |
| TC-migrations-status-line-at-latest | TC | qa/cli/migrations.md |  |  |
| TC-migrations-version-field-read | TC | qa/cli/migrations.md |  |  |
| TC-migrations-absent-version-state | TC | qa/cli/migrations.md |  |  |
| TC-migrations-absent-version-no-writes | TC | qa/cli/migrations.md |  |  |
| TC-migrations-newer-recorded-refused | TC | qa/cli/migrations.md |  |  |
| TC-migrations-foreign-lineage-refused | TC | qa/cli/migrations.md |  |  |
| TC-migrations-noop-at-latest | TC | qa/cli/migrations.md |  |  |
| TC-migrations-noop-no-writes | TC | qa/cli/migrations.md |  |  |
| TC-migrations-pending-detection-single | TC | qa/cli/migrations.md |  |  |
| TC-migrations-pending-detection-multi | TC | qa/cli/migrations.md |  |  |
| TC-migrations-pending-detection-none | TC | qa/cli/migrations.md |  |  |
| TC-migrations-multi-order | TC | qa/cli/migrations.md |  |  |
| TC-migrations-ordered-pending-list | TC | qa/cli/migrations.md |  |  |
| TC-migrations-version-bump-success | TC | qa/cli/migrations.md |  |  |
| TC-migrations-dry-run-no-writes | TC | qa/cli/migrations.md |  |  |
| TC-migrations-dry-run-output-shape | TC | qa/cli/migrations.md |  |  |
| TC-migrations-dry-run-semantic-skipped | TC | qa/cli/migrations.md |  |  |
| TC-migrations-dry-run-matches-real-run | TC | qa/cli/migrations.md |  |  |
| TC-migrations-dry-run-file-list-exhaustive | TC | qa/cli/migrations.md |  |  |
| TC-migrations-rerun-is-noop | TC | qa/cli/migrations.md |  |  |
| TC-migrations-mechanical-idempotent | TC | qa/cli/migrations.md |  |  |
| TC-migrations-semantic-idempotent | TC | qa/cli/migrations.md |  |  |
| TC-migrations-non-breaking-no-file | TC | qa/cli/migrations.md |  |  |
| TC-migrations-one-file-per-version | TC | qa/cli/migrations.md |  |  |
| TC-migrations-file-required | TC | qa/cli/migrations.md |  |  |
| TC-migrations-no-auto-trigger | TC | qa/cli/migrations.md |  |  |
| TC-migrations-mechanical-runs | TC | qa/cli/migrations.md |  |  |
| TC-migrations-mechanical-absent-marker | TC | qa/cli/migrations.md |  |  |
| TC-migrations-semantic-runs | TC | qa/cli/migrations.md |  |  |
| TC-migrations-semantic-absent-marker | TC | qa/cli/migrations.md |  |  |
| TC-migrations-mechanical-before-semantic | TC | qa/cli/migrations.md |  |  |
| TC-migrations-atomic-bump-on-mechanical-fail | TC | qa/cli/migrations.md |  |  |
| TC-migrations-atomic-bump-on-semantic-fail | TC | qa/cli/migrations.md |  |  |
| TC-migrations-failure-report-names-migration | TC | qa/cli/migrations.md |  |  |
| TC-migrations-failure-report-names-block | TC | qa/cli/migrations.md |  |  |
| TC-migrations-failure-report-recovery-steps | TC | qa/cli/migrations.md |  |  |
| TC-migrations-partial-recoverable-state | TC | qa/cli/migrations.md |  |  |
| TC-migrations-resume-after-fix | TC | qa/cli/migrations.md |  |  |
| TC-migrations-no-skip-gaps | TC | qa/cli/migrations.md |  |  |
| TC-migrations-scope-default-enforced | TC | qa/cli/migrations.md |  |  |
| TC-migrations-scope-broader-declared | TC | qa/cli/migrations.md |  |  |
| TC-migrations-scope-semantic-context-confined | TC | qa/cli/migrations.md |  |  |
| TC-migrations-semantic-context-receives-files | TC | qa/cli/migrations.md |  |  |
| TC-migrations-untouched-files-unchanged | TC | qa/cli/migrations.md |  |  |
| TC-migrations-gate-blocks-missing-file | TC | qa/cli/migrations.md |  |  |
| TC-migrations-gate-passes-with-file | TC | qa/cli/migrations.md |  |  |
| TC-migrations-gate-docs-only | TC | qa/cli/migrations.md |  |  |
| TC-migrations-gate-nonframework | TC | qa/cli/migrations.md |  |  |
| TC-migrations-gate-trailer-override | TC | qa/cli/migrations.md |  |  |
| TC-migrations-self-migration-same-command | TC | qa/cli/migrations.md |  |  |
| TC-migrations-self-migration-advances-version | TC | qa/cli/migrations.md |  |  |
| TC-migrations-output-glyphs | TC | qa/cli/migrations.md |  |  |
| TC-migrations-determinism-two-runs | TC | qa/cli/migrations.md |  |  |
| TC-migrations-unknown-format-error | TC | qa/cli/migrations.md |  |  |
| TC-migrations-grep-friendly | TC | qa/cli/migrations.md |  |  |
| TC-migrations-nonbreaking-advance | TC | qa/cli/migrations.md |  |  |
| TC-migrations-missing-file-refused | TC | qa/cli/migrations.md |  |  |
| TC-migrations-update-happy | TC | qa/cli/migrations.md |  |  |
| TC-migrations-update-noop-current | TC | qa/cli/migrations.md |  |  |
| TC-migrations-update-nonbreaking-only | TC | qa/cli/migrations.md |  |  |
| TC-migrations-update-in-session-new-command | TC | qa/cli/migrations.md |  |  |
| TC-migrations-update-bump-failure-network | TC | qa/cli/migrations.md |  |  |
| TC-migrations-update-dry-run | TC | qa/cli/migrations.md |  |  |
| TC-migrations-update-self-host-refuses | TC | qa/cli/migrations.md |  |  |
| TC-migrations-update-symlink-prune | TC | qa/cli/migrations.md |  |  |
| FR-code-mapping-marker-presence | FR | product/code-mapping.md | engineering/cli/code-mapping.md, qa/cli/code-mapping.md | scripts/audit-traceability.sh:176 |
| FR-code-mapping-marker-multi | FR | product/code-mapping.md | engineering/cli/code-mapping.md, qa/cli/code-mapping.md |  |
| FR-code-mapping-marker-scope | FR | product/code-mapping.md | engineering/cli/code-mapping.md, qa/cli/code-mapping.md | scripts/audit-traceability.sh:463 |
| FR-code-mapping-marker-language | FR | product/code-mapping.md | engineering/cli/code-mapping.md, qa/cli/code-mapping.md |  |
| FR-code-mapping-marker-slug-reference | FR | product/code-mapping.md | engineering/cli/code-mapping.md, qa/cli/code-mapping.md |  |
| FR-code-mapping-marker-retirement-blocks | FR | product/code-mapping.md | engineering/cli/code-mapping.md, qa/cli/code-mapping.md | scripts/audit-traceability.sh:451 |
| FR-code-mapping-planned-paths | FR | product/code-mapping.md | engineering/cli/code-mapping.md, qa/cli/code-mapping.md | scripts/audit-traceability.sh:254 |
| FR-code-mapping-planned-paths-living | FR | product/code-mapping.md | engineering/cli/code-mapping.md, qa/cli/code-mapping.md | scripts/audit-traceability.sh:254 |
| FR-code-mapping-planned-paths-per-platform | FR | product/code-mapping.md | engineering/cli/code-mapping.md, qa/cli/code-mapping.md |  |
| FR-code-mapping-acknowledged-unimplemented | FR | product/code-mapping.md | engineering/cli/code-mapping.md, qa/cli/code-mapping.md |  |
| FR-code-mapping-audit-scan | FR | product/code-mapping.md | engineering/cli/code-mapping.md, qa/cli/code-mapping.md | scripts/audit-traceability.sh:137, scripts/audit-traceability.sh:176, scripts/init.sh:636 |
| FR-code-mapping-audit-validates-slug | FR | product/code-mapping.md | engineering/cli/code-mapping.md, qa/cli/code-mapping.md | scripts/audit-traceability.sh:451, scripts/audit-traceability.sh:66 |
| FR-code-mapping-audit-validates-path | FR | product/code-mapping.md | engineering/cli/code-mapping.md, qa/cli/code-mapping.md |  |
| FR-code-mapping-audit-coverage | FR | product/code-mapping.md | engineering/cli/code-mapping.md, qa/cli/code-mapping.md |  |
| FR-code-mapping-audit-coverage-blocks | FR | product/code-mapping.md | engineering/cli/code-mapping.md, qa/cli/code-mapping.md |  |
| FR-code-mapping-audit-coverage-grace | FR | product/code-mapping.md | engineering/cli/code-mapping.md, qa/cli/code-mapping.md |  |
| FR-code-mapping-audit-escape-hatch | FR | product/code-mapping.md | engineering/cli/code-mapping.md, qa/cli/code-mapping.md |  |
| FR-code-mapping-index-code-locations | FR | product/code-mapping.md | engineering/cli/code-mapping.md, qa/cli/code-mapping.md | scripts/audit-traceability.sh:319 |
| FR-code-mapping-index-populated | FR | product/code-mapping.md | engineering/cli/code-mapping.md, qa/cli/code-mapping.md | scripts/audit-traceability.sh:319 |
| FR-code-mapping-index-removes-stale | FR | product/code-mapping.md | engineering/cli/code-mapping.md, qa/cli/code-mapping.md |  |
| NFR-code-mapping-audit-speed | NFR | product/code-mapping.md | engineering/cli/code-mapping.md, qa/cli/code-mapping.md |  |
| NFR-code-mapping-precision | NFR | product/code-mapping.md | engineering/cli/code-mapping.md, qa/cli/code-mapping.md | scripts/audit-traceability.sh:172 |
| NFR-code-mapping-review-cost | NFR | product/code-mapping.md | engineering/cli/code-mapping.md, qa/cli/code-mapping.md |  |
| NFR-code-mapping-determinism | NFR | product/code-mapping.md | engineering/cli/code-mapping.md, qa/cli/code-mapping.md |  |
| AC-code-mapping-orphan-marker-rejected | AC | product/code-mapping.md | engineering/cli/code-mapping.md, qa/cli/code-mapping.md |  |
| AC-code-mapping-retirement-blocks | AC | product/code-mapping.md | engineering/cli/code-mapping.md, qa/cli/code-mapping.md |  |
| AC-code-mapping-stale-planned-path-rejected | AC | product/code-mapping.md | engineering/cli/code-mapping.md, qa/cli/code-mapping.md |  |
| AC-code-mapping-uncovered-warns | AC | product/code-mapping.md | engineering/cli/code-mapping.md, qa/cli/code-mapping.md |  |
| AC-code-mapping-uncovered-blocks | AC | product/code-mapping.md | engineering/cli/code-mapping.md, qa/cli/code-mapping.md |  |
| AC-code-mapping-acknowledged-unimplemented | AC | product/code-mapping.md | engineering/cli/code-mapping.md, qa/cli/code-mapping.md |  |
| AC-code-mapping-multi-slug-counted | AC | product/code-mapping.md | engineering/cli/code-mapping.md, qa/cli/code-mapping.md |  |
| AC-code-mapping-marker-scope-enforced | AC | product/code-mapping.md | engineering/cli/code-mapping.md, qa/cli/code-mapping.md | scripts/audit-traceability.sh:463 |
| AC-code-mapping-marker-syntax-per-type | AC | product/code-mapping.md | engineering/cli/code-mapping.md, qa/cli/code-mapping.md |  |
| AC-code-mapping-planned-paths-living | AC | product/code-mapping.md | engineering/cli/code-mapping.md, qa/cli/code-mapping.md |  |
| AC-code-mapping-index-reflects-markers | AC | product/code-mapping.md | engineering/cli/code-mapping.md, qa/cli/code-mapping.md |  |
| AC-code-mapping-index-drops-removed | AC | product/code-mapping.md | engineering/cli/code-mapping.md, qa/cli/code-mapping.md |  |
| AC-code-mapping-escape-hatch | AC | product/code-mapping.md | engineering/cli/code-mapping.md, qa/cli/code-mapping.md |  |
| AC-code-mapping-near-match-rejected | AC | product/code-mapping.md | engineering/cli/code-mapping.md, qa/cli/code-mapping.md |  |
| AC-code-mapping-audit-speed | AC | product/code-mapping.md | engineering/cli/code-mapping.md, qa/cli/code-mapping.md |  |
| AC-code-mapping-deterministic-output | AC | product/code-mapping.md | engineering/cli/code-mapping.md, qa/cli/code-mapping.md |  |
| TC-code-mapping-marker-matches | TC | qa/cli/code-mapping.md |  |  |
| TC-code-mapping-multi-slug | TC | qa/cli/code-mapping.md |  |  |
| TC-code-mapping-syntax-table | TC | qa/cli/code-mapping.md |  |  |
| TC-code-mapping-close-token-required | TC | qa/cli/code-mapping.md |  |  |
| TC-code-mapping-scan-finds-markers | TC | qa/cli/code-mapping.md |  |  |
| TC-code-mapping-near-match-ignored | TC | qa/cli/code-mapping.md |  |  |
| TC-code-mapping-nested-comment-known-limit | TC | qa/cli/code-mapping.md |  |  |
| TC-code-mapping-single-line-marker | TC | qa/cli/code-mapping.md |  |  |
| TC-code-mapping-orphan-blocks | TC | qa/cli/code-mapping.md |  |  |
| TC-code-mapping-retirement-blocks | TC | qa/cli/code-mapping.md |  |  |
| TC-code-mapping-scope-flagged | TC | qa/cli/code-mapping.md |  |  |
| TC-code-mapping-code-map-parses | TC | qa/cli/code-mapping.md |  |  |
| TC-code-mapping-code-map-malformed | TC | qa/cli/code-mapping.md |  |  |
| TC-code-mapping-stale-path-blocks | TC | qa/cli/code-mapping.md |  |  |
| TC-code-mapping-unimplemented-exempt | TC | qa/cli/code-mapping.md |  |  |
| TC-code-mapping-coverage-reported | TC | qa/cli/code-mapping.md |  |  |
| TC-code-mapping-grace-warns | TC | qa/cli/code-mapping.md |  |  |
| TC-code-mapping-grace-expires | TC | qa/cli/code-mapping.md |  |  |
| TC-code-mapping-shallow-clone-warns | TC | qa/cli/code-mapping.md |  |  |
| TC-code-mapping-index-populated | TC | qa/cli/code-mapping.md |  |  |
| TC-code-mapping-index-auto-stage | TC | qa/cli/code-mapping.md |  |  |
| TC-code-mapping-index-check-mode-fails | TC | qa/cli/code-mapping.md |  |  |
| TC-code-mapping-index-removes-stale | TC | qa/cli/code-mapping.md |  |  |
| TC-code-mapping-per-platform-index | TC | qa/cli/code-mapping.md |  |  |
| TC-code-mapping-override-demotes | TC | qa/cli/code-mapping.md |  |  |
| TC-code-mapping-override-reports-suppressed | TC | qa/cli/code-mapping.md |  |  |
| TC-code-mapping-audit-under-2s | TC | qa/cli/code-mapping.md |  |  |
| TC-code-mapping-deterministic-two-runs | TC | qa/cli/code-mapping.md |  |  |
| TC-code-mapping-exclusion-respected | TC | qa/cli/code-mapping.md |  |  |
| TC-code-mapping-selfhost-includes | TC | qa/cli/code-mapping.md |  |  |
| TC-code-mapping-consumer-excludes-pdeq | TC | qa/cli/code-mapping.md |  |  |
| TC-code-mapping-scope-on-function-passes | TC | qa/cli/code-mapping.md |  |  |
| TC-code-mapping-grep-fallback-correctness | TC | qa/cli/code-mapping.md |  |  |
| TC-code-mapping-skip-index-rewrite | TC | qa/cli/code-mapping.md |  |  |
| TC-code-mapping-grace-default-5 | TC | qa/cli/code-mapping.md |  |  |
| TC-code-mapping-implemented-status-no-marker | TC | qa/cli/code-mapping.md |  |  |
| FR-visualize-command | FR | product/visualize.md |  | pdeq-rules/commands/pdeq-visualize.md:1 |
| FR-visualize-input-design-spec | FR | product/visualize.md |  | pdeq-rules/commands/pdeq-visualize.md:1 |
| FR-visualize-single-file | FR | product/visualize.md |  | pdeq-rules/commands/pdeq-visualize.md:1 |
| FR-visualize-browser-viewable | FR | product/visualize.md |  | pdeq-rules/commands/pdeq-visualize.md:1 |
| FR-visualize-auto-open | FR | product/visualize.md |  | pdeq-rules/commands/pdeq-visualize.md:1 |
| FR-visualize-output-path | FR | product/visualize.md |  | pdeq-rules/commands/pdeq-visualize.md:1 |
| FR-visualize-gitignored | FR | product/visualize.md |  | pdeq-rules/commands/pdeq-visualize.md:1 |
| FR-visualize-regenerable | FR | product/visualize.md |  | pdeq-rules/commands/pdeq-visualize.md:1 |
| FR-visualize-single-mode | FR | product/visualize.md |  | pdeq-rules/commands/pdeq-visualize.md:1 |
| FR-visualize-platform-scope | FR | product/visualize.md |  | pdeq-rules/commands/pdeq-visualize.md:1 |
| AC-visualize-renders | AC | product/visualize.md |  |  |
| AC-visualize-gitignored | AC | product/visualize.md |  |  |
| AC-visualize-self-contained | AC | product/visualize.md |  |  |
| AC-visualize-missing-spec | AC | product/visualize.md |  |  |
| AC-visualize-rerun-overwrites | AC | product/visualize.md |  |  |
| FR-cli-naming-prefix | FR | product/cli-conventions.md | migrations/0.3.0.md | migrations/0.3.0.md:8 |
| FR-cli-naming-rename-existing | FR | product/cli-conventions.md | migrations/0.3.0.md | migrations/0.3.0.md:8 |
| FR-cli-naming-discoverable | FR | product/cli-conventions.md |  |  |
| FR-cli-naming-no-collision | FR | product/cli-conventions.md |  |  |
| AC-cli-naming-listing | AC | product/cli-conventions.md |  |  |
| AC-cli-naming-no-bare-name | AC | product/cli-conventions.md |  |  |
| AC-cli-naming-migration-carries | AC | product/cli-conventions.md |  |  |
| FR-harness-agnostic-config | FR | product/harness-agnostic.md | engineering/cli/harness-agnostic.md, qa/cli/harness-agnostic.md | scripts/init.sh:132, scripts/init.sh:601 |
| FR-harness-agnostic-v1-harness-set | FR | product/harness-agnostic.md | engineering/cli/harness-agnostic.md, qa/cli/harness-agnostic.md | scripts/init.sh:110 |
| FR-harness-agnostic-multiple-per-install | FR | product/harness-agnostic.md | engineering/cli/harness-agnostic.md, qa/cli/harness-agnostic.md |  |
| FR-harness-agnostic-unknown-rejected | FR | product/harness-agnostic.md | engineering/cli/harness-agnostic.md, qa/cli/harness-agnostic.md | scripts/init.sh:111, scripts/init.sh:170 |
| FR-harness-agnostic-canonical-agents-file | FR | product/harness-agnostic.md | engineering/cli/harness-agnostic.md, qa/cli/harness-agnostic.md |  |
| FR-harness-agnostic-content-portable | FR | product/harness-agnostic.md | engineering/cli/harness-agnostic.md, qa/cli/harness-agnostic.md |  |
| FR-harness-agnostic-no-import-in-canonical | FR | product/harness-agnostic.md | engineering/cli/harness-agnostic.md, qa/cli/harness-agnostic.md |  |
| FR-harness-agnostic-per-harness-install | FR | product/harness-agnostic.md | engineering/cli/harness-agnostic.md, qa/cli/harness-agnostic.md | scripts/init.sh:184, scripts/init.sh:439, scripts/init.sh:449 |
| FR-harness-agnostic-claude-import | FR | product/harness-agnostic.md | engineering/cli/harness-agnostic.md, qa/cli/harness-agnostic.md | CLAUDE.md:1, scripts/init.sh:185 |
| FR-harness-agnostic-symlink-include | FR | product/harness-agnostic.md | engineering/cli/harness-agnostic.md, qa/cli/harness-agnostic.md | scripts/init.sh:186 |
| FR-harness-agnostic-commands-per-harness | FR | product/harness-agnostic.md | engineering/cli/harness-agnostic.md, qa/cli/harness-agnostic.md | scripts/init.sh:217, scripts/init.sh:499 |
| FR-harness-agnostic-commands-source-path | FR | product/harness-agnostic.md | engineering/cli/harness-agnostic.md, qa/cli/harness-agnostic.md |  |
| FR-harness-agnostic-bootstrap-inline | FR | product/harness-agnostic.md | engineering/cli/harness-agnostic.md, qa/cli/harness-agnostic.md | pdeq-rules/commands/pdeq-bootstrap.md:3 |
| FR-harness-agnostic-no-subagent-files | FR | product/harness-agnostic.md | engineering/cli/harness-agnostic.md, qa/cli/harness-agnostic.md | pdeq-rules/commands/pdeq-bootstrap.md:3 |
| FR-harness-agnostic-skill-claude-only | FR | product/harness-agnostic.md | engineering/cli/harness-agnostic.md, qa/cli/harness-agnostic.md |  |
| FR-harness-agnostic-migration | FR | product/harness-agnostic.md | engineering/cli/harness-agnostic.md, qa/cli/harness-agnostic.md | migrations/0.4.0.md:8 |
| FR-harness-agnostic-hard-cutover | FR | product/harness-agnostic.md | engineering/cli/harness-agnostic.md, qa/cli/harness-agnostic.md | migrations/0.4.0.md:8 |
| FR-harness-agnostic-migration-default-harness | FR | product/harness-agnostic.md | engineering/cli/harness-agnostic.md, qa/cli/harness-agnostic.md | migrations/0.4.0.md:8 |
| FR-harness-agnostic-migration-idempotent | FR | product/harness-agnostic.md | engineering/cli/harness-agnostic.md, qa/cli/harness-agnostic.md | migrations/0.4.0.md:8 |
| FR-harness-agnostic-migration-removes-subagents | FR | product/harness-agnostic.md | engineering/cli/harness-agnostic.md, qa/cli/harness-agnostic.md | migrations/0.4.0.md:8 |
| FR-harness-agnostic-harness-change-reinstall | FR | product/harness-agnostic.md | engineering/cli/harness-agnostic.md, qa/cli/harness-agnostic.md |  |
| FR-harness-agnostic-removed-harness-cleaned | FR | product/harness-agnostic.md | engineering/cli/harness-agnostic.md, qa/cli/harness-agnostic.md | scripts/init.sh:252, scripts/init.sh:505 |
| NFR-harness-agnostic-no-new-deps | NFR | product/harness-agnostic.md | engineering/cli/harness-agnostic.md, qa/cli/harness-agnostic.md |  |
| NFR-harness-agnostic-installer-reporting | NFR | product/harness-agnostic.md | engineering/cli/harness-agnostic.md, qa/cli/harness-agnostic.md | scripts/init.sh:187 |
| NFR-harness-agnostic-symlink-portability | NFR | product/harness-agnostic.md | engineering/cli/harness-agnostic.md, qa/cli/harness-agnostic.md | scripts/init.sh:218 |
| NFR-harness-agnostic-docs-multi-harness | NFR | product/harness-agnostic.md | engineering/cli/harness-agnostic.md |  |
| AC-harness-agnostic-default-claude | AC | product/harness-agnostic.md | engineering/cli/harness-agnostic.md, qa/cli/harness-agnostic.md |  |
| AC-harness-agnostic-codex-install | AC | product/harness-agnostic.md | engineering/cli/harness-agnostic.md, qa/cli/harness-agnostic.md |  |
| AC-harness-agnostic-pi-install | AC | product/harness-agnostic.md | engineering/cli/harness-agnostic.md, qa/cli/harness-agnostic.md |  |
| AC-harness-agnostic-multi-install | AC | product/harness-agnostic.md | engineering/cli/harness-agnostic.md, qa/cli/harness-agnostic.md |  |
| AC-harness-agnostic-unknown-init | AC | product/harness-agnostic.md | engineering/cli/harness-agnostic.md, qa/cli/harness-agnostic.md |  |
| AC-harness-agnostic-unknown-schema | AC | product/harness-agnostic.md | engineering/cli/harness-agnostic.md, qa/cli/harness-agnostic.md |  |
| AC-harness-agnostic-codex-no-commands | AC | product/harness-agnostic.md | engineering/cli/harness-agnostic.md, qa/cli/harness-agnostic.md |  |
| AC-harness-agnostic-pi-no-commands | AC | product/harness-agnostic.md | engineering/cli/harness-agnostic.md, qa/cli/harness-agnostic.md |  |
| AC-harness-agnostic-bootstrap-no-subagent | AC | product/harness-agnostic.md | engineering/cli/harness-agnostic.md, qa/cli/harness-agnostic.md |  |
| AC-harness-agnostic-migration-end-to-end | AC | product/harness-agnostic.md | engineering/cli/harness-agnostic.md, qa/cli/harness-agnostic.md |  |
| AC-harness-agnostic-migration-idempotent | AC | product/harness-agnostic.md | engineering/cli/harness-agnostic.md, qa/cli/harness-agnostic.md |  |
| AC-harness-agnostic-migration-warns-customized | AC | product/harness-agnostic.md | engineering/cli/harness-agnostic.md, qa/cli/harness-agnostic.md |  |
| AC-harness-agnostic-no-new-deps | AC | product/harness-agnostic.md | engineering/cli/harness-agnostic.md, qa/cli/harness-agnostic.md |  |
| AC-harness-agnostic-remove-harness | AC | product/harness-agnostic.md | engineering/cli/harness-agnostic.md, qa/cli/harness-agnostic.md |  |
| AC-harness-agnostic-installer-output | AC | product/harness-agnostic.md | engineering/cli/harness-agnostic.md, qa/cli/harness-agnostic.md |  |
| AC-harness-agnostic-self-host-migrates | AC | product/harness-agnostic.md | engineering/cli/harness-agnostic.md, qa/cli/harness-agnostic.md |  |
| TC-harness-agnostic-default-claude-resolved | TC | qa/cli/harness-agnostic.md |  |  |
| TC-harness-agnostic-codex-install-files | TC | qa/cli/harness-agnostic.md |  |  |
| TC-harness-agnostic-codex-symlink-content | TC | qa/cli/harness-agnostic.md |  |  |
| TC-harness-agnostic-pi-install-files | TC | qa/cli/harness-agnostic.md |  |  |
| TC-harness-agnostic-pi-symlink-content | TC | qa/cli/harness-agnostic.md |  |  |
| TC-harness-agnostic-multi-install-both-files | TC | qa/cli/harness-agnostic.md |  |  |
| TC-harness-agnostic-multi-install-canonical-edit-propagates | TC | qa/cli/harness-agnostic.md |  |  |
| TC-harness-agnostic-init-unknown-rejected | TC | qa/cli/harness-agnostic.md |  |  |
| TC-harness-agnostic-schema-unknown-rejected | TC | qa/cli/harness-agnostic.md |  |  |
| TC-harness-agnostic-codex-no-commands-dir | TC | qa/cli/harness-agnostic.md |  |  |
| TC-harness-agnostic-pi-no-commands-dir | TC | qa/cli/harness-agnostic.md |  |  |
| TC-harness-agnostic-bootstrap-no-subagent-files | TC | qa/cli/harness-agnostic.md |  |  |
| TC-harness-agnostic-bootstrap-prompts-inlined | TC | qa/cli/harness-agnostic.md |  |  |
| TC-harness-agnostic-migrate-cutover | TC | qa/cli/harness-agnostic.md |  |  |
| TC-harness-agnostic-migrate-bumps-version | TC | qa/cli/harness-agnostic.md |  |  |
| TC-harness-agnostic-migrate-rerun-noop | TC | qa/cli/harness-agnostic.md |  |  |
| TC-harness-agnostic-migrate-customized-subagent-warn | TC | qa/cli/harness-agnostic.md |  |  |
| TC-harness-agnostic-install-no-extra-toolchain | TC | qa/cli/harness-agnostic.md |  |  |
| TC-harness-agnostic-remove-harness-cleanup | TC | qa/cli/harness-agnostic.md |  |  |
| TC-harness-agnostic-remove-harness-preserves-authored | TC | qa/cli/harness-agnostic.md |  |  |
| TC-harness-agnostic-installer-names-harness-per-line | TC | qa/cli/harness-agnostic.md |  |  |
| TC-harness-agnostic-self-host-migrate-clean | TC | qa/cli/harness-agnostic.md |  |  |
