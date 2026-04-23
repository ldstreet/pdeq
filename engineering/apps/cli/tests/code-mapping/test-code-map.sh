#!/usr/bin/env bash
# Tests for Code Map parsing + phase 7 validation: TC-code-mapping-stale-path-blocks,
# TC-code-mapping-unimplemented-exempt, TC-code-mapping-implemented-status-no-marker.

test_stale_path_blocks() {
  local f
  f=$(make_fixture)
  seed_product_spec "$f" "x" "FR-x-one"
  seed_index "$f" "FR-x-one"
  seed_code_map "$f" "engineering/cli/x.md" "FR-x-one" "src/deleted.ts" "implemented"
  local out status
  out=$(run_audit "$f" || true)
  assert_contains "$out" "src/deleted.ts" "stale path named"
  assert_contains "$out" "implemented" "status context included"
}

test_unimplemented_exempt() {
  local f
  f=$(make_fixture)
  seed_product_spec "$f" "x" "FR-x-one"
  seed_index "$f" "FR-x-one"
  seed_code_map "$f" "engineering/cli/x.md" "FR-x-one" "—" "unimplemented"
  local out
  out=$(run_audit "$f" 2>&1)
  assert_contains "$out" "All traceability checks passed" "unimplemented exempts FR from coverage"
  assert_not_contains "$out" "has no marker" "no uncovered warning"
}

test_implemented_without_marker_blocks() {
  local f
  f=$(make_fixture)
  seed_product_spec "$f" "x" "FR-x-one"
  seed_index "$f" "FR-x-one"
  # File exists but has no marker; Code Map claims implemented.
  echo "// placeholder" > "$f/src/main.ts"
  seed_code_map "$f" "engineering/cli/x.md" "FR-x-one" "src/main.ts" "implemented"
  local out
  out=$(run_audit "$f" || true)
  assert_contains "$out" "implemented but no marker" "drift surfaced"
}

test_code_map_planned_tolerates_missing_file() {
  local f
  f=$(make_fixture)
  seed_product_spec "$f" "x" "FR-x-one"
  seed_index "$f" "FR-x-one"
  # Status `planned` with a path that doesn't exist yet — must not block.
  seed_code_map "$f" "engineering/cli/x.md" "FR-x-one" "src/future.ts" "planned"
  local out
  out=$(run_audit "$f" 2>&1)
  # Without a git fixture grace_delta returns 0, full grace; audit passes.
  assert_contains "$out" "All traceability checks passed" "planned row is aspirational"
}
