#!/usr/bin/env bash
set -euo pipefail

# PDEQ init script
# Installs the PDEQ framework into the current directory (or a nested subdirectory).
#
# Usage:
#   Standard (git root):
#     .pdeq/scripts/init.sh
#     bash /path/to/pdeq/scripts/init.sh <pdeq-url>
#
#   Nested / monorepo:
#     bash /path/to/pdeq/scripts/init.sh \
#       --nested <path-to-repo-root> \
#       --label <component-name> \
#       --code-root <path-to-src> \
#       --platforms ios,android
#
#   Interactive (prompts for each value):
#     bash /path/to/pdeq/scripts/init.sh --interactive
#
# Flags:
#   --code-root <path>      Where source code lives (relative to install dir)
#   --specs-root <path>     Where to put product/design/engineering/qa/roadmap (default: .)
#   --nested <repo-root>    Path from install dir up to the actual git root
#   --label <name>          Component name for nested installs
#   --platforms <list>      Comma-separated platform IDs (e.g. ios,android)
#   --interactive           Prompt for each config value
#   --pdeq-url <url>        PDEQ repo URL or local path (for first-time installs)

PDEQ_DIR=".pdeq"
CREATED=0
SKIPPED=0

# Config values (populated by flags, interactive prompts, or defaults)
OPT_CODE_ROOT=""
OPT_SPECS_ROOT=""
OPT_NESTED_REPO_ROOT=""
OPT_LABEL=""
OPT_PLATFORMS=""
OPT_INTERACTIVE=0
OPT_PDEQ_URL=""
OPT_SKIP_HOOKS=0

green()  { printf '\033[0;32m✓\033[0m %s\n' "$*"; }
skip()   { printf '\033[0;33m~\033[0m %s\n' "$*"; }
info()   { printf '  %s\n' "$*"; }
prompt() { printf '\033[0;36m?\033[0m %s ' "$*"; }

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --code-root)   OPT_CODE_ROOT="$2";         shift 2 ;;
    --specs-root)  OPT_SPECS_ROOT="$2";        shift 2 ;;
    --nested)      OPT_NESTED_REPO_ROOT="$2";  shift 2 ;;
    --label)       OPT_LABEL="$2";             shift 2 ;;
    --platforms)   OPT_PLATFORMS="$2";         shift 2 ;;
    --interactive) OPT_INTERACTIVE=1;          shift ;;
    --pdeq-url)    OPT_PDEQ_URL="$2";         shift 2 ;;
    --skip-hooks)  OPT_SKIP_HOOKS=1;           shift ;;
    -*)
      echo "Unknown flag: $1"
      echo "Usage: $0 [--code-root <path>] [--specs-root <path>] [--nested <repo-root>] [--label <name>] [--platforms <list>] [--interactive] [--pdeq-url <url>] [--skip-hooks]"
      exit 1
      ;;
    *)
      # Positional arg treated as pdeq-url for backwards compat
      OPT_PDEQ_URL="$1"
      shift
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Detect install location
# ---------------------------------------------------------------------------
INSTALL_DIR="$(pwd)"

# Determine git root — either explicit (nested) or auto-detected
if [[ -n "$OPT_NESTED_REPO_ROOT" ]]; then
  # Nested install: resolve the git root manually
  GIT_ROOT="$(cd "$INSTALL_DIR/$OPT_NESTED_REPO_ROOT" && pwd)"
  IS_NESTED=1
else
  if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: not inside a git repository."
    echo "If this is a nested install, use --nested <path-to-repo-root>"
    exit 1
  fi
  GIT_ROOT="$(git rev-parse --show-toplevel)"
  IS_NESTED=0
fi

# Compute the relative path depth from INSTALL_DIR back to GIT_ROOT
# Used to build correct @ import prefixes for CLAUDE.md files
_rel_depth() {
  local from="$1" to="$2"
  if [[ "$from" == "$to" ]]; then
    echo ""
    return
  fi
  local rel="${from#$to/}"
  local depth
  depth=$(echo "$rel" | tr -cd '/' | wc -c)
  depth=$((depth + 1))
  local ups=""
  for ((i=0; i<depth; i++)); do ups="../$ups"; done
  echo "${ups%/}"
}

REL_TO_GIT_ROOT="$(_rel_depth "$INSTALL_DIR" "$GIT_ROOT")"

