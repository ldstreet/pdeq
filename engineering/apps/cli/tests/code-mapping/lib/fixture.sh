#!/usr/bin/env bash
# Fixture builder helpers for code-mapping tests.
#
# make_fixture [git]
#   Creates a fresh mktemp directory, seeded with the minimum files the audit
#   expects (pdeq.json, empty index.md header, empty product/ dir). Returns
#   absolute path on stdout.
#   If "git" is passed, initializes the directory as a git repository and
#   makes an initial commit. Required for grace-period and retirement tests.
#
# seed_product_spec <fixture> <feature> <slugs_space_separated>
#   Writes product/<feature>.md with a heading and one bullet per slug.
#   Each slug is wrapped in backticks so collect_defined_slugs finds it.
#
# seed_index <fixture> <slugs_space_separated>
#   Writes index.md with a standard header and one row per slug (Type/defined-in
#   derived from slug prefix + feature). Code column starts empty.
#
# seed_marker <fixture> <relative-file> <slug> [<line_comment_prefix>]
#   Appends an Implements: marker to the given file in the fixture. Prefix
#   defaults to `//`.
#
# seed_code_map <fixture> <engineering-spec> <slug> <location> <status>
#   Appends one row to the `## Code Map` table of the engineering spec,
#   creating the file + heading if absent.
#
# commit_fixture <fixture> <message>
#   Adds all changes in the fixture to its git index and commits with the
#   given message. Requires the fixture was created with `make_fixture git`.

make_fixture() {
  local dir
  dir=$(mktemp -d 2>/dev/null || mktemp -d -t code-mapping-fixture)
  mkdir -p "$dir/product" "$dir/engineering" "$dir/engineering/cli"
  cat > "$dir/pdeq.json" << 'JSON'
{
  "pdeqVersion": "0.2.0",
  "specsRoot": ".",
  "codeRoot": ".",
  "platforms": ["cli"],
  "selfHost": true
}
JSON
  cat > "$dir/index.md" << 'MD'
# Traceability Index

## Index

| Slug | Type | Defined In | Referenced In |
|------|------|------------|---------------|
MD
  # Always git-init so the audit's `git rev-parse --show-toplevel` resolves to
  # the fixture directory, not the pdeq repo that actually owns the audit script.
  git -C "$dir" init -q
  git -C "$dir" config user.email test@pdeq
  git -C "$dir" config user.name test
  if [ "${1:-}" = "git" ]; then
    # "git" mode: seed an initial commit so git log works for grace-period tests.
    git -C "$dir" commit --allow-empty -qm "init"
  fi
  echo "$dir"
}

seed_product_spec() {
  local fixture="$1"
  local feature="$2"
  shift 2
  local slugs=("$@")
  local file="$fixture/product/$feature.md"
  {
    echo "# $feature"
    echo ""
    echo "## Requirements"
    echo ""
    for slug in "${slugs[@]}"; do
      echo "- **$slug** \`$slug\`: placeholder description."
    done
  } > "$file"
}

seed_index() {
  local fixture="$1"
  shift
  local slugs=("$@")
  local idx="$fixture/index.md"
  for slug in "${slugs[@]}"; do
    local type feature
    type="${slug%%-*}"
    feature=$(echo "$slug" | sed -E 's/^(FR|NFR|AC)-//; s/-.*$//')
    echo "| $slug | $type | product/$feature.md | |" >> "$idx"
  done
}

seed_marker() {
  local fixture="$1"
  local relfile="$2"
  local slug="$3"
  local prefix="${4:-//}"
  local abspath="$fixture/$relfile"
  mkdir -p "$(dirname "$abspath")"
  # Choose a line-comment-safe form. HTML comment gets an explicit closing.
  case "$prefix" in
    "<!--")
      echo "<!-- Implements: $slug -->" >> "$abspath"
      ;;
    *)
      echo "$prefix Implements: $slug" >> "$abspath"
      ;;
  esac
}

seed_code_map() {
  local fixture="$1"
  local relspec="$2"
  local slug="$3"
  local loc="$4"
  local status="$5"
  local spec="$fixture/$relspec"
  mkdir -p "$(dirname "$spec")"
  if ! grep -q '^## Code Map' "$spec" 2>/dev/null; then
    {
      echo "# Engineering Spec"
      echo ""
      echo "## Code Map"
      echo ""
      echo "| Slug | Planned location | Status |"
      echo "|---|---|---|"
    } >> "$spec"
  fi
  echo "| $slug | $loc | $status |" >> "$spec"
}

commit_fixture() {
  local fixture="$1"
  local msg="$2"
  git -C "$fixture" add -A
  git -C "$fixture" commit -qm "$msg"
}

# Run the audit against a fixture. Emits stderr to stdout for easy assertion.
run_audit() {
  local fixture="$1"
  shift
  (cd "$fixture" && PDEQ_CONFIG_PATH="$fixture/pdeq.json" "$PDEQ_REPO_ROOT/scripts/audit-traceability.sh" "$@" 2>&1)
}
