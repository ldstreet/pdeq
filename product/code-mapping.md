# Requirement ↔ Code Mapping

## Overview

Pdeq specs define *what* a project must do in requirement slugs (`FR-`, `NFR-`, `AC-`). Today, the traceability index maps those slugs to spec files across product, design, engineering, and QA — but not to the code that actually realizes them. When an agent or human reviewer asks "where is this requirement implemented?" the only answer is grep-and-guess.

This feature closes that gap by formalizing three reinforcing layers: a planned code location recorded in the engineering spec before implementation, an inline marker placed in the code itself at the point of implementation, and a traceability audit that reconciles the two against the product spec. Each layer is redundant enough to catch the others' drift. The goal is that at any moment, given any slug, an agent can locate every piece of code fulfilling it in a single lookup — and can trust the result is current.

## User Stories

- As an **implementing agent**, I want to locate the code that realizes a requirement without guessing so that I can extend or debug it without reintroducing bugs.
- As a **reviewing agent**, I want to see which requirement every code block claims to fulfill so that I can audit whether a change actually matches its upstream spec.
- As a **pdeq maintainer**, I want the traceability index to surface code locations alongside spec references so that drift between a requirement and its implementation becomes mechanically visible.
- As an **engineering spec author**, I want to record intended code locations alongside a requirement so that the plan is captured before implementation starts, not reverse-engineered afterward.
- As a **commit-time gate**, I want commits with markers that cite nonexistent slugs, or plans that reference missing files, to be rejected so that the spec-to-code link cannot silently rot.

## Requirements

### Inline Markers

Code claims the requirements it realizes through a short, inline marker placed at the implementation site.

- **Marker presence** `FR-code-mapping-marker-presence`: Every functional requirement (`FR-`) realized in code carries at least one inline marker citing its slug at the implementation site. Non-functional requirements and acceptance criteria may carry markers where a specific code block realizes them, but are not required to.
- **Multi-slug markers** `FR-code-mapping-marker-multi`: A single marker may cite more than one slug, allowing a single block to claim it realizes multiple requirements at once.
- **Scoped placement** `FR-code-mapping-marker-scope`: A marker is placed on or immediately above the smallest enclosing named unit (function, method, or block) that implements the requirement, not at file-top level. "File-top level" means the marker appears before every named unit in the file — its position is judged structurally, against where the file's named units begin, not against an absolute line count.
- **Language-appropriate syntax** `FR-code-mapping-marker-language`: A marker uses comment syntax appropriate to the file type it appears in, and its slug citation appears on the same source line as the opening marker token so the marker can be located by a single-line scan.
- **Stable slug reference** `FR-code-mapping-marker-slug-reference`: A marker cites an existing slug defined in a current product spec. A marker that cites a slug which is not defined (typo, yet-to-be-added, or previously retired) is invalid regardless of whether the marker was just added or was already present in the tree.
- **Retirement forces cleanup in same change** `FR-code-mapping-marker-retirement-blocks`: When a product spec change removes a slug that still has markers in the code, the audit rejects the commit. Slug removal and marker cleanup must land together.

### Planned Code Locations

The engineering spec captures intended code locations per slug before implementation begins.

- **Code Map in engineering spec** `FR-code-mapping-planned-paths`: Each platform's engineering spec includes a section that lists planned code locations for every functional requirement it covers. Locations may be left empty before code exists.
- **Living Code Map** `FR-code-mapping-planned-paths-living`: The Code Map is updated as files move, split, or merge during implementation, so it always reflects the current realization — not the initial guess.
- **Cross-platform scoping** `FR-code-mapping-planned-paths-per-platform`: The Code Map belongs to the platform-specific engineering spec. Requirements realized by multiple platforms appear in each platform's Code Map independently, and the traceability index surfaces code locations per platform rather than merging them.
- **Deliberately unimplemented slugs** `FR-code-mapping-acknowledged-unimplemented`: A requirement that is intentionally not-yet-implemented (e.g., future-scope that still lives in the current product spec) can be acknowledged as such in the engineering spec's Code Map. An acknowledged slug does not count as uncovered and does not trigger coverage warnings or blocks.

