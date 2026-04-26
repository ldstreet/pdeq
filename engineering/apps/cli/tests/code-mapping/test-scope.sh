#!/usr/bin/env bash
# Tests for Phase 5b marker scope rule:
# TC-code-mapping-scope-flagged, TC-code-mapping-scope-on-function-passes,
# TC-code-mapping-scope-inside-short-body,
# TC-code-mapping-scope-above-first-decl-warns,
# TC-code-mapping-scope-no-decl-no-warn.
# Sourced by run-all.sh — do not execute directly.

# Existing happy path: marker on the line immediately above a function decl.
test_scope_on_function_passes() {
  local f
  f=$(make_fixture)
  seed_product_spec "$f" "x" "FR-x-one"
  seed_index "$f" "FR-x-one"
  mkdir -p "$f/src"
  # Pad with blank/import lines so the function decl lands at line 12 and the
  # marker on line 11 — matches the QA spec fixture description.
  cat > "$f/src/main.ts" << 'TS'
// pad 1
// pad 2
// pad 3
// pad 4
// pad 5
// pad 6
// pad 7
// pad 8
// pad 9
// pad 10
// Implements: FR-x-one
export function doThing() { return 1; }
TS
  local out
  out=$(run_audit "$f" 2>&1)
  assert_not_contains "$out" "implementing unit" "no scope warning when marker is immediately above function"
  assert_index_code_column "FR-x-one" "src/main.ts:11" "$f/index.md"
}

# False-positive regression test: function declaration starts on line 1, marker
# sits inside the body on line 3 — should NOT warn even though the marker line
# is small. This is the case the prior `line <= 5` heuristic broke.
test_scope_inside_short_body() {
  local f
  f=$(make_fixture)
  seed_product_spec "$f" "x" "FR-x-one"
  seed_index "$f" "FR-x-one"
  mkdir -p "$f/src"
  cat > "$f/src/Loading.tsx" << 'TSX'
export function DiffLoadingState() {

  // Implements: FR-x-one
  return null;
}
TSX
  local out
  out=$(run_audit "$f" 2>&1)
  assert_not_contains "$out" "implementing unit" "marker inside short body must not be flagged"
  assert_index_code_column "FR-x-one" "src/Loading.tsx:3" "$f/index.md"
}

# Genuine file-top antipattern: marker on line 1, first declaration on line 5
# (gap > 1). Must warn; flagged marker is not counted toward coverage.
test_scope_above_first_decl_warns() {
  local f
  f=$(make_fixture)
  seed_product_spec "$f" "x" "FR-x-one"
  seed_index "$f" "FR-x-one"
  mkdir -p "$f/src"
  cat > "$f/src/header.ts" << 'TS'
// Implements: FR-x-one
import a from "a";
import b from "b";
import c from "c";
export function foo() { return 1; }
TS
  local out
  out=$(run_audit "$f" 2>&1 || true)
  assert_contains "$out" "implementing unit" "warn when marker precedes first decl with gap > 1"
  assert_contains "$out" "src/header.ts:1" "warning cites file:line"
  # Pin the new wording so a future regression to a line-number heuristic is caught.
  assert_contains "$out" "marker above first named unit" "uses first-declaration-line wording"
}

# Function-capable extension but no declaration in the file at all → exempt.
# The scope rule does not apply when there is nothing to anchor against.
test_scope_no_decl_no_warn() {
  local f
  f=$(make_fixture)
  seed_product_spec "$f" "x" "FR-x-one"
  seed_index "$f" "FR-x-one"
  mkdir -p "$f/src"
  cat > "$f/src/top-level-only.ts" << 'TS'
// Implements: FR-x-one
console.log("top-level only, no function or class");
TS
  local out
  out=$(run_audit "$f" 2>&1)
  assert_not_contains "$out" "implementing unit" "no decl in file = no scope warning"
  assert_index_code_column "FR-x-one" "src/top-level-only.ts:1" "$f/index.md"
}
