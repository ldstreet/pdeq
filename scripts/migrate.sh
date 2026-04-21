#!/usr/bin/env bash
#
# pdeq migrate — version math, file discovery, parsing, and version bump.
#
# Deterministic subcommands invoked by the /migrate slash command orchestrator.
# Every subcommand is non-interactive, prints to stdout for machine-readable
# output, stderr for human-readable logs, and exits non-zero on error.
#
# Subcommands:
#   recorded                           Print pdeqVersion from pdeq.json (empty if absent).
#   pinned                             Print pinned pdeq version (reads VERSION).
#   list-pending                       Print pending migration versions, ascending.
#   parse <file>                       Print frontmatter + section TOC for a migration.
#   bump <version>                     Write pdeqVersion back to pdeq.json.
#   check-lineage                      Verify recorded version lives in pinned lineage.
#   lineage-breaking <from> <to>       Breaking versions in the (from, to] window.
#   audit-scope <migration>            Post-run scope-compliance check.
#
# Env overrides (all optional):
#   PDEQ_CONFIG_PATH      pdeq.json path. Default ./pdeq.json.
#   PDEQ_MIGRATIONS_DIR   migrations directory. Auto-detects:
#                           ./migrations (pdeq-repo context)
#                           .pdeq/migrations (consumer context)
#   PDEQ_SPECS_ROOT       specs root for audit-scope defaults. Default: specsRoot
#                         field in pdeq.json, or `.`.
#   PDEQ_LINEAGE_FILE     newline-delimited list of versions treated as in-lineage
#                         by check-lineage. Default: `git -C .pdeq tag --list`.

set -euo pipefail

# ─── Resolution ─────────────────────────────────────────────────────────────

CONFIG_PATH="${PDEQ_CONFIG_PATH:-./pdeq.json}"

# Migrations directory auto-detect: .pdeq/migrations if it exists, else migrations.
if [[ -n "${PDEQ_MIGRATIONS_DIR:-}" ]]; then
  MIGRATIONS_DIR="$PDEQ_MIGRATIONS_DIR"
elif [[ -d ".pdeq/migrations" ]]; then
  MIGRATIONS_DIR=".pdeq/migrations"
else
  MIGRATIONS_DIR="migrations"
fi

# Pinned VERSION file auto-detect: .pdeq/VERSION (consumer) else ./VERSION (repo).
pinned_file() {
  if [[ -f ".pdeq/VERSION" ]]; then
    echo ".pdeq/VERSION"
  else
    echo "VERSION"
  fi
}

err()  { echo "migrate.sh: $*" >&2; }
die()  { err "$*"; exit 2; }

# ─── Version helpers ────────────────────────────────────────────────────────

SEMVER_RE='^[0-9]+\.[0-9]+\.[0-9]+$'

is_semver() {
  [[ "$1" =~ $SEMVER_RE ]]
}

# semver_cmp A B -> echoes -1 if A<B, 0 if equal, 1 if A>B. Pure sort -V.
semver_cmp() {
  local a="$1" b="$2"
  if [[ "$a" == "$b" ]]; then echo 0; return; fi
  local first
  first=$(printf '%s\n%s\n' "$a" "$b" | sort -V | head -n 1)
  if [[ "$first" == "$a" ]]; then echo -1; else echo 1; fi
}

# major_minor X.Y.Z -> "X.Y"
major_minor() {
  echo "$1" | awk -F. '{ print $1 "." $2 }'
}

# ─── recorded ────────────────────────────────────────────────────────────────
#
# Read pdeqVersion from pdeq.json. Empty output if the file or field is absent.

cmd_recorded() {
  [[ -f "$CONFIG_PATH" ]] || { echo ""; return; }
  # Tolerant match — field can appear anywhere on a line, not just after
  # leading whitespace. Covers both pretty-printed and minified pdeq.json.
  sed -n 's/.*"pdeqVersion"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
    "$CONFIG_PATH" | head -n 1
}

# ─── pinned ──────────────────────────────────────────────────────────────────
#
# Read single-line semver from the VERSION file.

