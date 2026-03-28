#!/usr/bin/env bash
#
# Merges pending decision entries into decisions.md.
#
# During a session, agents write new decisions to decisions-pending.md.
# This script appends those entries into decisions.md (above the template comment),
# clears the pending file, and stages both files.
#
# Called by the pre-commit hook. Can also be run manually.

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || dirname "$(dirname "$0")")"
DECISIONS="$ROOT/decisions.md"
PENDING="$ROOT/decisions-pending.md"

# Nothing to do if there's no pending file or it's empty/whitespace-only
if [ ! -f "$PENDING" ]; then
  exit 0
fi

content=$(cat "$PENDING")
# Strip leading/trailing whitespace and check if anything remains
trimmed=$(echo "$content" | sed '/^[[:space:]]*$/d')
if [ -z "$trimmed" ]; then
  rm -f "$PENDING"
  exit 0
fi

echo "Merging pending decisions into decisions.md..."

# Insert pending entries above the template comment at the end of decisions.md
if grep -q '^<!--' "$DECISIONS"; then
  # Find the line number of the first <!-- and insert before it
  insert_line=$(grep -n '^<!--' "$DECISIONS" | head -1 | cut -d: -f1)
  {
    head -n $((insert_line - 1)) "$DECISIONS"
    echo "$trimmed"
    echo ""
    tail -n +"$insert_line" "$DECISIONS"
  } > "$DECISIONS.tmp"
  mv "$DECISIONS.tmp" "$DECISIONS"
else
  # No template comment — just append
  echo "" >> "$DECISIONS"
  echo "$trimmed" >> "$DECISIONS"
fi

# Clear the pending file
rm -f "$PENDING"

# Stage the updated decisions.md (pending file removal is handled by .gitignore)
git add "$DECISIONS"

echo "  Merged $(echo "$trimmed" | grep -c '^## ' || echo "?") decision(s)."
