---
name: pdeq
description: Add the PDEQ spec-driven development framework to the current project. Use when user says "add pdeq", "set up pdeq", "install pdeq", "add spec management", or wants to add structured product/design/engineering/QA workflow to a project.
---

# PDEQ Setup Skill

**Add PDEQ to the current project.**

PDEQ is a multi-harness coding-agent framework that gives a project four structured lanes — Product, Design, Engineering, QA — with traceable requirements, lane discipline, and a spec-first workflow. v1 supports Claude Code, Codex CLI, and Pi. This skill is the Claude Code surface for setup; consumers using other harnesses install via `scripts/init.sh` directly with the `--harnesses` flag.

Local PDEQ repo: `/Users/ldstreet/Development/pdeq`

---

## Step 0: Orient

Before doing anything, run:

```bash
pwd && git rev-parse --show-toplevel 2>/dev/null || echo "NOT A GIT REPO"
```

If not in a git repo, tell the user and stop.

Check if PDEQ is already installed:

```bash
ls .pdeq 2>/dev/null && echo "ALREADY INSTALLED" || echo "NOT INSTALLED"
```

If already installed, tell the user PDEQ is already set up, and offer to run `/pdeq-kickoff` or `/pdeq-bootstrap` instead.

---

## Step 1: Determine Install Type

Ask the user two questions (one combined prompt is fine):

1. > Is this a **new (greenfield) project**, an **existing project** with code already written, or a **nested/monorepo install** (PDEQ goes inside a subfolder)?
2. > Which coding-agent harnesses do you want pdeq materialized for? (default `claude`; can be a comma-separated list of `claude`, `codex`, `pi`)

Based on the first answer, proceed to the matching path below. Pass the harness list to `init.sh` via `--harnesses <list>` (omit the flag to accept the default `claude`).

---

## Path A: Greenfield Project

```bash
git submodule add /Users/ldstreet/Development/pdeq .pdeq
bash .pdeq/scripts/init.sh --harnesses <list>
```

When done:
- Tell the user PDEQ is installed and which harnesses were materialized
- For Claude Code users: invoke `/pdeq-kickoff [feature description]` to start their first feature
- For Codex/Pi users: ask their agent to "do a pdeq kickoff for X" — same workflow, no markdown slash command needed
- Mention they can define platforms by editing the platform table in `AGENTS.md` (or `CLAUDE.md` for Claude users)

---

## Path B: Existing Project (code already exists)

Ask:
1. Where is the source code relative to the project root? (e.g., `src`, `.`, `lib`) — default `.`
2. What platform(s) does this project target? (e.g., `web`, `ios`, `cli`) — can be comma-separated

Then run:

```bash
git submodule add /Users/ldstreet/Development/pdeq .pdeq
bash .pdeq/scripts/init.sh --code-root <answer-1> --platforms <answer-2> --harnesses <harness-list>
```

When done:
- Tell the user PDEQ is installed with `pdeq.json` configured (including the harness list)
- For Claude Code users: invoke `/pdeq-bootstrap` to analyze their existing code and generate draft specs
- For Codex/Pi users: ask their agent to "bootstrap pdeq from existing code"
- Mention `--dry-run` is available to preview without writing files (works in either invocation form)

---

## Path C: Nested / Monorepo Install

Ask:
1. What is the relative path from the **current directory** up to the **git root**? (e.g., `../..`, `../../..`)
2. What is a short name for this component? (e.g., `auth-service`, `ios-app`)
3. Where is the source code relative to the current directory? (e.g., `src`, `../src`) — default `.`
4. What platform(s)? (e.g., `ios`, `web`) — can be comma-separated

Then run:

```bash
bash /Users/ldstreet/Development/pdeq/scripts/init.sh \
  --pdeq-url /Users/ldstreet/Development/pdeq \
  --nested <answer-1> \
  --label <answer-2> \
  --code-root <answer-3> \
  --platforms <answer-4> \
  --harnesses <harness-list>
```

When done:
- Tell the user PDEQ is installed as a nested component
- Tell them `.pdeq`, `scripts/`, and any per-harness command directories were anchored at the git root
- Tell them to invoke `/pdeq-bootstrap` (or ask their agent to bootstrap from existing code) to generate draft specs, or `/pdeq-kickoff` to start fresh

---

## After Any Install

Remind the user of the key commands:

| Command | What it does |
|---|---|
| `/pdeq-kickoff [feature]` | Start a new feature: product → design → engineering + QA |
| `/pdeq-bootstrap` | Generate draft specs from existing code |
| `/pdeq-status` | See feature coverage and traceability gaps |
| `/pdeq-impact [slug]` | See what would change if a requirement is modified |
| `/pdeq-migrate` | Apply pending pdeq migrations |
| `/pdeq-update` | Bump pdeq and chain into `/pdeq-migrate` in one flow |

The cardinal rule: **specs change first, code follows.** To change behavior, update the relevant spec in `product/`, `design/`, or `engineering/`, then update code to match.