### Traceability Audit

The existing traceability audit is extended to reconcile markers, planned paths, and product-spec slugs.

- **Marker discovery** `FR-code-mapping-audit-scan`: The audit scans the project for markers, extracts the cited slugs and their file locations, and builds a mapping from slug to every code location that claims it.
- **Slug validation** `FR-code-mapping-audit-validates-slug`: The audit rejects any marker that cites a slug not defined in a current product spec.
- **Planned-path validation** `FR-code-mapping-audit-validates-path`: The audit rejects any planned path in an engineering spec Code Map that points to a file which does not exist.
- **Coverage report** `FR-code-mapping-audit-coverage`: For every functional requirement defined in a product spec, the audit determines whether at least one marker references it and surfaces the result in its report.
- **Coverage blocks commits** `FR-code-mapping-audit-coverage-blocks`: A functional requirement defined in a product spec that has no inline marker in code and is not acknowledged as unimplemented in the engineering spec is treated as an audit failure, subject to the grace period below.
- **Graceful coverage ramp** `FR-code-mapping-audit-coverage-grace`: A newly-added functional requirement without any marker is reported as a warning during a defined grace period rather than blocking; once the grace period elapses, the same condition blocks commits per the coverage-blocks behavior above. The grace period's duration is defined by the engineering spec.
- **Escape hatch** `FR-code-mapping-audit-escape-hatch`: The audit honors the same override mechanism used by other pdeq audits, so a consumer can land a commit that would otherwise fail. When the override is invoked, the audit's report records that the override was used and names the conditions it suppressed.

### Traceability Index

The index surfaces code alongside spec references, in the same place all other slug references live.

- **Code locations in index** `FR-code-mapping-index-code-locations`: The traceability index lists code locations for each slug alongside its existing spec references.
- **Automatic population** `FR-code-mapping-index-populated`: Running the audit populates or updates the code-location entries for every slug with at least one marker. Index entries for code never need manual editing.
- **Stale-location removal** `FR-code-mapping-index-removes-stale`: When a marker disappears from the code, the corresponding code location is removed from the index on the next audit run.

### Non-Functional Requirements

- **Audit speed** `NFR-code-mapping-audit-speed`: The combined traceability audit, including the marker scan, completes in under two seconds on the pdeq repository.
- **Precision on near-matches** `NFR-code-mapping-precision`: The marker scan counts only tokens that form a complete, well-formed slug per the project's slug grammar. Partial matches, prose that merely mentions a slug prefix, and text nested inside surrounding block comments that are themselves commented out produce zero false positives.
- **Reviewer overhead** `NFR-code-mapping-review-cost`: Adding a marker adds at most a single line of comment to the implementation site. Markers never require wrapping, relocating, or restructuring the code they annotate.
- **Determinism** `NFR-code-mapping-determinism`: Two runs of the audit on the same commit produce identical output.

## Acceptance Criteria

These cover the testable, observable outcomes QA verifies directly.

