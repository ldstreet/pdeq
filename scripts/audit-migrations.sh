#!/usr/bin/env bash
#
# pdeq audit-migrations — commit-msg gate for breaking version bumps.
#
# Blocks pdeq-maintainer commits that bump VERSION to a breaking release without
# authoring the matching migrations/<version>.md file. Silent on all other
# commits (docs-only, non-framework, non-breaking patch bumps, etc.) per
# NFR-migrations-enforcement-precision.
#
# Invocation: commit-msg hook. Git passes the path to COMMIT_EDITMSG as $1.
# The hook reads that file directly — NOT `git log -1`, which would read the
# previous commit (the new commit's message is not yet in the log at this point).
#
# Exit codes:
#   0 — commit allowed (gate silent, or non-breaking, or trailer override).
#   1 — gate blocked the commit: Surface 8 output printed to stderr.
#
# Escape hatch: a commit message containing the literal trailer line
#   pdeq-migration: none-required
# bypasses the gate after logging a one-line note. Use only when the version
# bump is consciously non-breaking despite framework-file changes.
#
# Implements: FR-migrations-breaking-gate, FR-migrations-no-false-positive

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || dirname "$(dirname "$0")")"

red()    { printf '\033[0;31m✗\033[0m %s\n' "$*"; }
info()   { printf '  %s\n' "$*"; }

# ─── Input: commit message path ─────────────────────────────────────────────
#
# Git invokes commit-msg with the path to COMMIT_EDITMSG as $1. Reading the
# message from that file is the only correct source; `git log -1` reads the
# previous commit.
COMMIT_MSG_FILE="${1:-}"
if [[ -z "$COMMIT_MSG_FILE" || ! -f "$COMMIT_MSG_FILE" ]]; then
  echo "[pdeq gate] commit-msg hook invoked without a message path; aborting." >&2
  exit 1
fi

# ─── Step 1: collect staged framework-file changes ──────────────────────────
#
# Framework files trigger the gate's preconditions. Anything staged outside
# this set is invisible to the gate (docs, specs, tests, fixtures).
framework_changes=$(git diff --cached --name-only -- \
  'CLAUDE.md' '*/CLAUDE.md' 'scripts/*.sh' '.claude/commands/*.md' 'pdeq.schema.json' \
  2>/dev/null || true)

# ─── Step 2: check whether VERSION was bumped ───────────────────────────────
version_change=$(git diff --cached --name-only -- VERSION 2>/dev/null || true)

# ─── Step 3: if neither framework nor VERSION changed, silent pass ──────────
#
# Gate is silent on every non-matching commit. NFR-migrations-enforcement-precision
# requires no noise on unrelated commits.
if [[ -z "$framework_changes" && -z "$version_change" ]]; then
  exit 0
fi

# ─── Step 4: read old and new VERSION ───────────────────────────────────────
#
# `git show HEAD:VERSION` reads the previous committed value; plain `cat VERSION`
# reads the staged value (which is what will land on disk once the commit
# finishes). If VERSION is not staged, old == new.
old_ver=$(git show HEAD:VERSION 2>/dev/null | head -n 1 | tr -d '[:space:]' || echo "")
if [[ -f "$ROOT/VERSION" ]]; then
  new_ver=$(head -n 1 "$ROOT/VERSION" | tr -d '[:space:]')
else
  new_ver=""
fi

# ─── Step 5: check for the none-required trailer (explicit override) ────────
#
# Trailer must appear on its own line. Matched with a literal regex — not
# `git interpret-trailers`, which is not uniformly available.
commit_msg=$(cat "$COMMIT_MSG_FILE")
if grep -qE '^pdeq-migration:[[:space:]]*none-required[[:space:]]*$' <<< "$commit_msg"; then
  echo "[pdeq gate] pdeq-migration: none-required — commit allowed." >&2
  exit 0
fi

# ─── Step 6: determine whether the bump is breaking ─────────────────────────
#
# A bump is breaking when MAJOR or MINOR changes. PATCH-only bumps are assumed
# non-breaking and pass through. A bump requires both old and new to be valid
# semver; a first-ever VERSION write (no HEAD:VERSION) is treated as the
# baseline (not breaking) so this gate doesn't fire on the feature's own
# bootstrap commit.
is_breaking_bump() {
  local old="$1" new="$2"
  [[ -n "$old" && -n "$new" ]] || return 1
  [[ "$old" != "$new" ]] || return 1
  local old_mm new_mm
  old_mm=$(awk -F. '{ print $1 "." $2 }' <<< "$old")
  new_mm=$(awk -F. '{ print $1 "." $2 }' <<< "$new")
  [[ "$old_mm" != "$new_mm" ]]
}

# ─── Step 7: if VERSION was not staged, no breaking bump is possible ────────
#
# Framework files can change freely without a VERSION bump; the gate only
# fires when a breaking bump actually occurs.
if [[ -z "$version_change" ]]; then
  exit 0
fi

if ! is_breaking_bump "$old_ver" "$new_ver"; then
  exit 0
fi

# ─── Step 8: breaking bump — require migrations/<new_ver>.md staged ─────────
#
# Printed path is `migrations/<ver>.md` (repo-local). The consumer-side
# `.pdeq/migrations/` form is used by the /pdeq-migrate runner, not by this gate.
migration_file="migrations/${new_ver}.md"
staged=$(git diff --cached --name-only 2>/dev/null || true)
if grep -qxF "$migration_file" <<< "$staged"; then
  exit 0
fi

# ─── Step 9: block — print Surface 8 output ─────────────────────────────────
{
  red "pdeq commit-msg: breaking-change gate blocked this commit."
  echo
  info "This commit bumps the pdeq version:"
  info "  ${old_ver:-<none>} → ${new_ver}   (breaking)"
  echo
  info "Framework files were modified:"
  if [[ -n "$framework_changes" ]]; then
    while IFS= read -r f; do
      info "  $f"
    done <<< "$framework_changes"
  else
    info "  (VERSION only — still treated as breaking at MAJOR/MINOR bump)"
  fi
  echo
  info "But no migration file exists for ${new_ver}:"
  info "  expected: ${migration_file}  (not found)"
  echo
  info "What to do — pick one:"
  echo
  info "  A) This change is breaking. Author the migration file."
  info "       Create ${migration_file}"
  info "       Include at minimum: frontmatter, Mechanical block (or an"
  info "       explicit \"## Mechanical\\n\\nNone.\" if no mechanical step is needed)."
  echo
  info "  B) This change is NOT breaking. Downgrade the version bump."
  info "       The version in VERSION should change as patch"
  info "       (${old_ver:-X.Y.Z} → patch-only) instead of a breaking bump."
  echo
  info "  C) The gate is wrong about this being a breaking change."
  info "       Add a line to your commit message:"
  info "         pdeq-migration: none-required"
  info "       This signals to the gate that you have reviewed and this bump"
  info "       is deliberately non-breaking despite framework-file changes."
  info "       The gate will log this and allow the commit."
} >&2

exit 1
