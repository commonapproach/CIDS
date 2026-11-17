#!/usr/bin/env bash
# Runs the checks for the CIDS repository. GitHub Actions runs this same
# script on every pull request and on every push to main.
#
# Usage:  tests/run-tests.sh [--skip-owl] [--update-owl-lists]
#
#   --skip-owl           Skip the checks that need ROBOT (cfo.owl loading and test 2).
#   --update-owl-lists   Rewrite tests/known-owl-problems/ to match what ROBOT
#                        reports now. Use after fixing OWL problems.
#
# Needs:  Java 17 or newer
#         Apache Jena: riot, shacl and sparql on your PATH
#         ROBOT: robot on your PATH, or ROBOT_JAR=/path/to/robot.jar
#         Internet access: ROBOT loads the ontologies CIDS imports.
#
# See tests/README.md for what each test does and how to add samples.

set -u
# Sort the same way on every computer, so lists compare correctly.
export LC_ALL=C

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 2

TESTS="tests"
KNOWN_FILE="$TESTS/known-failures.txt"
OWL_LISTS="$TESTS/known-owl-problems"
CATALOG="$TESTS/catalog-v001.xml"
RESULTS_QUERY="$TESTS/lib/results.rq"
SHAPES_DIR="validation/shacl"

skip_owl=false
update_owl_lists=false
for arg in "$@"; do
  case "$arg" in
    --skip-owl) skip_owl=true ;;
    --update-owl-lists) update_owl_lists=true ;;
    -h|--help) sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: $arg (try --help)" >&2; exit 2 ;;
  esac
done

# ---------------------------------------------------------------- tools

for cmd in java riot shacl sparql; do
  if ! command -v "$cmd" > /dev/null 2>&1; then
    echo "Missing '$cmd'. Install Java 17+ and Apache Jena, and put Jena's bin folder on your PATH." >&2
    exit 2
  fi
done

robot() {
  if [ -n "${ROBOT_JAR:-}" ]; then
    java -jar "$ROBOT_JAR" "$@"
  else
    command robot "$@"
  fi
}

if ! $skip_owl; then
  if [ -n "${ROBOT_JAR:-}" ]; then
    [ -f "$ROBOT_JAR" ] || { echo "ROBOT_JAR is set but $ROBOT_JAR does not exist." >&2; exit 2; }
  elif ! command -v robot > /dev/null 2>&1; then
    echo "ROBOT not found. Download robot.jar from https://github.com/ontodev/robot/releases" >&2
    echo "and run:  ROBOT_JAR=/path/to/robot.jar tests/run-tests.sh" >&2
    echo "Or run without the OWL checks:  tests/run-tests.sh --skip-owl" >&2
    exit 2
  fi
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
LOG="$TMP/log"

# ---------------------------------------------------------------- reporting

passed=0; failed=0; known=0; skipped=0
failed_names=""

section() { printf '\n== %s\n' "$1"; }

is_known() {
  # Check names are everything on the line except the last word (the issue link).
  grep -v '^[[:space:]]*#' "$KNOWN_FILE" \
    | awk 'NF >= 2 { $NF = ""; sub(/[ \t]+$/, ""); print }' > "$TMP/known"
  grep -qxF "$1" "$TMP/known"
}

annotate() {
  # Shows the failure on the pull request page when running in GitHub Actions.
  [ "${GITHUB_ACTIONS:-}" = "true" ] || return 0
  local file msg
  file="$(echo "$1" | awk '{print $2}')"
  msg="$(head -n 1 "$LOG" 2>/dev/null | cut -c1-300)"
  echo "::error file=${file},title=${1}::${msg:-see the job log}"
}

# record <check name> <exit status>   (details of a failure are read from $LOG)
record() {
  local name="$1" status="$2"
  if [ "$status" -eq 0 ]; then
    if is_known "$name"; then
      echo "FAIL  $name"
      echo "        Listed in $KNOWN_FILE but now passes. Remove it from that list."
      echo "This check is in known-failures.txt but now passes; remove it from the list." > "$LOG"
      annotate "$name"
      failed=$((failed + 1)); failed_names="$failed_names
  $name"
    else
      echo "PASS  $name"
      passed=$((passed + 1))
    fi
  elif is_known "$name"; then
    echo "KNOWN $name"
    known=$((known + 1))
  else
    echo "FAIL  $name"
    sed 's/^/        /' "$LOG" | head -n 40
    annotate "$name"
    failed=$((failed + 1)); failed_names="$failed_names
  $name"
  fi
}

