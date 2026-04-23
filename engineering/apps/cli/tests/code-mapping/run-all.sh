#!/usr/bin/env bash
#
# Code-mapping audit test runner.
#
# Discovers every test-*.sh file in this directory, sources it, and invokes
# each `test_*` function defined therein. Prints PASS / FAIL per test and a
# final summary. Exits non-zero if any test fails.
#
# Usage: ./engineering/apps/cli/tests/code-mapping/run-all.sh

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
export PDEQ_REPO_ROOT="$(cd "$HERE/../../../../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$HERE/lib/assert.sh"
# shellcheck source=lib/fixture.sh
source "$HERE/lib/fixture.sh"

total=0
passed=0
failed=()
start_time=$(date +%s)

for test_file in "$HERE"/test-*.sh; do
  [ -f "$test_file" ] || continue
  # shellcheck source=/dev/null
  source "$test_file"
done

# Run every defined function whose name starts with test_
for fn in $(declare -F | awk '{print $3}' | grep '^test_'); do
  total=$((total + 1))
  echo "→ $fn"
  fixture_scratch=""
  set +e
  ( "$fn" )
  status=$?
  set -e
  if [ "$status" -eq 0 ]; then
    passed=$((passed + 1))
    echo "  ✓ PASS"
  else
    failed+=("$fn")
    echo "  ✗ FAIL (exit $status)"
  fi
done

end_time=$(date +%s)
elapsed=$((end_time - start_time))

echo ""
echo "─────────────────────────────────"
echo "Ran $total tests in ${elapsed}s"
echo "Passed: $passed"
echo "Failed: ${#failed[@]}"
if [ ${#failed[@]} -gt 0 ]; then
  echo ""
  echo "Failures:"
  for fn in "${failed[@]}"; do
    echo "  - $fn"
  done
  exit 1
fi
exit 0
