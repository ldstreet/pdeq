#!/usr/bin/env bash
set -euo pipefail

# PDEQ bootstrap script
# Orchestrates the full bootstrap flow for importing an existing codebase into PDEQ.
#
# This script is the shell-side half of the /bootstrap command. It validates
# preconditions and resolves paths before Claude agents take over.
#
# Usage:
#   ./scripts/bootstrap.sh [--dry-run] [--feature <name>]
#
# Flags:
#   --dry-run             Analyze only; no spec files are written
#   --feature <name>      Scope bootstrap to a single feature area

DRY_RUN=0
FEATURE=""

green() { printf '\033[0;32m✓\033[0m %s\n' "$*"; }
info()  { printf '  %s\n' "$*"; }
warn()  { printf '\033[0;33m!\033[0m %s\n' "$*"; }
err()   { printf '\033[0;31m✗\033[0m %s\n' "$*" >&2; }

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)        DRY_RUN=1;         shift ;;
    --feature)        FEATURE="$2";      shift 2 ;;
    -*)
      err "Unknown flag: $1"
      echo "Usage: $0 [--dry-run] [--feature <name>]"
      exit 1
      ;;
    *) shift ;;
  esac
done

# ---------------------------------------------------------------------------
# Resolve paths from pdeq.json (if present) or defaults
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Scripts live at {git-root}/scripts/ — parent is git root
GIT_ROOT="$(dirname "$SCRIPT_DIR")"

PDEQ_CONFIG="$GIT_ROOT/pdeq.json"
SPECS_ROOT="$GIT_ROOT"
CODE_ROOT="$GIT_ROOT"

if [[ -f "$PDEQ_CONFIG" ]]; then
  # Parse pdeq.json with python (available on macOS/Linux) or node as fallback
  if command -v python3 &>/dev/null; then
    SPECS_ROOT_REL=$(python3 -c "import json,sys; d=json.load(open('$PDEQ_CONFIG')); print(d.get('specsRoot','.'))" 2>/dev/null || echo ".")
    CODE_ROOT_REL=$(python3 -c "import json,sys; d=json.load(open('$PDEQ_CONFIG')); print(d.get('codeRoot','.'))" 2>/dev/null || echo ".")
  elif command -v node &>/dev/null; then
    SPECS_ROOT_REL=$(node -e "const d=require('$PDEQ_CONFIG'); process.stdout.write(d.specsRoot||'.')" 2>/dev/null || echo ".")
    CODE_ROOT_REL=$(node -e "const d=require('$PDEQ_CONFIG'); process.stdout.write(d.codeRoot||'.')" 2>/dev/null || echo ".")
  else
    warn "python3/node not found — cannot parse pdeq.json; using defaults"
    SPECS_ROOT_REL="."
    CODE_ROOT_REL="."
  fi
  SPECS_ROOT="$(cd "$GIT_ROOT/$SPECS_ROOT_REL" && pwd)"
  CODE_ROOT="$(cd "$GIT_ROOT/$CODE_ROOT_REL" && pwd)"
  green "Loaded pdeq.json"
  info "  specsRoot → $SPECS_ROOT"
  info "  codeRoot  → $CODE_ROOT"
else
  info "No pdeq.json found — using defaults (specsRoot=., codeRoot=.)"
fi

# ---------------------------------------------------------------------------
# Precondition checks
# ---------------------------------------------------------------------------
if [[ ! -d "$CODE_ROOT" ]]; then
  err "codeRoot '$CODE_ROOT' does not exist"
  exit 1
fi

if [[ ! -d "$SPECS_ROOT/product" ]]; then
  err "Specs directory not found at '$SPECS_ROOT'. Run scripts/init.sh first."
  exit 1
fi

# ---------------------------------------------------------------------------
# Check for existing bootstrap-analysis.md
# ---------------------------------------------------------------------------
ANALYSIS_FILE="$SPECS_ROOT/bootstrap-analysis.md"

if [[ -f "$ANALYSIS_FILE" ]]; then
  warn "bootstrap-analysis.md already exists at $ANALYSIS_FILE"
  info "Delete it to re-run the analyzer, or proceed directly to the generator."
  printf '\n'
fi

# ---------------------------------------------------------------------------
# Print configuration summary
# ---------------------------------------------------------------------------
printf '\n'
info "Bootstrap configuration:"
info "  Specs root:  $SPECS_ROOT"
info "  Code root:   $CODE_ROOT"
if [[ -n "$FEATURE" ]]; then
  info "  Scoped to:   $FEATURE"
fi
if [[ "$DRY_RUN" == "1" ]]; then
  info "  Mode:        DRY RUN (no files will be written)"
fi
printf '\n'

# ---------------------------------------------------------------------------
# Export env vars for Claude agents to consume
# ---------------------------------------------------------------------------
export PDEQ_SPECS_ROOT="$SPECS_ROOT"
export PDEQ_CODE_ROOT="$CODE_ROOT"
export PDEQ_DRY_RUN="$DRY_RUN"
export PDEQ_FEATURE="$FEATURE"

green "Bootstrap preconditions OK"
info "Hand-off to /bootstrap command for agent orchestration."
printf '\n'
info "The /bootstrap command will:"
info "  1. Spawn the bootstrap-analyzer against $CODE_ROOT"
info "  2. Show you a summary and ask for confirmation"
info "  3. Spawn the bootstrap-generator to write draft specs"
info "  4. Run audit-traceability.sh and audit-lanes.sh"
info "  5. Print bootstrap-summary.md"
printf '\n'