skip() { echo "SKIP  $1"; skipped=$((skipped + 1)); }

# owl_dl_check <ontology file>
# Compares ROBOT's OWL 2 DL report with the file's list of known problems.
owl_dl_check() {
  local f="$1" name="owl-dl $1" list="$OWL_LISTS/$1.txt"
  rm -f "$TMP/profile.txt"
  robot --catalog "$CATALOG" validate-profile --profile DL \
    --input "$f" --output "$TMP/profile.txt" > "$LOG" 2>&1
  if [ ! -f "$TMP/profile.txt" ]; then
    record "$name" 1      # ROBOT could not load the file or its imports
    return
  fi

  # One line per problem. Blank node ids change on every run, so blank them out.
  grep -v '^OWL 2 DL Profile Report' "$TMP/profile.txt" \
    | grep -v '^[[:space:]]*$' \
    | sed -E 's/_:genid[0-9]+/_:b/g' | sort -u > "$TMP/now"

  if $update_owl_lists; then
    if [ -s "$TMP/now" ]; then
      {
        if [ -f "$list" ]; then
          grep '^#' "$list"
        else
          echo "# OWL 2 DL problems that ROBOT reports today for $f, including its imports."
          echo "# A pull request fails if it adds a problem that is not on this list."
          echo "# Don't edit by hand. After fixing problems, run:"
          echo "#   tests/run-tests.sh --update-owl-lists"
          echo "# Issues: see the 'OWL 2 DL problems' section of tests/known-failures.txt"
        fi
        cat "$TMP/now"
      } > "$TMP/newlist"
      mv "$TMP/newlist" "$list"
      echo "UPDATED $list ($(wc -l < "$TMP/now" | tr -d ' ') problems)"
    else
      rm -f "$list"
      echo "UPDATED $list removed (no problems left)"
    fi
    passed=$((passed + 1))
    return
  fi

  if [ -f "$list" ]; then
    grep -v '^#' "$list" | sort -u > "$TMP/known-owl"
  else
    : > "$TMP/known-owl"
  fi
  comm -13 "$TMP/known-owl" "$TMP/now" > "$TMP/new-owl"
  comm -23 "$TMP/known-owl" "$TMP/now" > "$TMP/gone-owl"

  if [ -s "$TMP/new-owl" ]; then
    {
      echo "New OWL 2 DL problems ($(wc -l < "$TMP/new-owl" | tr -d ' ')):"
      sed 's/^/  /' "$TMP/new-owl" | cut -c1-400
    } > "$LOG"
    record "$name" 1
  elif [ -s "$TMP/gone-owl" ]; then
    {
      echo "Fixed $(wc -l < "$TMP/gone-owl" | tr -d ' ') of the problems on $list. Update the list with:"
      echo "  tests/run-tests.sh --update-owl-lists"
      echo "and commit the change. Fixed:"
      sed 's/^/  /' "$TMP/gone-owl" | cut -c1-400
    } > "$LOG"
    record "$name" 1
  elif [ -s "$TMP/now" ]; then
    echo "KNOWN $name ($(wc -l < "$TMP/now" | tr -d ' ') known problems, nothing new)"
    known=$((known + 1))
  else
    record "$name" 0
  fi
}

# ---------------------------------------------------------------- test 1

section "Test 1: every ontology, SHACL and context file loads without syntax errors"