- [ ] **Orphan marker rejected** `AC-code-mapping-orphan-marker-rejected`: A commit is rejected by the audit whenever any marker — whether newly introduced in the commit or already present in the tree — cites a slug that is not defined in any current product spec.
- [ ] **Slug retirement blocks stale markers** `AC-code-mapping-retirement-blocks`: A commit that removes a slug from a product spec while one or more markers in the tree still cite that slug is rejected by the audit, regardless of grace-period status.
- [ ] **Stale planned path rejected** `AC-code-mapping-stale-planned-path-rejected`: A commit whose engineering spec Code Map references a file that does not exist is rejected by the audit.
- [ ] **Uncovered slug warns within grace** `AC-code-mapping-uncovered-warns`: A newly-defined functional requirement with no marker in code produces a warning but does not block commits during the grace period.
- [ ] **Uncovered slug blocks after grace** `AC-code-mapping-uncovered-blocks`: A functional requirement that remains uncovered past the grace period blocks commits until either a marker is added or the slug is acknowledged as unimplemented in the engineering spec's Code Map.
- [ ] **Acknowledged unimplemented does not block** `AC-code-mapping-acknowledged-unimplemented`: A functional requirement marked as unimplemented in the engineering spec's Code Map produces no coverage warning or block, regardless of grace-period status.
- [ ] **Multi-slug marker counted for all** `AC-code-mapping-multi-slug-counted`: A single marker citing multiple slugs counts toward coverage for every slug it cites.
- [ ] **Marker at file-top rejected** `AC-code-mapping-marker-scope-enforced`: A marker is flagged by the audit and does not count toward coverage when both conditions hold: (a) the file contains at least one named unit capable of scoping the claim, and (b) the marker appears before that unit and is not immediately above it. A marker that sits inside the body of a named unit, or on the line immediately above a named unit, is not flagged regardless of its absolute line number in the file.
- [ ] **Marker syntax matches file type** `AC-code-mapping-marker-syntax-per-type`: A slug citation that is not enclosed in a comment of the form appropriate to its file type is ignored by the marker scan (it is neither counted as a marker nor reported as an orphan).
- [ ] **Living Code Map after file move** `AC-code-mapping-planned-paths-living`: After a file listed in a Code Map is moved or renamed, the audit passes only once the Code Map has been updated to reference the new location.
- [ ] **Index reflects markers** `AC-code-mapping-index-reflects-markers`: After running the audit, the traceability index lists every code location where a marker exists for the corresponding slug.
- [ ] **Index drops removed markers** `AC-code-mapping-index-drops-removed`: When a marker is removed from the code, the corresponding code location disappears from the index on the next audit run.
- [ ] **Escape hatch honored** `AC-code-mapping-escape-hatch`: A commit that would otherwise fail the audit can be landed by the documented override mechanism, and the audit report names which conditions the override suppressed.
- [ ] **Near-match rejected** `AC-code-mapping-near-match-rejected`: Text that mentions a slug prefix but does not form a complete, well-formed slug is ignored by the marker scan and is neither counted as a marker nor reported as an orphan.
- [ ] **Audit meets speed target** `AC-code-mapping-audit-speed`: Running the traceability audit on the pdeq repository completes in under two seconds, matching the NFR threshold without qualification.
- [ ] **Deterministic output** `AC-code-mapping-deterministic-output`: Two consecutive audit runs on the same commit produce byte-identical reports and byte-identical index updates.

## Open Questions

- **Grace period duration.** A newly-added functional requirement should not immediately block commits — authoring the spec and writing the code usually span separate commits. Engineering picks the concrete threshold (expected to be a small commit count measured against the product spec's git history) and documents rationale. The product spec only requires that a threshold exist.
- **Bootstrap integration.** When `/bootstrap` generates specs from an existing codebase, should it simultaneously emit markers into the analyzed code? Likely yes, but defer scoping to a follow-up — this first pass covers only new work.

## Dependencies

- **Existing traceability audit:** the marker scan and index-code-column maintenance are extensions of the existing audit pipeline, not a parallel tool. The exact script name is an engineering concern.
- **Drift detection convention:** downstream specs (including engineering Code Map updates) continue to stamp `product-hash` and `product-slugs` per the established convention. A Code Map change does not require re-stamping on its own; a product-spec change does.
- **Audit override mechanism:** this feature reuses the same override the audit already honors rather than introducing a new one. The exact mechanism (environment variable, commit trailer, or other) is an engineering concern.
- **Hook installation (PDEQ-fdaiacem):** the audit is only effective when wired into the consumer project's git-hook chain at install time. Without hook installation the code-mapping feature is dormant. This feature's adoption is therefore gated on the expanded hook-install task landing first.
- **Glossary:** introduces the terms *Inline marker*, *Code Map*, *Traceability audit*, and *Orphan marker* — see `glossary.md`.
