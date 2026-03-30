---
name: pdeq
description: Add the PDEQ spec-driven development framework to the current project. Use when user says "add pdeq", "set up pdeq", "install pdeq", "add spec management", or wants to add structured product/design/engineering/QA workflow to a project.
---

# PDEQ Setup Skill

**Add PDEQ to the current project.**

PDEQ is a Claude Code framework that gives a project four structured lanes — Product, Design, Engineering, QA — with traceable requirements, lane discipline, and a spec-first workflow.

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

If already installed, tell the user PDEQ is already set up, and offer to run `/kickoff` or `/bootstrap` instead.

---

## Step 1: Determine Install Type

Ask the user one question:

> Is this a **new (greenfield) project**, an **existing project** with code already written, or a **nested/monorepo install** (PDEQ goes inside a subfolder)?

Based on the answer, proceed to the matching path below.

---

## Path A: Greenfield Project

```bash
git submodule add /Users/ldstreet/Development/pdeq .pdeq
bash .pdeq/scripts/init.sh
```

When done:
- Tell the user PDEQ is installed
- Tell them to open Claude Code (if not already in it) and run `/kickoff [feature description]` to start their first feature
- Mention they can define platforms by editing the platform table in `CLAUDE.md`

---

## Path B: Existing Project (code already exists)

Ask:
1. Where is the source code relative to the project root? (e.g., `src`, `.`, `lib`) — default `.`
2. What platform(s) does this project target? (e.g., `web`, `ios`, `cli`) — can be comma-separated

Then run:

```bash
git submodule add /Users/ldstreet/Development/pdeq .pdeq
bash .pdeq/scripts/init.sh --code-root <answer-1> --platforms <answer-2>
```

When done:
- Tell the user PDEQ is installed with `pdeq.json` configured
- Tell them to run `/bootstrap` in Claude Code to analyze their existing code and generate draft specs
- Mention `/bootstrap --dry-run` is available to preview without writing files

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
  --platforms <answer-4>
```

When done:
- Tell the user PDEQ is installed as a nested component
- Tell them `.pdeq`, `scripts/`, and `.claude/commands/` were symlinked at the git root
- Tell them to run `/bootstrap` to generate draft specs from existing code, or `/kickoff` to start fresh

---

## After Any Install

Remind the user of the key commands:

| Command | What it does |
|---|---|
| `/kickoff [feature]` | Start a new feature: product → design → engineering + QA |
| `/bootstrap` | Generate draft specs from existing code |
| `/status` | See feature coverage and traceability gaps |
| `/impact [slug]` | See what would change if a requirement is modified |

The cardinal rule: **specs change first, code follows.** To change behavior, update the relevant spec in `product/`, `design/`, or `engineering/`, then update code to match.
