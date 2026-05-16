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
OPT_HARNESSES=""
OPT_INTERACTIVE=0
OPT_PDEQ_URL=""
OPT_SKIP_HOOKS=0

# Resolved harness list (populated by resolve_harnesses, validated by
# validate_harnesses). v0.4.0 recognized values: claude, codex, pi.
HARNESSES_ARR=()

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
    --harnesses)   OPT_HARNESSES="$2";         shift 2 ;;
    --interactive) OPT_INTERACTIVE=1;          shift ;;
    --pdeq-url)    OPT_PDEQ_URL="$2";         shift 2 ;;
    --skip-hooks)  OPT_SKIP_HOOKS=1;           shift ;;
    -*)
      echo "Unknown flag: $1"
      echo "Usage: $0 [--code-root <path>] [--specs-root <path>] [--nested <repo-root>] [--label <name>] [--platforms <list>] [--harnesses <list>] [--interactive] [--pdeq-url <url>] [--skip-hooks]"
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

# ---------------------------------------------------------------------------
# Harness adapter table + materialization helpers
# ---------------------------------------------------------------------------
# The adapter table maps each recognized harness identifier to the per-lane
# agent-instructions filename that harness reads, plus the relative directory
# inside the consumer's project where that harness expects markdown-defined
# slash commands (empty = harness does not support markdown slash commands).
#
# Implements: FR-harness-agnostic-v1-harness-set
# Implements: FR-harness-agnostic-unknown-rejected
#
# Adding a new harness in v1.x: add a case branch to each function below and
# add the identifier to pdeq.schema.json's enum. The install logic itself
# does not change.
harness_agent_file() {
  case "$1" in
    claude)     echo "CLAUDE.md" ;;
    codex|pi)   echo "AGENTS.md" ;;
    *)          return 1 ;;
  esac
}

harness_commands_dir() {
  case "$1" in
    claude)     echo ".claude/commands" ;;
    codex|pi)   echo "" ;;  # no markdown slash commands at v1
    *)          echo "" ;;
  esac
}

