# Roadmap

This folder holds **forward-looking notes** for features — fast follows, V2 ideas, future directions — that are **not yet scoped** for implementation.

Roadmap entries are intentionally lightweight. They are not specs. Their job is to park ideas so product/design/engineering/QA specs stay focused on what exists today, and so future `/pdeq-kickoff` runs have a starting point.

## What Goes Here

- Fast follows for features currently being built.
- V2 / V3 / "someday" ideas for existing features.
- Cross-cutting vision that spans multiple features (in `_overview.md`).

## What Does NOT Go Here

- Requirements that are actively being built — those belong in `../product/<feature>.md`.
- Design mockups, architecture plans, or test cases — those belong in their respective folders once scoped.
- Bug fixes or small corrections — those update the existing spec directly.

## File Layout

- `<feature>.md` — one file per feature. Use the same filename as the product spec it extends (or will eventually become).
- `_overview.md` — optional, for multi-feature or cross-cutting vision.

## File Structure

```markdown
# [Feature Name] — Roadmap

Short prose intro. Where is this feature headed? What's the longer-term vision?

See current state in [../product/[feature].md](../product/[feature].md).

## Fast Follow

Ideas queued up for immediately after the current scope ships.

- **[Readable Label]** — one-line description. Brief rationale if non-obvious.
- **[Readable Label]** — ...

## V2

Larger additions or reshapes that require their own kickoff.

- **[Readable Label]** — ...

## Later

Speculative / aspirational. May or may not happen.

- **[Readable Label]** — ...
```

Horizon sections (**Fast Follow**, **V2**, **Later**) are a suggestion — use whatever names make sense for the feature. Could also be **V1 → V2 → V3**, **Phase 1 → Phase 2**, etc.

## Rules

- **No slugs.** `FR-`, `NFR-`, `AC-`, `TC-` prefixes never appear in roadmap files. Slugs are minted only when an idea graduates into `../product/`.
- **No lane discipline.** Roadmap entries can hand-wave across product/design/engineering/QA concerns. Detail comes later at kickoff.
- **Not tracked in `../index.md`.** Roadmap is not authoritative.
- **Not audited by the pre-commit traceability hook.**
- **Not platform-scoped at the folder level.** If an idea is platform-specific, mention platform inline. Do not create `roadmap/<platform>/` subfolders.
- **Keep entries short.** One or two bullets per idea. If an idea needs a page of detail, it's ready for `/pdeq-kickoff`.

## Graduation Flow

When a roadmap item is ready for implementation:

1. Run `/pdeq-kickoff` on that item. The kickoff flow reads the roadmap entry for context, then creates a proper product spec (with slugs), design spec, engineering spec, and QA test plan.
2. Remove the graduated item from `<feature>.md`. Delete the file if empty.

## Path Resolution

At the start of each session, check for a `pdeq.json` config file:

1. Look in `../pdeq.json` (parent of this `roadmap/` folder).
2. If not found, check `../../pdeq.json`.

If `pdeq.json` is found, apply:

- **`specsRoot`**: Directory containing `product/`, `design/`, `engineering/`, `qa/`, `roadmap/`. Cross-folder references (e.g., `../product/<feature>.md`) are relative to `specsRoot`.
- **`nested.label`**: If present, you are working on the `{label}` component. Scope roadmap entries to this component.

If `pdeq.json` is absent, assume defaults: sibling folders at `../`.
