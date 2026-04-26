# Visualize

## Overview

Design specs in pdeq are markdown — fast to write, easy to review, but invisible until engineering builds the real thing. That gap is expensive: a misread layout, a missed interaction, an unclear empty state can survive design review only to surface during implementation, where the cost of changing course is high.

The visualize feature gives a consumer a cheap, throwaway preview of a design spec before any production code exists. The user runs a single command against a design spec and gets a self-contained HTML rendering they can open in a browser, click through, and react to. The artifact is intentionally low-fidelity and disposable — not a deliverable, not committed, not maintained. Its job is to surface "this layout doesn't read the way I thought" in seconds, not to ship.

## User Stories

- As a **designer**, I want to render a design spec to a viewable artifact so that I can review my own work in context, not just as prose.
- As a **product reviewer**, I want to click through a feature mockup before engineering starts so that I can catch missed flows while changes are still cheap.
- As an **engineering reviewer**, I want a visual reference alongside the design spec so that I can ask layout questions before scoping the build.

## Requirements

### Core Behavior

The user invokes a single command targeting a design spec and gets a viewable artifact in return.

- **Slash command** `FR-visualize-command`: A `/visualize` slash command renders a design spec to a viewable artifact. The command accepts a feature name and resolves the corresponding design spec under the consumer's specs root.
- **Design spec as input** `FR-visualize-input-design-spec`: The command reads a design spec markdown file as its sole input. It does not read product, engineering, or QA specs to produce the artifact.
- **Single-file output** `FR-visualize-single-file`: The rendered artifact is a single self-contained HTML file. Opening that one file in a browser must be sufficient to view the result. No build step, no external bundle, no required server.
- **Browser-viewable** `FR-visualize-browser-viewable`: The artifact opens correctly in a modern desktop browser via the file system, with no installation or local server required from the user.
- **Auto-open** `FR-visualize-auto-open`: After generation, the command opens the rendered artifact in the user's default browser using the platform's standard open mechanism.

### Output Location

The artifact has a predictable location and is treated as disposable.

- **Output path** `FR-visualize-output-path`: Rendered artifacts are written under `.pdeq/viz/` at the consumer's repo root, named after the feature.
- **Gitignored** `FR-visualize-gitignored`: The `.pdeq/viz/` directory is ignored by git. Rendered artifacts are never committed.
- **Regenerable** `FR-visualize-regenerable`: Re-running the command on the same feature overwrites the previous artifact. There is no version history, no diff, no migration path between renders.

### Fidelity

A single mode covers the common case. Fidelity is chosen by the rendering process based on the design spec content, not by the user.

- **Single mode** `FR-visualize-single-mode`: The command takes no fidelity flag. The rendering process produces one output per design spec, choosing layout density and styling based on what the design spec describes.

### Multi-Platform

When a project targets multiple platforms, each platform's design spec is visualized independently.

- **Platform scoping** `FR-visualize-platform-scope`: The command resolves the design spec under the platform requested. When the consumer's project defines multiple platforms, the command targets one platform per invocation.

## Non-Goals

The following are deliberately out of scope. They are listed here so future requests against this spec land against an explicit baseline.

- **No drift detection.** The visualize artifact carries no design-hash, no slug inventory, and is not audited by the traceability hook. Re-rendering after a design change is the user's responsibility.
- **No mode flag.** There is no wireframe-versus-prototype selector and no fidelity tier. A second mode may be added later but is not part of this spec.
- **No QA coverage.** The visualize artifact is not test-targeted. No QA test plan is authored for the rendered output.
- **No design spec for the command.** `/visualize` is a CLI tool with no UI surface. No design spec is authored for the command itself.

## Acceptance Criteria

- [ ] **Renders an existing design spec** `AC-visualize-renders`: Invoking `/visualize <feature>` against a design spec that exists writes a single HTML file under `.pdeq/viz/` and opens it in the default browser.
- [ ] **Output gitignored** `AC-visualize-gitignored`: Files written to `.pdeq/viz/` do not appear in `git status` after a fresh run.
- [ ] **Self-contained artifact** `AC-visualize-self-contained`: The generated HTML file opens and renders correctly when double-clicked from the file system, with no local server running.
- [ ] **Missing design spec reported** `AC-visualize-missing-spec`: Invoking the command against a feature with no design spec reports the missing path and exits without writing an artifact.
- [ ] **Re-run overwrites** `AC-visualize-rerun-overwrites`: Running the command twice in a row produces a single artifact at the expected path with content reflecting the latest render.

## Open Questions

- **Multi-screen design specs:** When a design spec describes several screens, should the artifact embed all screens in a single HTML page with in-page navigation, or split into multiple files? Engineering decision — both satisfy `FR-visualize-single-file` if the navigation is embedded.

## Dependencies

- **Design specs (`design/<platform>/<feature>.md`):** the command's only input.
- **Consumer's repo root:** writes `.pdeq/viz/` and depends on the consumer's `.gitignore` to mask it.