for f in ./*.ttl contexts/*.jsonld "$SHAPES_DIR"/*.ttl; do
  f="${f#./}"
  riot --validate "$f" > "$LOG" 2>&1
  record "syntax $f" $?
done

for f in ./*.owl; do
  f="${f#./}"
  if $skip_owl; then skip "syntax $f"; continue; fi
  robot --catalog "$CATALOG" convert --input "$f" --output "$TMP/converted.ttl" > "$LOG" 2>&1
  record "syntax $f" $?
done

# A SHACL file can be valid Turtle but still not usable as shapes (for example
# a property shape with two sh:path values). Check that each one compiles.
: > "$TMP/empty.ttl"
for f in "$SHAPES_DIR"/*.ttl; do
  shacl validate -s "$f" -d "$TMP/empty.ttl" > /dev/null 2> "$LOG"
  record "shapes $f" $?
done

# ---------------------------------------------------------------- test 2

section "Test 2: the ontology files are valid OWL"

if $skip_owl; then
  skip "OWL checks (--skip-owl)"
else
  mkdir -p "$OWL_LISTS"
  for f in ./*.ttl ./*.owl; do
    f="${f#./}"

    # Follows the OWL 2 DL rules (what reasoners and most OWL tools expect).
    # The ontologies already break some rules. Those problems are listed in
    # tests/known-owl-problems/<file>.txt; only problems NOT on that list fail.
    owl_dl_check "$f"

    # No logical contradictions and no classes that can never have members.
    robot --catalog "$CATALOG" reason --reasoner HermiT \
      --input "$f" --output "$TMP/reasoned.owl" > "$LOG" 2>&1
    record "owl-consistent $f" $?
  done

  # cfo.ttl and cfo.owl are the same ontology in two formats; they must match.
  if [ -f cfo.ttl ] && [ -f cfo.owl ]; then
    robot --catalog "$CATALOG" diff --left cfo.ttl --right cfo.owl \
      --output "$TMP/diff.txt" > "$LOG" 2>&1
    status=$?
    if [ $status -eq 0 ] && ! grep -q "identical" "$TMP/diff.txt"; then
      { echo "cfo.ttl and cfo.owl say different things:"; head -n 30 "$TMP/diff.txt"; } > "$LOG"
      status=1
    fi
    record "same cfo.ttl cfo.owl" $status
  fi
fi

# ---------------------------------------------------------------- test 3

section "Test 3: sample capsules against the SHACL shapes"

# Valid samples for a tier must pass that tier and every tier below it.
tiers_for() {
  case "$1" in
    basic)     echo "basictier" ;;
    essential) echo "basictier essentialtier" ;;
    full)      echo "basictier essentialtier fulltier" ;;
  esac
}

# validate <shapes file> <data file> <output file>
# Writes one line per problem found ("<property> <constraint>") to the output.
validate() {
  shacl validate -s "$1" -d "$2" > "$TMP/report.ttl" 2> "$LOG" || return 1
  sparql --data="$TMP/report.ttl" --query="$RESULTS_QUERY" --results=tsv \
    > "$TMP/results.tsv" 2>> "$LOG" || return 1
  tail -n +2 "$TMP/results.tsv" | tr -d '"' | sort > "$3"
}

for tier in basic essential full; do
  dir="$TESTS/samples/$tier"

  for f in "$dir"/valid/*.jsonld; do
    [ -e "$f" ] || continue
    for t in $(tiers_for "$tier"); do
      status=0
      if validate "$SHAPES_DIR/cids.$t.shacl.ttl" "$f" "$TMP/got"; then
        if [ -s "$TMP/got" ]; then
          { echo "Expected no problems, but got:"; sed 's/^/  /' "$TMP/got"; } > "$LOG"
          status=1
        fi
      else
        status=1
      fi
      record "valid $f ($t)" $status
    done
  done

  # Broken samples are checked against their own tier only. Each one has a
  # .expected file listing exactly the problems it must produce.
  own="$(tiers_for "$tier" | awk '{print $NF}')"
  for f in "$dir"/invalid/*.jsonld; do
    [ -e "$f" ] || continue
    expected="${f%.jsonld}.expected"
    status=0
    if [ ! -f "$expected" ]; then
      echo "Missing $expected (list the problems this sample must produce)." > "$LOG"
      status=1
    elif validate "$SHAPES_DIR/cids.$own.shacl.ttl" "$f" "$TMP/got"; then
      grep -v '^[[:space:]]*$' "$expected" | sort > "$TMP/want"
      if ! cmp -s "$TMP/want" "$TMP/got"; then
        {
          echo "Expected these problems:"; sed 's/^/  /' "$TMP/want"
          echo "But got:"; sed 's/^/  /' "$TMP/got"
        } > "$LOG"
        status=1
      fi
    else
      status=1
    fi
    record "invalid $f ($own)" $status
  done
done

# ---------------------------------------------------------------- summary

printf '\n== Summary: %d passed, %d failed, %d known failures, %d skipped\n' \
  "$passed" "$failed" "$known" "$skipped"

if [ "$failed" -gt 0 ]; then
  echo "Failed checks:$failed_names"
  exit 1
fi
exit 0