# ---------------------------------------------------------------------------
# Interactive mode — prompt for values not already supplied
# ---------------------------------------------------------------------------
if [[ "$OPT_INTERACTIVE" == "1" ]]; then
  if [[ -z "$OPT_CODE_ROOT" ]]; then
    prompt "Where is your source code? (relative to this directory, default '.')"
    read -r OPT_CODE_ROOT
    OPT_CODE_ROOT="${OPT_CODE_ROOT:-.}"
  fi
  if [[ -z "$OPT_SPECS_ROOT" ]]; then
    prompt "Where should specs live? (relative to this directory, default '.')"
    read -r OPT_SPECS_ROOT
    OPT_SPECS_ROOT="${OPT_SPECS_ROOT:-.}"
  fi
  if [[ -z "$OPT_PLATFORMS" ]]; then
    prompt "Platforms (comma-separated, e.g. 'web,mobile', optional — press enter to skip)"
    read -r OPT_PLATFORMS
  fi
  if [[ "$IS_NESTED" == "0" && -z "$OPT_NESTED_REPO_ROOT" ]]; then
    prompt "Is this a nested install? (path up to git root, or press enter to skip)"
    read -r OPT_NESTED_REPO_ROOT
    if [[ -n "$OPT_NESTED_REPO_ROOT" && -z "$OPT_LABEL" ]]; then
      prompt "Component label (e.g. 'auth-service', optional — press enter to skip)"
      read -r OPT_LABEL
    fi
  fi
fi

# Apply defaults
OPT_CODE_ROOT="${OPT_CODE_ROOT:-.}"
OPT_SPECS_ROOT="${OPT_SPECS_ROOT:-.}"

# ---------------------------------------------------------------------------
# Step 1: Add submodule if needed
# ---------------------------------------------------------------------------
PDEQ_PATH="$GIT_ROOT/$PDEQ_DIR"

if [[ -d "$PDEQ_PATH" ]]; then
  skip "Submodule $PDEQ_DIR already present"
  ((SKIPPED++))
else
  if [[ -z "$OPT_PDEQ_URL" ]]; then
    echo "Error: $PDEQ_DIR not found. Provide a URL/path with --pdeq-url <url>."
    exit 1
  fi
  cd "$GIT_ROOT"
  git submodule add "$OPT_PDEQ_URL" "$PDEQ_DIR"
  green "Added submodule $PDEQ_DIR"
  ((CREATED++))
  cd "$INSTALL_DIR"
fi

# ---------------------------------------------------------------------------
# Step 2: Resolve specs dir and build @ import prefixes
# ---------------------------------------------------------------------------
# SPECS_DIR: absolute path where product/design/engineering/qa/roadmap will be created
if [[ "$OPT_SPECS_ROOT" == "." ]]; then
  SPECS_DIR="$INSTALL_DIR"
else
  SPECS_DIR="$INSTALL_DIR/$OPT_SPECS_ROOT"
  mkdir -p "$SPECS_DIR"
fi

# Build the @ import prefix for functional area CLAUDE.md files:
# "relative path from SPECS_DIR up to GIT_ROOT" + "/$PDEQ_DIR"
if [[ "$SPECS_DIR" == "$GIT_ROOT" ]]; then
  PDEQ_IMPORT_PREFIX="$PDEQ_DIR"
else
  UP="$(_rel_depth "$SPECS_DIR" "$GIT_ROOT")"
  PDEQ_IMPORT_PREFIX="$UP/$PDEQ_DIR"
fi

# For the root CLAUDE.md (at INSTALL_DIR):
if [[ "$INSTALL_DIR" == "$GIT_ROOT" ]]; then
  ROOT_CLAUDE_IMPORT="$PDEQ_DIR/CLAUDE.md"
else
  UP="$(_rel_depth "$INSTALL_DIR" "$GIT_ROOT")"
  ROOT_CLAUDE_IMPORT="$UP/$PDEQ_DIR/CLAUDE.md"
fi

# ---------------------------------------------------------------------------
# Step 3: Create functional area directories + CLAUDE.md @ imports
# ---------------------------------------------------------------------------
for area in product design engineering qa roadmap; do
  areadir="$SPECS_DIR/$area"
  mkdir -p "$areadir"
  target="$areadir/CLAUDE.md"
  if [[ -f "$target" ]]; then
    skip "$area/CLAUDE.md already exists"
    ((SKIPPED++))
  else
    echo "@$PDEQ_IMPORT_PREFIX/$area/CLAUDE.md" > "$target"
    green "Created $area/CLAUDE.md"
    ((CREATED++))
  fi
