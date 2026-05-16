<!-- Implements: FR-visualize-command, FR-visualize-input-design-spec, FR-visualize-single-file, FR-visualize-browser-viewable, FR-visualize-auto-open, FR-visualize-output-path, FR-visualize-gitignored, FR-visualize-regenerable, FR-visualize-single-mode, FR-visualize-platform-scope -->
# Visualize: $ARGUMENTS

Render a design spec to a self-contained HTML artifact and open it in the user's browser. This is a cheap throwaway preview — disposable, gitignored, never committed.

`$ARGUMENTS` is one of:

| Form | Meaning |
|---|---|
| `<feature>` | Resolve `design/<platform>/<feature>.md` using the project's default platform from `pdeq.json`. |
| `<feature> --platform <id>` | Render against the named platform's design spec. |

If `$ARGUMENTS` is empty, print usage and exit. If the resolved design spec does not exist, report the missing path and exit without writing anything.

---

## Step 1 — Resolve paths

Read `pdeq.json` from the repo root.

- `specsRoot` — root for `design/`, `product/`, etc. Default: `.`.
- `platforms` — list of platform IDs.

Resolve the input path: `<specsRoot>/design/<platform>/<feature>.md`.

If `--platform` is omitted and `platforms` has exactly one entry, use it. If `platforms` has more than one entry and `--platform` was omitted, print the list and ask the user which platform to render.

Resolve the output path: `.pdeq/viz/<feature>.html` at the repo root. Create `.pdeq/viz/` if it doesn't exist. If `<feature>.html` already exists at that path, overwrite it.

---

## Step 2 — Read the design spec

Read the resolved design spec markdown file. The full file content is your input. You may also read `<specsRoot>/product/<feature>.md` for context on what the feature does, but the design spec is the source of truth for layout, interaction, and visual structure.

Do not read engineering or QA specs. They describe implementation and verification, not visual intent.

---

## Step 3 — Generate the HTML artifact

Produce a single self-contained HTML file with the following constraints:

- One `.html` file. No external CSS, no external JS bundles, no build step. The file must render correctly when opened directly from the file system.
- Use Tailwind via the Play CDN (`<script src="https://cdn.tailwindcss.com"></script>`) for styling. No other framework dependencies.
- Inline JavaScript is allowed for screen-to-screen navigation, modal toggles, and other interactive affordances the design spec describes. No external JS dependencies.
- If the design spec describes multiple screens, embed all of them in the single file with in-page navigation (tabs, buttons, hash routing — pick whichever fits the design's flow).
- Translate layout, content, and interaction described in the design spec as faithfully as you can read them. When the spec is ambiguous, pick a reasonable default and add a small visible note in the artifact (not a comment — a UI element) flagging the assumption.
- Choose fidelity automatically based on what the design spec says. A spec dense with copy, color, and component detail should produce a styled mockup. A spec that's mostly layout boxes and notes should produce a wireframe. Do not ask the user which mode — the spec is the answer.

Write the HTML file to `.pdeq/viz/<feature>.html`.

---

## Step 4 — Open it

Open the rendered artifact in the user's default browser:

- macOS: `open .pdeq/viz/<feature>.html`
- Linux: `xdg-open .pdeq/viz/<feature>.html`
- Windows (WSL): `explorer.exe .pdeq/viz/<feature>.html`

Detect the platform from `uname` and pick the right command. If detection fails, just print the absolute path and tell the user to open it manually.

---

## Step 5 — Report

Print a one-line summary:

```
visualize: rendered <feature> from design/<platform>/<feature>.md → .pdeq/viz/<feature>.html (opened)
```

If the user asked for a specific feature that has no design spec, report:

```
✗ no design spec at design/<platform>/<feature>.md
```

and exit without writing anything.

---

## Constraints

- This artifact is disposable. Do not commit it. Do not reference it from any other spec. Do not stamp it with frontmatter, hashes, or slug inventories.
- Re-running the command on the same feature overwrites the previous artifact. There is no version history.
- This is a prototype tool. Cheap, fast, throwaway. If you find yourself reaching for production-quality scaffolding (drift detection, test fixtures, audit integration), stop — that's not the goal here.
