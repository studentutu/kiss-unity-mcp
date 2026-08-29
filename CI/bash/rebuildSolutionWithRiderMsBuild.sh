#!/usr/bin/env bash

# Fast validation for already-generated Unity solution files.
# This does not import assets or regenerate the solution; run
# rebuildSolutionFromUnityItself.sh after adding/removing scripts or asmdefs.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=unity-ci-common.sh
source "$SCRIPT_DIR/unity-ci-common.sh"

require_unity_project

resolve_solution() {
  local configured candidates

  if [[ -n "${UNITY_SOLUTION_PATH:-}" ]]; then
    configured="$(to_unix_path "$UNITY_SOLUTION_PATH")"
    [[ -f "$configured" ]] || fail "UNITY_SOLUTION_PATH does not exist: $configured"
    printf '%s\n' "$configured"
    return 0
  fi

  shopt -s nullglob
  candidates=("$UNITY_PROJECT_PATH"/*.sln)
  shopt -u nullglob

  if (( ${#candidates[@]} == 0 )); then
    fail "No .sln exists in $UNITY_PROJECT_PATH. Run $SCRIPT_DIR/rebuildSolutionFromUnityItself.sh first."
  fi

  if (( ${#candidates[@]} > 1 )); then
    printf 'ERROR: Multiple Unity solutions found; set UNITY_SOLUTION_PATH explicitly:\n' >&2
    printf '  %s\n' "${candidates[@]}" >&2
    exit 1
  fi

  printf '%s\n' "${candidates[0]}"
}

resolve_msbuild() {
  local configured candidates candidate

  if [[ -n "${RIDER_MSBUILD:-}" ]]; then
    configured="$(to_unix_path "$RIDER_MSBUILD")"
    [[ -x "$configured" ]] || fail "RIDER_MSBUILD is not executable: $configured"
    printf '%s\n' "$configured"
    return 0
  fi

  shopt -s nullglob
  candidates=(
    /c/Program\ Files/JetBrains/JetBrains\ Rider\ */tools/MSBuild/Current/Bin/amd64/MSBuild.exe
    /c/Program\ Files/JetBrains/JetBrains\ Rider\ */tools/MSBuild/Current/Bin/MSBuild.exe
  )
  shopt -u nullglob

  if (( ${#candidates[@]} > 0 )); then
    candidate="$(printf '%s\n' "${candidates[@]}" | sort -V | tail -n 1)"
    [[ -x "$candidate" ]] || fail "Discovered MSBuild is not executable: $candidate"
    printf '%s\n' "$candidate"
    return 0
  fi

  if command -v msbuild >/dev/null 2>&1; then
    command -v msbuild
    return 0
  fi

  fail "Rider MSBuild was not found. Set RIDER_MSBUILD to MSBuild.exe."
}

SOLUTION_UNIX="$(resolve_solution)"
MSBUILD="$(resolve_msbuild)"
RIDER_LOG="$(to_unix_path "${RIDER_MSBUILD_LOG_PATH:-$CI_OUTPUT_DIR/RiderMsBuild.log}")"
DIAGNOSTICS_FILE="$(to_unix_path "${MSBUILD_DIAGNOSTICS_PATH:-$CI_OUTPUT_DIR/CompileErrorsAfterUnityRun.txt}")"

if command -v cygpath >/dev/null 2>&1; then
  SOLUTION_NATIVE="$(cygpath -w "$SOLUTION_UNIX")"
else
  SOLUTION_NATIVE="$SOLUTION_UNIX"
fi

prepare_output_file "$RIDER_LOG"
prepare_output_file "$DIAGNOSTICS_FILE"

print_context
printf 'Solution:      %s\n' "$SOLUTION_UNIX"
printf 'MSBuild:       %s\n' "$MSBUILD"
printf 'MSBuild log:   %s\n' "$RIDER_LOG"
printf 'Diagnostics:   %s\n\n' "$DIAGNOSTICS_FILE"

# Git Bash otherwise rewrites MSBuild switches such as /t and /p as paths.
set +e
MSYS2_ARG_CONV_EXCL="*" "$MSBUILD" \
  "$SOLUTION_NATIVE" \
  /t:Rebuild \
  /m \
  /v:minimal \
  /nologo \
  /p:Configuration=Debug \
  /p:Platform="Any CPU" \
  2>&1 | tee "$RIDER_LOG"
msbuild_exit_code=${PIPESTATUS[0]}
set -e

require_nonempty_file "$RIDER_LOG" "Rider MSBuild log"

awk '
  { sub(/\r$/, "", $0) }
  tolower($0) ~ /: error [a-z]+[0-9]+:/ { print; next }
  tolower($0) ~ /error msb[0-9]+:/ { print; next }
  tolower($0) ~ /^build failed/ { print; next }
' "$RIDER_LOG" | awk '!seen[$0]++' > "$DIAGNOSTICS_FILE"

if (( msbuild_exit_code != 0 )); then
  if [[ ! -s "$DIAGNOSTICS_FILE" ]]; then
    printf 'MSBuild exited with code %d without a recognized compiler diagnostic. Inspect %s\n' \
      "$msbuild_exit_code" "$RIDER_LOG" > "$DIAGNOSTICS_FILE"
  fi

  printf 'ERROR: MSBuild failed with exit code %d. Diagnostics:\n' "$msbuild_exit_code" >&2
  sed -n '1,200p' "$DIAGNOSTICS_FILE" >&2
  exit "$msbuild_exit_code"
fi

if [[ -s "$DIAGNOSTICS_FILE" ]]; then
  printf 'ERROR: MSBuild emitted error diagnostics despite returning zero:\n' >&2
  sed -n '1,200p' "$DIAGNOSTICS_FILE" >&2
  exit 1
fi

printf 'Rider MSBuild passed.\n'
