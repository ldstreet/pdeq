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
