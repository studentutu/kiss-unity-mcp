#!/usr/bin/env bash

# Shared, project-agnostic contract for every script in CI/bash.
# Paths are resolved from this file so callers may run the scripts from any directory.

if [[ -n "${SIMPLE_UNITY_MCP_CI_COMMON_LOADED:-}" ]]; then
  return 0
fi
readonly SIMPLE_UNITY_MCP_CI_COMMON_LOADED=1

set -euo pipefail

CI_BASH_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPOSITORY_ROOT="${REPOSITORY_ROOT:-$(cd -- "$CI_BASH_DIR/../.." && pwd -P)}"
CI_OUTPUT_DIR="${CI_OUTPUT_DIR:-$REPOSITORY_ROOT/CI}"

if [[ -z "${UNITY_PROJECT_PATH:-}" ]]; then
  if [[ -f "$REPOSITORY_ROOT/UnityProj/ProjectSettings/ProjectVersion.txt" ]]; then
    UNITY_PROJECT_PATH="$REPOSITORY_ROOT/UnityProj"
  elif [[ -f "$REPOSITORY_ROOT/ProjectSettings/ProjectVersion.txt" ]]; then
    UNITY_PROJECT_PATH="$REPOSITORY_ROOT"
  else
    UNITY_PROJECT_PATH="$REPOSITORY_ROOT/UnityProj"
  fi
fi

to_unix_path() {
  local path="$1"
  if command -v cygpath >/dev/null 2>&1 && [[ "$path" =~ ^[A-Za-z]:[\\/] ]]; then
    cygpath -u "$path"
  else
    printf '%s\n' "$path"
  fi
}

REPOSITORY_ROOT="$(to_unix_path "$REPOSITORY_ROOT")"
UNITY_PROJECT_PATH="$(to_unix_path "$UNITY_PROJECT_PATH")"
CI_OUTPUT_DIR="$(to_unix_path "$CI_OUTPUT_DIR")"

readonly CI_BASH_DIR REPOSITORY_ROOT UNITY_PROJECT_PATH CI_OUTPUT_DIR

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

require_unity_project() {
  [[ -d "$UNITY_PROJECT_PATH/Assets" ]] || fail "Unity Assets directory not found: $UNITY_PROJECT_PATH/Assets"
  [[ -d "$UNITY_PROJECT_PATH/Packages" ]] || fail "Unity Packages directory not found: $UNITY_PROJECT_PATH/Packages"
  [[ -f "$UNITY_PROJECT_PATH/ProjectSettings/ProjectVersion.txt" ]] || \
    fail "Unity ProjectVersion.txt not found: $UNITY_PROJECT_PATH/ProjectSettings/ProjectVersion.txt"
}

unity_version() {
  local version_file="$UNITY_PROJECT_PATH/ProjectSettings/ProjectVersion.txt"
  local version
  version="$(sed -n 's/^m_EditorVersion:[[:space:]]*//p' "$version_file" | tr -d '\r' | head -n 1)"
  [[ -n "$version" ]] || fail "Could not read m_EditorVersion from $version_file"
  printf '%s\n' "$version"
}

resolve_unity_editor() {
  local requested_version candidate
  requested_version="$(unity_version)"

  if [[ -n "${UNITY_EDITOR_PATH:-}" ]]; then
    candidate="$(to_unix_path "$UNITY_EDITOR_PATH")"
    [[ -x "$candidate" ]] || fail "UNITY_EDITOR_PATH is not executable: $candidate"
    printf '%s\n' "$candidate"
    return 0
  fi

  case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
      candidate="/c/Program Files/Unity/Hub/Editor/$requested_version/Editor/Unity.exe"
      ;;
    Darwin*)
      candidate="/Applications/Unity/Hub/Editor/$requested_version/Unity.app/Contents/MacOS/Unity"
      ;;
    *)
      candidate="/opt/unity/editors/$requested_version/Editor/Unity"
      ;;
  esac

  if [[ -x "$candidate" ]]; then
    printf '%s\n' "$candidate"
    return 0
  fi

  if command -v Unity >/dev/null 2>&1; then
    command -v Unity
    return 0
  fi

  fail "Unity $requested_version was not found. Set UNITY_EDITOR_PATH to the editor executable."
}

prepare_output_file() {
  local path="$1"
  mkdir -p -- "$(dirname -- "$path")"
  : > "$path"
}

require_nonempty_file() {
  local path="$1"
  local label="$2"
  [[ -s "$path" ]] || fail "$label was not created or is empty: $path"
}

extract_unity_diagnostics() {
  local log_file="$1"
  local output_file="$2"

  prepare_output_file "$output_file"
  [[ -f "$log_file" ]] || return 0

  # Unity has no stable machine-readable editor log. Keep this list narrow and pair it
  # with the process status and command-specific completion artifacts in the entry scripts.
  awk '
    { sub(/\r$/, "", $0) }
    script_error_lines_remaining > 0 {
      print
      script_error_lines_remaining--
      next
    }
    index($0, "## Script Compilation Error") == 1 {
      print
      script_error_lines_remaining=49
      next
    }
    tolower($0) ~ /error (cs|bc)[0-9]+/ { print; next }
    tolower($0) ~ /shader error in/ { print; next }
    tolower($0) ~ /scripts have compiler errors/ { print; next }
    tolower($0) ~ /compilation failed/ { print; next }
    tolower($0) ~ /aborting batchmode due to failure/ { print; next }
    tolower($0) ~ /executemethod.*(could not be found|threw exception|failed)/ { print; next }
    tolower($0) ~ /unhandled exception/ { print; next }
    tolower($0) ~ /fatal error/ { print; next }
    index($0, "Crash!!!") > 0 { print; next }
  ' "$log_file" | awk '!seen[$0]++' > "$output_file"
}

print_context() {
  local unity_editor="${1:-not required}"
  printf 'Repository:    %s\n' "$REPOSITORY_ROOT"
  printf 'Unity project: %s\n' "$UNITY_PROJECT_PATH"
  printf 'CI output:     %s\n' "$CI_OUTPUT_DIR"
  printf 'Unity editor:  %s\n' "$unity_editor"
}