done

# ---------------------------------------------------------------------------
# Step 4: Root CLAUDE.md (in INSTALL_DIR)
# ---------------------------------------------------------------------------
ROOT_CLAUDE="$INSTALL_DIR/CLAUDE.md"
if [[ -f "$ROOT_CLAUDE" ]]; then
  skip "CLAUDE.md already exists — add '@$ROOT_CLAUDE_IMPORT' to the top manually if needed"
  ((SKIPPED++))
else
  cat > "$ROOT_CLAUDE" << HEREDOC
@$ROOT_CLAUDE_IMPORT

## Project-Specific Instructions

<!-- Add any project-specific overrides or additions below.
     The line above imports the full PDEQ coordinator agent from the submodule.
     Anything you write here extends or overrides those instructions. -->
HEREDOC
  green "Created CLAUDE.md"
  ((CREATED++))
fi

# ---------------------------------------------------------------------------
# Step 5: Symlink scripts (anchored at git root so paths stay valid)
# ---------------------------------------------------------------------------
SCRIPTS_TARGET="$GIT_ROOT/scripts"
mkdir -p "$SCRIPTS_TARGET"
for src in "$PDEQ_PATH"/scripts/*; do
  name="$(basename "$src")"
  dest="$SCRIPTS_TARGET/$name"
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
# Step 6: Symlink .claude/commands (anchored at git root)
# ---------------------------------------------------------------------------
COMMANDS_TARGET="$GIT_ROOT/.claude/commands"
mkdir -p "$COMMANDS_TARGET"
for src in "$PDEQ_PATH"/.claude/commands/*; do
  name="$(basename "$src")"
  dest="$COMMANDS_TARGET/$name"
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
# Step 7: Copy template files (index.md, glossary.md, decisions.md)
# ---------------------------------------------------------------------------
for tmpl in index.md glossary.md decisions.md; do
  dest="$SPECS_DIR/$tmpl"
  if [[ -f "$dest" ]]; then
    skip "$tmpl already exists"
    ((SKIPPED++))
  else
    cp "$PDEQ_PATH/$tmpl" "$dest"
    green "Created $tmpl (from $PDEQ_DIR template)"
    ((CREATED++))
  fi
done

# ---------------------------------------------------------------------------
# Step 8: .gitignore (at git root)
# ---------------------------------------------------------------------------
GITIGNORE="$GIT_ROOT/.gitignore"
if [[ ! -f "$GITIGNORE" ]]; then
  echo "decisions-pending.md" > "$GITIGNORE"
  green "Created .gitignore"
  ((CREATED++))
elif grep -q "decisions-pending.md" "$GITIGNORE"; then
  skip "decisions-pending.md already in .gitignore"
  ((SKIPPED++))
else
  echo "decisions-pending.md" >> "$GITIGNORE"
  green "Added decisions-pending.md to .gitignore"
  ((CREATED++))
fi

# ---------------------------------------------------------------------------
# Step 9: Generate pdeq.json (always — pdeqVersion must be recorded)
# ---------------------------------------------------------------------------
# Implements: FR-migrations-version-field
PDEQ_CONFIG="$INSTALL_DIR/pdeq.json"

# Resolve pdeqVersion from the authoritative VERSION file.
# Consumer install reads .pdeq/VERSION; pdeq self-host reads ./VERSION.
PDEQ_VERSION=""
if [[ -f "$PDEQ_PATH/VERSION" ]]; then
  PDEQ_VERSION="$(head -n 1 "$PDEQ_PATH/VERSION" | tr -d '[:space:]')"
elif [[ -f "$GIT_ROOT/VERSION" ]]; then
  PDEQ_VERSION="$(head -n 1 "$GIT_ROOT/VERSION" | tr -d '[:space:]')"
fi

if [[ -f "$PDEQ_CONFIG" ]]; then
  skip "pdeq.json already exists — update manually to change paths"
  ((SKIPPED++))
else
  # Build platforms JSON array
  platforms_json="[]"
  if [[ -n "$OPT_PLATFORMS" ]]; then
    IFS=',' read -ra PLAT_ARRAY <<< "$OPT_PLATFORMS"
    platforms_json="["
    first=1
    for p in "${PLAT_ARRAY[@]}"; do
      p="${p// /}"
      if [[ "$first" == "1" ]]; then
        platforms_json+="\"$p\""
        first=0
      else
        platforms_json+=", \"$p\""
      fi
    done
    platforms_json+="]"
  fi

  # Build optional nested block
  nested_block=""
  if [[ -n "$OPT_NESTED_REPO_ROOT" ]]; then
    if [[ -n "$OPT_LABEL" ]]; then
      nested_block=",
  \"nested\": {
    \"repoRoot\": \"$OPT_NESTED_REPO_ROOT\",
    \"label\": \"$OPT_LABEL\"
  }"
    else
      nested_block=",
  \"nested\": {
    \"repoRoot\": \"$OPT_NESTED_REPO_ROOT\"
  }"
    fi
  fi

  version_line=""
  if [[ -n "$PDEQ_VERSION" ]]; then
    version_line="
  \"pdeqVersion\": \"$PDEQ_VERSION\","
  fi

  cat > "$PDEQ_CONFIG" << JSONEOF
{$version_line
  "specsRoot": "$OPT_SPECS_ROOT",
  "codeRoot": "$OPT_CODE_ROOT",
  "platforms": $platforms_json$nested_block
}
JSONEOF
  green "Generated pdeq.json${PDEQ_VERSION:+ (pdeqVersion: $PDEQ_VERSION)}"
  ((CREATED++))
fi

# ---------------------------------------------------------------------------
# Step 10: Install git hooks via core.hooksPath (unless --skip-hooks)
# ---------------------------------------------------------------------------
# Points core.hooksPath at the tracked hook directory inside the pdeq install
# so the audit + merge-decisions + migrations-gate scripts run automatically
# at commit time. Tracked dir means adding new hooks is a code review, not a
# per-developer reinstall.
#
# See root CLAUDE.md §Requirement ↔ Code Mapping for the rationale on why
# core.hooksPath is preferred over symlinking into .git/hooks/.
# Implements: FR-code-mapping-audit-scan

if [[ "$OPT_SKIP_HOOKS" == "1" ]]; then
  skip "Skipping git hook install (--skip-hooks)"
  ((SKIPPED++))
else
  # Hooks live at <pdeq_root>/hooks for the pdeq self-host, or inside the
  # submodule at .pdeq/hooks for consumer installs. Resolve relative to
  # GIT_ROOT so the config entry survives cd'ing around.
  HOOKS_DIR_ABS="$PDEQ_PATH/hooks"
  if [[ ! -d "$HOOKS_DIR_ABS" ]]; then
    # Self-host fallback: pdeq's own repo keeps hooks at <root>/hooks
    HOOKS_DIR_ABS="$GIT_ROOT/hooks"
  fi

  if [[ -d "$HOOKS_DIR_ABS" ]]; then
    # Express the path relative to GIT_ROOT so git stores it portably.
    HOOKS_REL="${HOOKS_DIR_ABS#$GIT_ROOT/}"
    CURRENT_HOOKS_PATH="$(cd "$GIT_ROOT" && git config --get core.hooksPath 2>/dev/null || true)"

    if [[ "$CURRENT_HOOKS_PATH" == "$HOOKS_REL" ]]; then
      skip "Git hooks already wired to $HOOKS_REL"
      ((SKIPPED++))
    elif [[ -n "$CURRENT_HOOKS_PATH" && "$CURRENT_HOOKS_PATH" != "$HOOKS_REL" ]]; then
      skip "core.hooksPath already set to '$CURRENT_HOOKS_PATH' — not overwriting. Re-run with --skip-hooks, or unset manually to switch."
      ((SKIPPED++))
    else
      (cd "$GIT_ROOT" && git config core.hooksPath "$HOOKS_REL")
      green "Installed pdeq git hooks at $HOOKS_REL"
      info "  Hooks wired: pre-commit (traceability + decisions merge), commit-msg (migrations gate)"
      info "  Override for a single commit: PDEQ_SKIP_HOOKS=1 git commit ..."
      ((CREATED++))
    fi
  else
    skip "No hooks/ directory found in pdeq install — skipping hook install"
    ((SKIPPED++))
  fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n'
info "PDEQ init complete — Created: $CREATED  Skipped: $SKIPPED"
printf '\n'
info "Next steps:"
info "  1. Review CLAUDE.md and add project-specific instructions"
info "  2. Review pdeq.json — verify pdeqVersion, specsRoot, codeRoot, and platforms"
info "  3. Run /bootstrap to generate draft specs from your existing code,"
info "     or /kickoff to start your first feature from scratch"
info "  To update PDEQ later: git submodule update --remote $PDEQ_DIR"
printf '\n'
