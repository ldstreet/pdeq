#!/usr/bin/env bash
# Assertion helpers for code-mapping tests.
#
# Usage: source this file from each test script.
# Tests should emit PASS/FAIL lines via the assert_* helpers and rely on
# `set -e` to abort on first failure.

assert_eq() {
  local expected="$1"
  local actual="$2"
  local msg="${3:-}"
  if [ "$expected" = "$actual" ]; then
    return 0
  fi
  echo "  FAIL: assert_eq ${msg:+($msg) }expected=<$expected> actual=<$actual>" >&2
  return 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local msg="${3:-}"
  if [[ "$haystack" == *"$needle"* ]]; then
    return 0
  fi
  echo "  FAIL: assert_contains ${msg:+($msg) }needle=<$needle> not found in haystack:" >&2
  echo "$haystack" | head -20 | sed 's/^/    /' >&2
  return 1
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local msg="${3:-}"
  if [[ "$haystack" != *"$needle"* ]]; then
    return 0
  fi
  echo "  FAIL: assert_not_contains ${msg:+($msg) }needle=<$needle> unexpectedly found in haystack" >&2
  return 1
}

assert_exit_code() {
  local expected="$1"
  local actual="$2"
  local msg="${3:-}"
  if [ "$expected" -eq "$actual" ]; then
    return 0
  fi
  echo "  FAIL: assert_exit_code ${msg:+($msg) }expected=$expected actual=$actual" >&2
  return 1
}

assert_file_exists() {
  local path="$1"
  if [ -f "$path" ]; then
    return 0
  fi
  echo "  FAIL: assert_file_exists path=<$path>" >&2
  return 1
}

# assert_index_code_column SLUG EXPECTED_CELL INDEX_PATH
# Exact-match (after whitespace trim) on the Code cell of the slug's row.
assert_index_code_column() {
  local slug="$1"
  local expected="$2"
  local idx="$3"
  local row cell
  row=$(grep -F "| $slug |" "$idx" || true)
  if [ -z "$row" ]; then
    echo "  FAIL: assert_index_code_column slug=$slug not found in $idx" >&2
    return 1
  fi
  # Last cell is Code (5 columns); split on |
  cell=$(echo "$row" | awk -F'|' '{print $6}' | sed 's/^ *//; s/ *$//')
  if [ "$cell" = "$expected" ]; then
    return 0
  fi
  echo "  FAIL: assert_index_code_column slug=$slug expected=<$expected> actual=<$cell>" >&2
  return 1
}
