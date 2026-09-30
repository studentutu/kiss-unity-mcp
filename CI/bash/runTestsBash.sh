#!/usr/bin/env bash
# Headless Unity test run. Optional selection flags narrow the run to one test,
# one fixture (class), one category, or one assembly, so long suites can be skipped.
#   --filter <name-or-regex>   Unity -testFilter: full test name, "Fixture", or
#                              "Namespace.Fixture.Test"; regex on the full name;
#                              semicolon-separated list allowed.
#   --category <name>          Unity -testCategory (semicolon-separated list allowed).
#   --assembly <name>          Unity -assemblyNames (semicolon-separated list allowed).
#   --platform <EditMode|PlayMode>
# Environment equivalents: UNITY_TEST_FILTER, UNITY_TEST_CATEGORY,
# UNITY_TEST_ASSEMBLIES, UNITY_TEST_PLATFORM. Flags take precedence.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=unity-ci-common.sh
source "$SCRIPT_DIR/unity-ci-common.sh"

read_selection() {
  local flag="$1" value="$2"
  [[ -n "$value" ]] || fail "$flag requires a value"
  [[ "$value" != -* ]] || fail "$flag value must not start with '-': $value"
  [[ "$value" != *$'\n'* && "$value" != *$'\r'* ]] || fail "$flag value must be a single line"
  printf '%s' "$value"
}
while (( $# > 0 )); do
  case "$1" in
    --filter) (( $# >= 2 )) || fail "--filter requires a test name, fixture name, or regex"
      UNITY_TEST_FILTER="$(read_selection --filter "$2")"; shift 2;;
    --category) (( $# >= 2 )) || fail "--category requires a value"
      UNITY_TEST_CATEGORY="$(read_selection --category "$2")"; shift 2;;
    --assembly) (( $# >= 2 )) || fail "--assembly requires a value"
      UNITY_TEST_ASSEMBLIES="$(read_selection --assembly "$2")"; shift 2;;
    --platform) (( $# >= 2 )) || fail "--platform requires EditMode or PlayMode"
      UNITY_TEST_PLATFORM="$2"; shift 2;;
    *) fail "Unknown argument: $1. Supported: --filter, --category, --assembly, --platform";;
  esac
done
UNITY_TEST_PLATFORM="${UNITY_TEST_PLATFORM:-EditMode}"
case "$UNITY_TEST_PLATFORM" in EditMode|PlayMode) ;; *) fail "Unsupported test platform: $UNITY_TEST_PLATFORM. Use EditMode or PlayMode.";; esac
export UNITY_TEST_FILTER UNITY_TEST_CATEGORY UNITY_TEST_ASSEMBLIES UNITY_TEST_PLATFORM

require_unity_project

UNITY_EDITOR="$(resolve_unity_editor)"
export UNITY_EDITOR_PATH="$UNITY_EDITOR"
require_closed_editor
acquire_run_lock
TEST_RESULTS="$(to_unix_path "${UNITY_TEST_RESULTS_PATH:-$CI_OUTPUT_DIR/CITestOutput.xml}")"
UNITY_LOG="$(to_unix_path "${UNITY_TEST_LOG_PATH:-$CI_OUTPUT_DIR/UnityTests.log}")"

prepare_output_file "$TEST_RESULTS"
prepare_output_file "$UNITY_LOG"

selection_args=()
[[ -z "${UNITY_TEST_FILTER:-}" ]] || selection_args+=(-testFilter "$UNITY_TEST_FILTER")
[[ -z "${UNITY_TEST_CATEGORY:-}" ]] || selection_args+=(-testCategory "$UNITY_TEST_CATEGORY")
[[ -z "${UNITY_TEST_ASSEMBLIES:-}" ]] || selection_args+=(-assemblyNames "$UNITY_TEST_ASSEMBLIES")

print_context "$UNITY_EDITOR"
printf 'Test platform: %s\n' "$UNITY_TEST_PLATFORM"
printf 'Test filter:   %s\n' "${UNITY_TEST_FILTER:-<all tests>}"
[[ -z "${UNITY_TEST_CATEGORY:-}" ]] || printf 'Test category: %s\n' "$UNITY_TEST_CATEGORY"
[[ -z "${UNITY_TEST_ASSEMBLIES:-}" ]] || printf 'Assemblies:    %s\n' "$UNITY_TEST_ASSEMBLIES"
printf 'Test results:  %s\n' "$TEST_RESULTS"
printf 'Unity log:     %s\n\n' "$UNITY_LOG"

set +e
"$UNITY_EDITOR" \
  -batchmode \
  -nographics \
  -stackTraceLogType Full \
  -runTests \
  -projectPath "$UNITY_PROJECT_PATH" \
  -logFile "$UNITY_LOG" \
  -testPlatform "$UNITY_TEST_PLATFORM" \
  -testResultsVersion 2 \
  -testResults "$TEST_RESULTS" \
  ${selection_args[@]+"${selection_args[@]}"}
unity_exit_code=$?
set -e
release_exited_editor_lock
release_exited_editor_lock

printf '\nUnity exit code: %d\n' "$unity_exit_code"

set +e
bash "$SCRIPT_DIR/parseTestErrors.sh" \
  --test-results "$TEST_RESULTS" \
  --unity-log "$UNITY_LOG"
parse_exit_code=$?
set -e

if (( parse_exit_code != 0 )); then
  exit "$parse_exit_code"
fi

if (( unity_exit_code != 0 )); then
  fail "Unity returned $unity_exit_code even though the result parser found no test failure. Inspect $UNITY_LOG"
fi

printf 'Unity tests passed.\n'