cmd_pinned() {
  local f
  f=$(pinned_file)
  [[ -f "$f" ]] || die "no VERSION file at $f"
  head -n 1 "$f" | tr -d '[:space:]'
}

# ─── list-pending ───────────────────────────────────────────────────────────
#
# Enumerate migration files in $MIGRATIONS_DIR with:
#   version > recorded AND version <= pinned
# Sorted ascending. Exits 2 on malformed filename (author mistake).
# Skips TEMPLATE.md, README.md, and filenames starting with `_`.

cmd_list_pending() {
  [[ -d "$MIGRATIONS_DIR" ]] || return 0
  local recorded pinned v base
  recorded=$(cmd_recorded)
  pinned=$(cmd_pinned)

  [[ -z "$recorded" ]] && die "pdeqVersion absent in $CONFIG_PATH"

  local out=()
  shopt -s nullglob
  for f in "$MIGRATIONS_DIR"/*.md; do
    base=$(basename "$f" .md)
    # Skip authoring aids.
    if [[ "$base" == "TEMPLATE" || "$base" == "README" || "$base" == _* ]]; then
      continue
    fi
    is_semver "$base" || die "malformed migration filename: $f"
    v="$base"
    # v > recorded AND v <= pinned
    if [[ "$(semver_cmp "$v" "$recorded")" == "1" \
       && "$(semver_cmp "$v" "$pinned")" != "1" ]]; then
      out+=("$v")
    fi
  done
  shopt -u nullglob

  if ((${#out[@]})); then
    printf '%s\n' "${out[@]}" | sort -V
  fi
}

# ─── parse ──────────────────────────────────────────────────────────────────
#
# Emit a deterministic summary of a migration file:
#   target-version: X.Y.Z
#   breaking: true|false
#   summary: <one line>
#   scope: default | <first glob>
#   has-mechanical: true|false
#   has-semantic: true|false
#   semantic-files: <space-separated globs> (only if has-semantic)
#
# Validates frontmatter target-version matches filename stem.

cmd_parse() {
  local file="$1"
  [[ -f "$file" ]] || die "no such file: $file"

  local base
  base=$(basename "$file" .md)
  is_semver "$base" || die "filename not semver: $file"

  # Extract frontmatter (lines between first and second --- markers).
  local fm
  fm=$(awk '
    /^---[[:space:]]*$/ { c++; if (c==2) exit; next }
    c==1 { print }
  ' "$file")

  local target breaking summary scope
  target=$(sed -n 's/^[[:space:]]*target-version:[[:space:]]*\(.*[^[:space:]]\)[[:space:]]*$/\1/p' <<<"$fm" | head -n 1)
  breaking=$(sed -n 's/^[[:space:]]*breaking:[[:space:]]*\(.*[^[:space:]]\)[[:space:]]*$/\1/p' <<<"$fm" | head -n 1)
  summary=$(sed -n 's/^[[:space:]]*summary:[[:space:]]*\(.*[^[:space:]]\)[[:space:]]*$/\1/p' <<<"$fm" | head -n 1)
  scope=$(sed -n 's/^[[:space:]]*scope:[[:space:]]*\(.*[^[:space:]]\)[[:space:]]*$/\1/p' <<<"$fm" | head -n 1)

  [[ -z "$target" ]] && die "parse: missing target-version in $file"
  [[ "$target" == "$base" ]] || die "parse: target-version $target != filename $base"
  [[ -z "$breaking" ]] && breaking="true"
  [[ -z "$scope" ]] && scope="default"

  # Section presence. H2 vocabulary.
  local has_mech=false has_sem=false
  if grep -qE '^##[[:space:]]+Mechanical[[:space:]]*$' "$file"; then has_mech=true; fi
  if grep -qE '^##[[:space:]]+Semantic[[:space:]]*$' "$file"; then has_sem=true; fi

  echo "target-version: $target"
  echo "breaking: $breaking"
  echo "summary: $summary"
  echo "scope: $scope"
  echo "has-mechanical: $has_mech"
  echo "has-semantic: $has_sem"

  if [[ "$has_sem" == "true" ]]; then
    # Collect bullets under ### Files subsection within ## Semantic.
    local files
    files=$(awk '
      /^##[[:space:]]+Semantic[[:space:]]*$/ { in_sem=1; next }
      /^##[[:space:]]+/ { in_sem=0; in_files=0 }
      in_sem && /^###[[:space:]]+Files[[:space:]]*$/ { in_files=1; next }
      in_sem && /^###[[:space:]]+/ { in_files=0 }
      in_files && /^-[[:space:]]+/ {
        sub(/^-[[:space:]]+/, "")
        gsub(/`/, "")
        sub(/[[:space:]]+$/, "")
        print
      }
    ' "$file" | tr '\n' ' ' | sed 's/[[:space:]]*$//')
    echo "semantic-files: $files"
  fi
}

# ─── bump ───────────────────────────────────────────────────────────────────
#
# Write pdeqVersion back to pdeq.json. Fails if target is older than recorded.
# Creates the file if missing. Inserts the field if absent. Rewrites in place
# if present. Atomic via temp file + mv.

cmd_bump() {
  local target="$1"
  is_semver "$target" || die "bump: not semver: $target"

  local recorded
  recorded=$(cmd_recorded)
  if [[ -n "$recorded" ]]; then
    if [[ "$(semver_cmp "$target" "$recorded")" == "-1" ]]; then
      die "bump: target $target < recorded $recorded (regression refused)"
    fi
  fi

  if [[ ! -f "$CONFIG_PATH" ]]; then
    printf '{\n  "pdeqVersion": "%s"\n}\n' "$target" > "$CONFIG_PATH"
    return
  fi

  local tmp="$CONFIG_PATH.migrate-tmp"
  if grep -qE '"pdeqVersion"[[:space:]]*:' "$CONFIG_PATH"; then
    # Field present — rewrite in place. Tolerant of inline JSON.
    sed 's/\("pdeqVersion"[[:space:]]*:[[:space:]]*\)"[^"]*"/\1"'"$target"'"/' \
      "$CONFIG_PATH" > "$tmp"
  else
    # Field absent — inject as first property after the opening `{`.
    awk -v ver="$target" '
      BEGIN { injected = 0 }
      !injected && /\{/ {
        pos = index($0, "{")
        before = substr($0, 1, pos)
        after  = substr($0, pos + 1)
        print before
        printf("  \"pdeqVersion\": \"%s\",\n", ver)
        if (after !~ /^[[:space:]]*$/) print after
        injected = 1
        next
      }
      { print }
    ' "$CONFIG_PATH" > "$tmp"
  fi
  mv "$tmp" "$CONFIG_PATH"
}

# ─── check-lineage ──────────────────────────────────────────────────────────
#
# Verify recorded version appears in the pinned pdeq's tag history. Exit 0 on
# match, non-zero otherwise. If PDEQ_LINEAGE_FILE is set, use its contents
# (newline-delimited version list) instead of git tags.
#
# Special case: if no .pdeq submodule exists AND PDEQ_LINEAGE_FILE is unset,
# treat as no-op success (pre-baseline pdeq repo itself, before it adds its
# own submodule).

cmd_check_lineage() {
  local recorded
  recorded=$(cmd_recorded)
  [[ -z "$recorded" ]] && die "check-lineage: pdeqVersion absent"

  local lineage=""
  if [[ -n "${PDEQ_LINEAGE_FILE:-}" ]]; then
    [[ -f "$PDEQ_LINEAGE_FILE" ]] || die "check-lineage: PDEQ_LINEAGE_FILE not found: $PDEQ_LINEAGE_FILE"
    lineage=$(cat "$PDEQ_LINEAGE_FILE")
  elif [[ -d ".pdeq/.git" || -f ".pdeq/.git" ]]; then
    lineage=$(git -C .pdeq tag --list 2>/dev/null | sed 's/^v//' || true)
  else
    # No submodule, no override — pre-baseline no-op success.
    return 0
  fi

  if grep -Fxq "$recorded" <<<"$lineage"; then
    return 0
  fi
  die "check-lineage: recorded $recorded not in pinned lineage"
}

# ─── lineage-breaking ───────────────────────────────────────────────────────
#
# Print versions declared breaking in the pinned lineage between <from>
# (exclusive) and <to> (inclusive). "Breaking" = MAJOR or MINOR change
# relative to the previous lineage entry. A PATCH bump is non-breaking.

cmd_lineage_breaking() {
  local from="$1" to="$2"
  is_semver "$from" || die "lineage-breaking: from not semver: $from"
  is_semver "$to"   || die "lineage-breaking: to not semver: $to"

  local lineage=""
  if [[ -n "${PDEQ_LINEAGE_FILE:-}" ]]; then
    [[ -f "$PDEQ_LINEAGE_FILE" ]] || die "lineage-breaking: PDEQ_LINEAGE_FILE not found"
    lineage=$(cat "$PDEQ_LINEAGE_FILE")
  elif [[ -d ".pdeq/.git" || -f ".pdeq/.git" ]]; then
    lineage=$(git -C .pdeq tag --list 2>/dev/null | sed 's/^v//' || true)
  else
    return 0
  fi

  # Keep only well-formed semvers, sorted ascending.
  local sorted
  sorted=$(echo "$lineage" | grep -E "$SEMVER_RE" | sort -V)
  [[ -z "$sorted" ]] && return 0

  local prev="" v prev_mm cur_mm
  while IFS= read -r v; do
    # Window: from < v <= to
    if [[ "$(semver_cmp "$v" "$from")" == "1" \
       && "$(semver_cmp "$v" "$to")" != "1" ]]; then
      # Determine predecessor in the lineage (last version <= v, != v).
      if [[ -n "$prev" ]]; then
        prev_mm=$(major_minor "$prev")
        cur_mm=$(major_minor "$v")
        if [[ "$prev_mm" != "$cur_mm" ]]; then
          echo "$v"
        fi
      else
        # No predecessor in lineage → treat as breaking (first is breaking).
        echo "$v"
      fi
    fi
    prev="$v"
  done <<<"$sorted"
}

# ─── audit-scope ────────────────────────────────────────────────────────────
#
# Post-run check: diff `git status --porcelain` against the migration's
# declared scope. Exits 0 if every changed path falls inside scope, exits
# non-zero listing offenders otherwise.
#
# Scope globs are git pathspec style. `default` expands to:
#   <specsRoot>/**
#   pdeq.json
# where <specsRoot> is PDEQ_SPECS_ROOT, else pdeq.json's specsRoot, else `.`.

cmd_audit_scope() {
  local file="$1"
  [[ -f "$file" ]] || die "audit-scope: no such file: $file"

  # Extract scope: — either single value or YAML list.
  local scope_line
  scope_line=$(awk '
    /^---[[:space:]]*$/ { c++; if (c==2) exit; next }
    c==1
  ' "$file" | grep -E '^[[:space:]]*scope:' || true)

  local globs=()
  if [[ -z "$scope_line" ]]; then
    # Absent → treat as default.
    while IFS= read -r _line; do globs+=("$_line"); done < <(default_scope_globs)
  else
    # Scalar form: `scope: <value>` on one line.
    local val
    val=$(sed -n 's/^[[:space:]]*scope:[[:space:]]*\(.*[^[:space:]]\)[[:space:]]*$/\1/p' <<<"$scope_line" | head -n 1)
    if [[ -n "$val" && "$val" != "default" ]]; then
      # Strip surrounding quotes if any.
      val="${val#\"}"; val="${val%\"}"
      val="${val#\'}"; val="${val%\'}"
      globs=("$val")
    elif [[ "$val" == "default" ]]; then
      while IFS= read -r _line; do globs+=("$_line"); done < <(default_scope_globs)
    else
      # List form — parse subsequent `- "glob"` lines until another frontmatter key.
      local list
      list=$(awk '
        /^---[[:space:]]*$/ { c++; if (c==2) exit; next }
        c!=1 { next }
        in_list && /^[[:space:]]*-[[:space:]]+/ { sub(/^[[:space:]]*-[[:space:]]+/, ""); gsub(/["\x27]/, ""); sub(/[[:space:]]+$/, ""); print; next }
        in_list && /^[[:space:]]*[a-zA-Z_-]+:/ { exit }
        /^[[:space:]]*scope:[[:space:]]*$/ { in_list=1 }
      ' "$file")
      if [[ -n "$list" ]]; then
        while IFS= read -r g; do globs+=("$g"); done <<<"$list"
      else
        while IFS= read -r _line; do globs+=("$_line"); done < <(default_scope_globs)
      fi
    fi
  fi

  # Collect changed paths via git.
  local changes
  changes=$(git status --porcelain 2>/dev/null | awk '{ print $2 }' || true)
  [[ -z "$changes" ]] && return 0

  local offenders=()
  while IFS= read -r path; do
    [[ -z "$path" ]] && continue
    if ! path_in_any_glob "$path" "${globs[@]}"; then
      offenders+=("$path")
    fi
  done <<<"$changes"

  if ((${#offenders[@]})); then
    err "scope violation: paths outside declared scope:"
    printf '  %s\n' "${offenders[@]}" >&2
    err "declared scope:"
    printf '  %s\n' "${globs[@]}" >&2
    exit 1
  fi
}

default_scope_globs() {
  local root="${PDEQ_SPECS_ROOT:-}"
  if [[ -z "$root" && -f "$CONFIG_PATH" ]]; then
    root=$(sed -n 's/.*"specsRoot"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$CONFIG_PATH" | head -n 1)
  fi
  [[ -z "$root" ]] && root="."
  # Normalize: strip trailing slash.
  root="${root%/}"
  if [[ "$root" == "." || -z "$root" ]]; then
    echo "**"
    echo "pdeq.json"
  else
    echo "$root/**"
    echo "pdeq.json"
  fi
}

# Match a path against a glob using git pathspec semantics via `git check-ignore`
# is backwards — instead, use shell `[[ $path == $glob ]]` with extglob-like
# handling of `**`. Keep it simple: `**` matches any subpath, `*` matches a
# single segment without `/`.
path_in_any_glob() {
  local path="$1"; shift
  local g
  for g in "$@"; do
    if glob_match "$path" "$g"; then return 0; fi
  done
  return 1
}

glob_match() {
  local path="$1" glob="$2"
  # Translate git-pathspec glob to bash regex.
  # - `**` → `.*`
  # - `*`  → `[^/]*`
  # - `?`  → `[^/]`
  # - escape regex metacharacters in other literals
  local re=""
  local i=0 n=${#glob} c next
  while (( i < n )); do
    c="${glob:i:1}"
    next="${glob:i+1:1}"
    case "$c" in
      '*')
        if [[ "$next" == "*" ]]; then
          re+=".*"; ((i+=2))
        else
          re+="[^/]*"; ((i++))
        fi
        ;;
      '?') re+="[^/]"; ((i++));;
      '.'|'+'|'('|')'|'['|']'|'{'|'}'|'|'|'^'|'$'|'\\') re+="\\$c"; ((i++));;
      *) re+="$c"; ((i++));;
    esac
  done
  [[ "$path" =~ ^${re}$ ]]
}

# ─── Dispatch ───────────────────────────────────────────────────────────────

usage() {
  sed -n '3,20p' "$0" >&2
  exit 2
}

(( $# >= 1 )) || usage
sub="$1"; shift

case "$sub" in
  recorded)         cmd_recorded "$@" ;;
  pinned)           cmd_pinned "$@" ;;
  list-pending)     cmd_list_pending "$@" ;;
  parse)            (( $# == 1 )) || die "parse: usage: parse <file>"
                    cmd_parse "$@" ;;
  bump)             (( $# == 1 )) || die "bump: usage: bump <version>"
                    cmd_bump "$@" ;;
  check-lineage)    cmd_check_lineage "$@" ;;
  lineage-breaking) (( $# == 2 )) || die "lineage-breaking: usage: lineage-breaking <from> <to>"
                    cmd_lineage_breaking "$@" ;;
  audit-scope)      (( $# == 1 )) || die "audit-scope: usage: audit-scope <migration>"
                    cmd_audit_scope "$@" ;;
  -h|--help|help)   usage ;;
  *)                die "unknown subcommand: $sub"
esac
