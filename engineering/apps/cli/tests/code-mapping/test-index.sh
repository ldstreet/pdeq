#!/usr/bin/env bash
# Tests for phase 9 Code column rewrite: TC-code-mapping-index-populated,
# TC-code-mapping-index-removes-stale, TC-code-mapping-deterministic-two-runs.

test_index_code_column_populated() {
  local f
  f=$(make_fixture)
  seed_product_spec "$f" "x" "FR-x-one"
  seed_index "$f" "FR-x-one"
  seed_marker "$f" "src/main.ts" "FR-x-one"
  run_audit "$f" > /dev/null
  assert_index_code_column "FR-x-one" "src/main.ts:1" "$f/index.md"
  # Header gained a Code column.
  assert_contains "$(head -25 "$f/index.md")" "| Code |" "header includes Code column"
}

test_index_removes_stale() {
  local f
  f=$(make_fixture)
  seed_product_spec "$f" "x" "FR-x-one"
  seed_index "$f" "FR-x-one"
  seed_marker "$f" "src/main.ts" "FR-x-one"
  run_audit "$f" > /dev/null
  assert_index_code_column "FR-x-one" "src/main.ts:1" "$f/index.md"
  # Remove the marker and rerun; the entry should drop.
  rm "$f/src/main.ts"
  run_audit "$f" > /dev/null 2>&1 || true
  assert_index_code_column "FR-x-one" "" "$f/index.md"
}

test_deterministic_two_runs() {
  local f
  f=$(make_fixture)
  seed_product_spec "$f" "x" "FR-x-one" "FR-x-two"
  seed_index "$f" "FR-x-one" "FR-x-two"
  seed_marker "$f" "src/a.ts" "FR-x-one"
  seed_marker "$f" "src/b.ts" "FR-x-two"
  local run1 run2
  run1=$(run_audit "$f")
  cp "$f/index.md" "$f/index.md.run1"
  run2=$(run_audit "$f")
  diff -q "$f/index.md" "$f/index.md.run1" > /dev/null
  assert_eq "$run1" "$run2" "stderr byte-identical across two runs"
}
