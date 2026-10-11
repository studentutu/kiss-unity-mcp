#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=unity-ci-common.sh
source "$SCRIPT_DIR/unity-ci-common.sh"

TEST_RESULTS="$(to_unix_path "${UNITY_TEST_RESULTS_PATH:-$CI_OUTPUT_DIR/CITestOutput.xml}")"
UNITY_LOG="$(to_unix_path "${UNITY_TEST_LOG_PATH:-$CI_OUTPUT_DIR/UnityTests.log}")"
DIAGNOSTICS_FILE="$(to_unix_path "${UNITY_DIAGNOSTICS_PATH:-$CI_OUTPUT_DIR/CompileErrorsAfterUnityRun.txt}")"

while (( $# > 0 )); do
  case "$1" in
    --test-results)
      (( $# >= 2 )) || fail "--test-results requires a path"
      TEST_RESULTS="$(to_unix_path "$2")"
      shift 2
      ;;
    --unity-log)
      (( $# >= 2 )) || fail "--unity-log requires a path"
      UNITY_LOG="$(to_unix_path "$2")"
      shift 2
      ;;
    *)
      fail "Unknown argument: $1"
      ;;
  esac
done

require_command awk
require_command sed

# The NUnit parsers stream in linear time, but a test that logs every frame grows the XML to
# hundreds of MB. That is a defect in the test: report its cause with grep and stop.
MAX_TEST_RESULTS_MB=40
fail_on_oversized_results() {
  local size_mb
  [[ -f "$TEST_RESULTS" ]] || return 0
  size_mb=$(( $(wc -c < "$TEST_RESULTS") / 1048576 ))
  (( size_mb >= MAX_TEST_RESULTS_MB )) || return 0
  printf 'ERROR: Test results are %d MB (limit %d MB): %s\n' "$size_mb" "$MAX_TEST_RESULTS_MB" "$TEST_RESULTS" >&2
  printf 'Cause: a test floods its output, usually an exception logged every frame. The XML was not parsed.\n' >&2
  printf 'Root: %s\n' "$(grep -m 1 -o '<test-run [^>]*' "$TEST_RESULTS" || printf 'missing')" >&2
  printf 'First failed tests:\n' >&2
  grep -m 5 -o '<test-case [^>]*result="Failed[^>]*' "$TEST_RESULTS" | sed -n 's/.* fullname="\([^"]*\)".*/  \1/p' >&2 || true
  fail "Fix the flooding test, then rerun it alone with a test filter. Oversized results are never parsed."
}
fail_on_oversized_results

require_nonempty_file "$UNITY_LOG" "Unity test log"
extract_unity_diagnostics "$UNITY_LOG" "$DIAGNOSTICS_FILE"
# Compiler or import errors abort Unity before any XML exists. Surface them here
# so the caller never has to open the full editor log to learn why.
if [[ ! -s "$TEST_RESULTS" ]]; then
  if [[ -s "$DIAGNOSTICS_FILE" ]]; then
    printf 'ERROR: Unity produced no test results. Diagnostics extracted from the Unity log:\n' >&2
    sed -n '1,200p' "$DIAGNOSTICS_FILE" >&2
  fi
  fail "Unity test results missing or empty: $TEST_RESULTS (compile, import, or startup failure; see the diagnostics above)"
fi

root_line="$(awk -f "$SCRIPT_DIR/nunit-summary.awk" "$TEST_RESULTS")" || fail "Malformed, truncated, or inconsistent NUnit XML: $TEST_RESULTS"
[[ -n "$root_line" ]] || fail "The test result does not contain an NUnit <test-run> root: $TEST_RESULTS"

read_attribute() {
  local name="$1"
  printf '%s\n' "$root_line" | sed -n "s/.*[[:space:]]$name=\"\([^\"]*\)\".*/\1/p"
}

result="$(read_attribute result)"
total="$(read_attribute total)"
passed="$(read_attribute passed)"
failed="$(read_attribute failed)"
inconclusive="$(read_attribute inconclusive)"
skipped="$(read_attribute skipped)"

[[ "$total" =~ ^[0-9]+$ ]] || fail "Invalid or missing total count in $TEST_RESULTS"
[[ "$passed" =~ ^[0-9]+$ ]] || fail "Invalid or missing passed count in $TEST_RESULTS"
[[ "$failed" =~ ^[0-9]+$ ]] || fail "Invalid or missing failed count in $TEST_RESULTS"
[[ "$inconclusive" =~ ^[0-9]+$ ]] || fail "Invalid or missing inconclusive count in $TEST_RESULTS"
[[ "$skipped" =~ ^[0-9]+$ ]] || fail "Invalid or missing skipped count in $TEST_RESULTS"

printf 'Test summary: result=%s total=%s passed=%s failed=%s inconclusive=%s skipped=%s\n' \
  "$result" "$total" "$passed" "$failed" "$inconclusive" "$skipped"

if (( failed > 0 )) || [[ "$result" == "Failed" ]]; then
  awk -f "$SCRIPT_DIR/nunit-failures.awk" "$TEST_RESULTS"
fi

status=0

if ! grep -q 'Test run completed\. Exiting with code' "$UNITY_LOG"; then
  printf 'ERROR: Unity log has no test completion marker: %s\n' "$UNITY_LOG" >&2
  status=1
fi

if [[ -s "$DIAGNOSTICS_FILE" ]]; then
  printf 'ERROR: Unity diagnostics found in %s:\n' "$DIAGNOSTICS_FILE" >&2
  sed -n '1,200p' "$DIAGNOSTICS_FILE" >&2
  status=1
fi

if (( total == 0 )); then
  if [[ -n "${UNITY_TEST_FILTER:-}${UNITY_TEST_CATEGORY:-}${UNITY_TEST_ASSEMBLIES:-}" ]]; then
    printf 'ERROR: No test matched the selection (filter=%s category=%s assembly=%s). Use the NUnit full name, e.g. Namespace.Fixture.Test, or the fixture name.\n' \
      "${UNITY_TEST_FILTER:-}" "${UNITY_TEST_CATEGORY:-}" "${UNITY_TEST_ASSEMBLIES:-}" >&2
  else
    printf 'ERROR: Unity completed without discovering tests. Add tests and ensure the project includes Unity Test Framework.\n' >&2
  fi
  status=1
fi

if (( failed > 0 )) || (( inconclusive > 0 )) || [[ "$result" != "Passed" ]]; then
  if (( status == 0 )); then status=2; fi
fi

if (( skipped > 0 )) && [[ "${FAIL_ON_SKIPPED:-0}" == "1" ]]; then
  printf 'ERROR: %d skipped test(s) are disallowed by FAIL_ON_SKIPPED=1.\n' "$skipped" >&2
  status=2
fi

if (( status == 0 )); then
  printf 'Test result and Unity log are valid.\n'
fi

exit "$status"
