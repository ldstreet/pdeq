#!/usr/bin/env bash
set -euo pipefail

# PDEQ init script
# Installs the PDEQ framework into the current directory.
#
# Usage (from target project root):
#   .pdeq/scripts/init.sh              # if .pdeq submodule already added
#   curl ... | bash -s <pdeq-url>      # first-time install (adds submodule)
#   bash /path/to/pdeq/scripts/init.sh <pdeq-url>  # local path

PDEQ_DIR=".pdeq"
CREATED=0
SKIPPED=0

green() { printf '\033[0;32m✓\033[0m %s\n' "$*"; }
skip()  { printf '\033[0;33m~\033[0m %s\n' "$*"; }
info()  { printf '  %s\n' "$*"; }

# Detect project root (where .git lives)
if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo "Error: not inside a git repository. Run this from your project root."
  exit 1
fi
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

# ---------------------------------------------------------------------------
# Step 1: Add submodule if needed
# ---------------------------------------------------------------------------
if [[ -d "$PDEQ_DIR" ]]; then
  skip "Submodule $PDEQ_DIR already present"
  ((SKIPPED++))
else
  PDEQ_URL="${1:-}"
  if [[ -z "$PDEQ_URL" ]]; then
    echo "Usage: $0 <pdeq-repo-url-or-path>"
    echo "  e.g. $0 https://github.com/yourname/pdeq"
    echo "       $0 /path/to/local/pdeq"
    exit 1
  fi
  git submodule add "$PDEQ_URL" "$PDEQ_DIR"
  green "Added submodule $PDEQ_DIR"
  ((CREATED++))
fi

# ---------------------------------------------------------------------------
# Step 2: Create functional area directories + CLAUDE.md @ imports
# ---------------------------------------------------------------------------
for area in product design engineering qa; do
  mkdir -p "$area"
  target="$area/CLAUDE.md"
  if [[ -f "$target" ]]; then
    skip "$target already exists"
    ((SKIPPED++))
  else
    echo "@../$PDEQ_DIR/$area/CLAUDE.md" > "$target"
    green "Created $target"
    ((CREATED++))
  fi
done

# ---------------------------------------------------------------------------
# Step 3: Root CLAUDE.md
# ---------------------------------------------------------------------------
if [[ -f "CLAUDE.md" ]]; then
  skip "CLAUDE.md already exists — add '@$PDEQ_DIR/CLAUDE.md' to the top manually if needed"
  ((SKIPPED++))
else
  cat > "CLAUDE.md" << 'HEREDOC'
@.pdeq/CLAUDE.md

## Project-Specific Instructions

<!-- Add any project-specific overrides or additions below.
     The line above imports the full PDEQ coordinator agent from the submodule.
     Anything you write here extends or overrides those instructions. -->
HEREDOC
  green "Created CLAUDE.md"
  ((CREATED++))
fi

# ---------------------------------------------------------------------------
# Step 4: Symlink scripts
# ---------------------------------------------------------------------------
mkdir -p scripts
for src in "$PDEQ_DIR"/scripts/*; do
  name="$(basename "$src")"
  dest="scripts/$name"
  if [[ -e "$dest" || -L "$dest" ]]; then
    skip "scripts/$name already exists"
    ((SKIPPED++))
  else
    ln -s "../$PDEQ_DIR/scripts/$name" "$dest"
    green "Symlinked scripts/$name → $PDEQ_DIR/scripts/$name"
    ((CREATED++))
  fi
done

# ---------------------------------------------------------------------------
# Step 5: Symlink .claude/commands
# ---------------------------------------------------------------------------
mkdir -p .claude/commands
for src in "$PDEQ_DIR"/.claude/commands/*; do
  name="$(basename "$src")"
  dest=".claude/commands/$name"
  if [[ -e "$dest" || -L "$dest" ]]; then
    skip ".claude/commands/$name already exists"
    ((SKIPPED++))
  else
    ln -s "../../$PDEQ_DIR/.claude/commands/$name" "$dest"
    green "Symlinked .claude/commands/$name → $PDEQ_DIR/.claude/commands/$name"
    ((CREATED++))
  fi
done

# ---------------------------------------------------------------------------
# Step 6: Copy template files (index.md, glossary.md, decisions.md)
# ---------------------------------------------------------------------------
for tmpl in index.md glossary.md decisions.md; do
  if [[ -f "$tmpl" ]]; then
    skip "$tmpl already exists"
    ((SKIPPED++))
  else
    cp "$PDEQ_DIR/$tmpl" "$tmpl"
    green "Created $tmpl (from $PDEQ_DIR template)"
    ((CREATED++))
  fi
done

# ---------------------------------------------------------------------------
# Step 7: .gitignore
# ---------------------------------------------------------------------------
if [[ ! -f ".gitignore" ]]; then
  echo "decisions-pending.md" > .gitignore
  green "Created .gitignore"
  ((CREATED++))
elif grep -q "decisions-pending.md" .gitignore; then
  skip "decisions-pending.md already in .gitignore"
  ((SKIPPED++))
else
  echo "decisions-pending.md" >> .gitignore
  green "Added decisions-pending.md to .gitignore"
  ((CREATED++))
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n'
info "PDEQ init complete — Created: $CREATED  Skipped: $SKIPPED"
printf '\n'
info "Next steps:"
info "  1. Review CLAUDE.md and add project-specific instructions"
info "  2. Run /kickoff to start your first feature"
info "  3. To update PDEQ later: git submodule update --remote $PDEQ_DIR"
printf '\n'