# Implements: FR-harness-agnostic-config
# Resolution precedence:
#   1. --harnesses CLI flag (already in OPT_HARNESSES)
#   2. existing pdeq.json's harnesses array (when present, supports re-runs
#      after the consumer edits the field)
#   3. default ["claude"] (v0.3.x back-compat at the data level)
resolve_harnesses() {
  HARNESSES_ARR=()
  if [[ -n "$OPT_HARNESSES" ]]; then
    IFS=',' read -ra HARNESSES_ARR <<< "$OPT_HARNESSES"
  elif [[ -f "$INSTALL_DIR/pdeq.json" ]]; then
    # Cheap JSON parse: extract just the array contents (between [ and ]) so
    # the field name "harnesses" is not picked up by the token extractor.
    local raw inner
    raw=$(tr -d '\n' < "$INSTALL_DIR/pdeq.json" \
          | grep -oE '"harnesses"[[:space:]]*:[[:space:]]*\[[^]]*\]' \
          | head -n1)
    if [[ -n "$raw" ]]; then
      # Drop everything up to and including the opening bracket, drop the closing bracket.
      inner="${raw#*\[}"
      inner="${inner%\]}"
      local tok
      while IFS= read -r tok; do
        [[ -n "$tok" ]] && HARNESSES_ARR+=("$tok")
      done < <(echo "$inner" | grep -oE '"[a-z][a-z0-9-]*"' | tr -d '"')
    fi
  fi
  # Default fallback
  if [[ ${#HARNESSES_ARR[@]} -eq 0 ]]; then
    HARNESSES_ARR=("claude")
  fi
  # Trim whitespace from each entry
  local i
  for i in "${!HARNESSES_ARR[@]}"; do
    HARNESSES_ARR[$i]="${HARNESSES_ARR[$i]// /}"
  done
}

# Implements: FR-harness-agnostic-unknown-rejected
# Called BEFORE any filesystem writes so an unknown harness exits cleanly
# without partial install.
validate_harnesses() {
  local h
  for h in "${HARNESSES_ARR[@]}"; do
    if ! harness_agent_file "$h" >/dev/null 2>&1; then
      echo "Error: unrecognized harness '$h'." >&2
      echo "Recognized harnesses: claude, codex, pi" >&2
      exit 1
    fi
  done
}

# Implements: FR-harness-agnostic-per-harness-install
# Implements: FR-harness-agnostic-claude-import
# Implements: FR-harness-agnostic-symlink-include
# Implements: NFR-harness-agnostic-installer-reporting
# Args: <lane_abs_path> <import_relpath> <label>
#   import_relpath points at the canonical AGENTS.md inside the submodule,
#   relative to lane_abs_path (so Claude's @import line and other harnesses'
#   symlink targets resolve to the same file).
_materialize_agent_file() {
  local lane_dir="$1" import_path="$2" label="$3"
  local h fname dest
  for h in "${HARNESSES_ARR[@]}"; do
    fname=$(harness_agent_file "$h") || continue
    dest="$lane_dir/$fname"
    if [[ -e "$dest" || -L "$dest" ]]; then
      skip "$label/$fname already exists (harness: $h)"
      SKIPPED=$((SKIPPED + 1))
      continue
    fi
    if [[ "$h" == "claude" ]]; then
      # Claude supports @import — emit a one-line wrapper file so the consumer
      # can append project-specific instructions below the import.
      echo "@$import_path" > "$dest"
    else
      # Other harnesses don't have @import; symlink directly to the canonical.
      ln -s "$import_path" "$dest"
    fi
    green "Created $label/$fname (harness: $h)"
    CREATED=$((CREATED + 1))
  done
  return 0
}

# Implements: FR-harness-agnostic-commands-per-harness
# Implements: NFR-harness-agnostic-symlink-portability
# For each enabled harness whose adapter declares a commands dir, mirror the
# pdeq-rules/commands/*.md source files into <git_root>/<commands_dir>/ as
# relative symlinks. Harnesses without a commands dir (codex, pi at v1) are
# skipped entirely.
_materialize_commands() {
  local h cmd_dir target_root depth ups src name dest i
  for h in "${HARNESSES_ARR[@]}"; do
    cmd_dir=$(harness_commands_dir "$h")
    [[ -z "$cmd_dir" ]] && continue
    target_root="$GIT_ROOT/$cmd_dir"
    mkdir -p "$target_root"
    # depth from cmd_dir up to GIT_ROOT — used to build the relative symlink prefix
    depth=$(echo "$cmd_dir" | tr -cd '/' | wc -c)
    depth=$((depth + 1))
    ups=""
    for ((i=0; i<depth; i++)); do ups="../$ups"; done
    for src in "$PDEQ_PATH"/pdeq-rules/commands/*.md; do
      [[ ! -e "$src" ]] && continue
      name="$(basename "$src")"
      dest="$target_root/$name"
      if [[ -e "$dest" || -L "$dest" ]]; then
        skip "$cmd_dir/$name already exists (harness: $h)"
        SKIPPED=$((SKIPPED + 1))
      else
        ln -s "${ups}$PDEQ_DIR/pdeq-rules/commands/$name" "$dest"
        green "Symlinked $cmd_dir/$name → $PDEQ_DIR/pdeq-rules/commands/$name (harness: $h)"
        CREATED=$((CREATED + 1))
      fi
    done
  done
  return 0
}

# Implements: FR-harness-agnostic-removed-harness-cleaned
# After materialization, remove pdeq-managed files that belong to harnesses
# NOT in the current list. A file is considered pdeq-managed if it is a
# symlink (claude's @import files are regular files but we never remove
# CLAUDE.md when claude is dropped — see below). Files claimed by another
# enabled harness with the same filename are left alone.
_cleanup_removed_harnesses() {
  local known_harnesses=(claude codex pi)
  local lane lane_dir h fname is_enabled needed_filename
  # Build the set of filenames that ARE still needed by enabled harnesses.
  local needed=()
  for h in "${HARNESSES_ARR[@]}"; do
    fname=$(harness_agent_file "$h") || continue
    needed+=("$fname")
  done
  # For each known harness NOT in the current list, find and remove its file
  # at each lane if it is pdeq-managed and the filename is not still needed.
  local kh
  for kh in "${known_harnesses[@]}"; do
    is_enabled=0
    for h in "${HARNESSES_ARR[@]}"; do
      [[ "$kh" == "$h" ]] && is_enabled=1 && break
    done
    [[ "$is_enabled" == "1" ]] && continue
    fname=$(harness_agent_file "$kh") || continue
    # Skip if another enabled harness still uses this filename.
    local still_used=0
    for needed_filename in "${needed[@]}"; do
      [[ "$needed_filename" == "$fname" ]] && still_used=1 && break
    done
    [[ "$still_used" == "1" ]] && continue
    # Sweep INSTALL_DIR + each lane folder under SPECS_DIR.
    for lane_dir in "$INSTALL_DIR" "$SPECS_DIR/product" "$SPECS_DIR/design" \
                    "$SPECS_DIR/engineering" "$SPECS_DIR/qa" "$SPECS_DIR/roadmap"; do
      [[ ! -d "$lane_dir" ]] && continue
      local target="$lane_dir/$fname"
      if [[ -L "$target" ]]; then
        rm "$target"
        green "Removed stale $fname at $lane_dir (harness '$kh' no longer enabled)"
        CREATED=$((CREATED + 1))
      elif [[ -f "$target" ]]; then
        # Heuristic for claude's CLAUDE.md wrapper: if the file is a one-liner
        # `@.../AGENTS.md` or `@.../CLAUDE.md`, treat it as pdeq-managed.
        if [[ "$kh" == "claude" ]] && head -n 1 "$target" 2>/dev/null \
             | grep -qE '^@.*\.pdeq.*/(AGENTS|CLAUDE)\.md$'; then
          rm "$target"
          green "Removed stale $fname at $lane_dir (harness 'claude' no longer enabled)"
          CREATED=$((CREATED + 1))
        fi
        # Otherwise consumer-authored — leave alone.
      fi
    done
  done
  # Also remove .claude/commands/ symlinks if claude is disabled.
  if [[ ! " ${HARNESSES_ARR[*]} " =~ " claude " ]]; then
    local claude_cmd_dir="$GIT_ROOT/.claude/commands"
    if [[ -d "$claude_cmd_dir" ]]; then
      local f
      for f in "$claude_cmd_dir"/pdeq-*.md; do
        [[ ! -L "$f" ]] && continue
        # Confirm symlink target points at pdeq before removing
        local link_target
        link_target=$(readlink "$f")
        if [[ "$link_target" == *"$PDEQ_DIR/pdeq-rules/commands/"* ]]; then
          rm "$f"
          green "Removed stale $(basename "$f") (harness 'claude' no longer enabled)"
          CREATED=$((CREATED + 1))
        fi
      done
    fi
  fi
  return 0
}

# Compute the relative path depth from INSTALL_DIR back to GIT_ROOT
# Used to build correct @ import prefixes for AGENTS.md files
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
  if [[ -z "$OPT_HARNESSES" ]]; then
    prompt "Coding-agent harnesses (comma-separated, recognized: claude, codex, pi — default 'claude')"
    read -r OPT_HARNESSES
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

# Resolve and validate the harness list BEFORE any filesystem writes so an
# unknown harness exits cleanly without leaving a half-finished install.
resolve_harnesses
validate_harnesses
info "Harnesses: ${HARNESSES_ARR[*]}"

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

# Build the import prefix for functional area AGENTS.md files:
# "relative path from SPECS_DIR up to GIT_ROOT" + "/$PDEQ_DIR"
# Used by both Claude (@import) and non-Claude (symlink target) harnesses.
if [[ "$SPECS_DIR" == "$GIT_ROOT" ]]; then
  PDEQ_IMPORT_PREFIX="$PDEQ_DIR"
else
  UP="$(_rel_depth "$SPECS_DIR" "$GIT_ROOT")"
  PDEQ_IMPORT_PREFIX="$UP/$PDEQ_DIR"
fi

# Root-level import (relative from INSTALL_DIR back to the submodule):
if [[ "$INSTALL_DIR" == "$GIT_ROOT" ]]; then
  ROOT_AGENTS_IMPORT="$PDEQ_DIR/AGENTS.md"
else
  UP="$(_rel_depth "$INSTALL_DIR" "$GIT_ROOT")"
  ROOT_AGENTS_IMPORT="$UP/$PDEQ_DIR/AGENTS.md"
fi

# ---------------------------------------------------------------------------
# Step 3: Create functional area directories + per-harness agent-file imports
# ---------------------------------------------------------------------------
# Implements: FR-harness-agnostic-per-harness-install
for area in product design engineering qa roadmap; do
  areadir="$SPECS_DIR/$area"
  mkdir -p "$areadir"
  _materialize_agent_file "$areadir" "$PDEQ_IMPORT_PREFIX/$area/AGENTS.md" "$area"
done

# ---------------------------------------------------------------------------
# Step 4: Root agent file(s) (in INSTALL_DIR)
# ---------------------------------------------------------------------------
# Implements: FR-harness-agnostic-per-harness-install
# Root files get a fuller template for Claude (with a "Project-Specific
# Instructions" section the consumer can extend) and a plain symlink for
# other harnesses, since AGENTS.md can't carry @import-style directives.
for h in "${HARNESSES_ARR[@]}"; do
  fname=$(harness_agent_file "$h") || continue
  root_dest="$INSTALL_DIR/$fname"
  if [[ -e "$root_dest" || -L "$root_dest" ]]; then
    skip "$fname already exists (harness: $h)"
    ((SKIPPED++))
    continue
  fi
  if [[ "$h" == "claude" ]]; then
    cat > "$root_dest" << HEREDOC
@$ROOT_AGENTS_IMPORT

## Project-Specific Instructions

<!-- Add any project-specific overrides or additions below.
     The line above imports the full PDEQ coordinator agent from the submodule.
     Anything you write here extends or overrides those instructions. -->
HEREDOC
  else
    ln -s "$ROOT_AGENTS_IMPORT" "$root_dest"
  fi
  green "Created $fname (harness: $h)"
  ((CREATED++))
done

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
# Step 6: Mirror slash commands per enabled harness
# ---------------------------------------------------------------------------
# Implements: FR-harness-agnostic-commands-per-harness
_materialize_commands

# ---------------------------------------------------------------------------
# Step 6b: Cleanup files from harnesses that were removed since last run
# ---------------------------------------------------------------------------
# Implements: FR-harness-agnostic-removed-harness-cleaned
_cleanup_removed_harnesses

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

  # Build harnesses JSON array from the resolved HARNESSES_ARR.
  # Implements: FR-harness-agnostic-config
  harnesses_json="["
  first=1
  for h in "${HARNESSES_ARR[@]}"; do
    if [[ "$first" == "1" ]]; then
      harnesses_json+="\"$h\""
      first=0
    else
      harnesses_json+=", \"$h\""
    fi
  done
  harnesses_json+="]"

  cat > "$PDEQ_CONFIG" << JSONEOF
{$version_line
  "specsRoot": "$OPT_SPECS_ROOT",
  "codeRoot": "$OPT_CODE_ROOT",
  "platforms": $platforms_json,
  "harnesses": $harnesses_json$nested_block
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
info "  3. Run /pdeq-bootstrap to generate draft specs from your existing code,"
info "     or /pdeq-kickoff to start your first feature from scratch"
info "  To update PDEQ later: git submodule update --remote $PDEQ_DIR"
printf '\n'
