#!/usr/bin/env bash
#
# Traceability auditor.
# Checks that requirement slugs are defined, indexed, and cross-referenced correctly.
#
# Exit codes:
#   0 — all checks pass
#   1 — one or more issues found
#
# Can be run standalone (./scripts/audit-traceability.sh) or as a git pre-commit hook.

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || dirname "$(dirname "$0")")"
INDEX="$ROOT/index.md"
PRODUCT_DIR="$ROOT/product"
DESIGN_DIR="$ROOT/design"
ENGINEERING_DIR="$ROOT/engineering"
QA_DIR="$ROOT/qa"

errors=()

warn() {
  errors+=("$1")
  echo "  ⚠  $1"
}

# ─── Helpers ────────────────────────────────────────────────────────────────

# Extract slug definitions from product/ files (FR-*, NFR-*, AC-* patterns).
# Looks for slugs in backticks or at the start of list items.
collect_defined_slugs() {
  local dir="$1"
  if [ ! -d "$dir" ]; then return; fi
  find "$dir" -name "*.md" -not -name "CLAUDE.md" -print0 2>/dev/null \
    | xargs -0 grep -hoP '`(FR-[a-z0-9-]+|NFR-[a-z0-9-]+|AC-[a-z0-9-]+)`' 2>/dev/null \
    | tr -d '`' | sort -u || true
}

# Extract all slug references from a directory (FR-*, NFR-*, AC-*, TC-*).
collect_referenced_slugs() {
  local dir="$1"
  if [ ! -d "$dir" ]; then return; fi
  find "$dir" -name "*.md" -not -name "CLAUDE.md" -print0 2>/dev/null \
    | xargs -0 grep -hoP '`(FR-[a-z0-9-]+|NFR-[a-z0-9-]+|AC-[a-z0-9-]+|TC-[a-z0-9-]+)`' 2>/dev/null \
    | tr -d '`' | sort -u || true
}

# Extract slugs listed in index.md
collect_indexed_slugs() {
  if [ ! -f "$INDEX" ]; then return; fi
  grep -oP '`(FR-[a-z0-9-]+|NFR-[a-z0-9-]+|AC-[a-z0-9-]+)`' "$INDEX" 2>/dev/null \
    | tr -d '`' | sort -u || true
}

# Extract file paths referenced in an index entry (paths inside backticks)
collect_indexed_paths() {
  if [ ! -f "$INDEX" ]; then return; fi
  grep -oP '`(product/|design/|engineering/|qa/)[^`]+`' "$INDEX" 2>/dev/null \
    | tr -d '`' | sort -u || true
}

# ─── Checks ─────────────────────────────────────────────────────────────────

echo "Auditing traceability..."
echo ""

# 1. Check that index.md exists
if [ ! -f "$INDEX" ]; then
  warn "index.md not found at project root"
  echo ""
  echo "Found ${#errors[@]} issue(s)."
  exit 1
fi

# 2. Collect slugs
defined_slugs=$(collect_defined_slugs "$PRODUCT_DIR")
indexed_slugs=$(collect_indexed_slugs)

# Collect references from downstream agents (not product — that's where they're defined)
design_refs=$(collect_referenced_slugs "$DESIGN_DIR")
engineering_refs=$(collect_referenced_slugs "$ENGINEERING_DIR")
qa_refs=$(collect_referenced_slugs "$QA_DIR")

# Also check code comments for slug references
code_refs=""
for code_dir in "$ENGINEERING_DIR/apps" "$ENGINEERING_DIR/src"; do
  if [ -d "$code_dir" ]; then
    dir_refs=$(grep -rhoP '(FR-[a-z0-9-]+|NFR-[a-z0-9-]+|AC-[a-z0-9-]+)' "$code_dir" 2>/dev/null | sort -u || true)
    code_refs=$(echo -e "${code_refs}\n${dir_refs}" | grep -v '^$' | sort -u || true)
  fi
done

all_downstream_refs=$(echo -e "${design_refs}\n${engineering_refs}\n${qa_refs}\n${code_refs}" | grep -v '^$' | sort -u || true)

# 3. Check: every defined slug should be in the index
if [ -n "$defined_slugs" ]; then
  echo "[1/4] Defined slugs present in index..."
  while IFS= read -r slug; do
    if ! echo "$indexed_slugs" | grep -qx "$slug"; then
      warn "$slug defined in product/ but missing from index.md"
    fi
  done <<< "$defined_slugs"
  echo ""
fi

# 4. Check: every downstream reference should be defined in product/
if [ -n "$all_downstream_refs" ]; then
  echo "[2/4] Downstream references have definitions..."
  while IFS= read -r slug; do
    # Skip TC- slugs — they're defined in QA, not product
    if [[ "$slug" == TC-* ]]; then continue; fi
    if [ -n "$defined_slugs" ] && echo "$defined_slugs" | grep -qx "$slug"; then
      continue
    fi
    warn "$slug referenced downstream but not defined in product/"
  done <<< "$all_downstream_refs"
  echo ""
fi

# 5. Check: every downstream reference should be in the index
if [ -n "$all_downstream_refs" ]; then
  echo "[3/4] Downstream references present in index..."
  while IFS= read -r slug; do
    # Skip TC- slugs from this check
    if [[ "$slug" == TC-* ]]; then continue; fi
    if [ -n "$indexed_slugs" ] && echo "$indexed_slugs" | grep -qx "$slug"; then
      continue
    fi
    warn "$slug referenced downstream but missing from index.md"
  done <<< "$all_downstream_refs"
  echo ""
fi

# 6. Check: file paths in index.md point to real files
echo "[4/4] Index file paths exist..."
indexed_paths=$(collect_indexed_paths)
if [ -n "$indexed_paths" ]; then
  while IFS= read -r filepath; do
    if [ ! -f "$ROOT/$filepath" ]; then
      warn "index.md references $filepath but file does not exist"
    fi
  done <<< "$indexed_paths"
fi
echo ""

# ─── Summary ─────────────────────────────────────────────────────────────────

if [ ${#errors[@]} -eq 0 ]; then
  echo "✓ All traceability checks passed."
  exit 0
else
  echo "✗ Found ${#errors[@]} traceability issue(s). Fix them before committing."
  exit 1
fi
