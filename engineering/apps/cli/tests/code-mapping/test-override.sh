#!/usr/bin/env bash
# Tests for the PDEQ_ALLOW_DRIFT escape hatch: TC-code-mapping-override-demotes,
# TC-code-mapping-override-reports-suppressed.

test_override_demotes_orphan() {
  local f
  f=$(make_fixture)
  seed_product_spec "$f" "x" "FR-x-one"
  seed_index "$f" "FR-x-one"
  seed_marker "$f" "src/main.ts" "FR-x-bogus"
  local out status
  set +e
  out=$(PDEQ_ALLOW_DRIFT=1 run_audit "$f")
  status=$?
  set -e
  assert_exit_code 0 "$status" "override → exit 0"
  assert_contains "$out" "suppressed" "suppressed list emitted"
  assert_contains "$out" "FR-x-bogus" "the orphan is named in the suppression list"
}

test_override_reports_multiple_conditions() {
  local f
  f=$(make_fixture)
  seed_product_spec "$f" "x" "FR-x-one"
  seed_index "$f" "FR-x-one"
  seed_marker "$f" "src/main.ts" "FR-x-bogus"
  seed_code_map "$f" "engineering/cli/x.md" "FR-x-one" "src/missing.ts" "implemented"
  local out
  out=$(PDEQ_ALLOW_DRIFT=1 run_audit "$f")
  # Both conditions should appear as suppressed items.
  assert_contains "$out" "orphan marker" "orphan listed"
  assert_contains "$out" "src/missing.ts" "stale-path listed"
}
