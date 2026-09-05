#!/usr/bin/env bash
# Filesystem-only installation. No Unity launch, downloads, manifest edits, or eval.
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/common.sh"
PLUGIN_ROOT="$(cd -- "$TOOLS_SCRIPT_DIR/.." && pwd -P)"
[[ $# -gt 0 ]] || fail "Usage: bash $0 <Unity project> [--dry-run] [--replace]"
require_project "$(to_unix_path "$1")"; shift
dry_run=0; replace=0
while (( $# )); do
  case "$1" in --dry-run) dry_run=1;; --replace) replace=1;; *) fail "Unknown option: $1";; esac
  shift
done
PACKAGE_NAME=com.studentutu.unitysimplemcp
source_package="$PLUGIN_ROOT/$PACKAGE_NAME"
target_package="$PROJECT/Packages/$PACKAGE_NAME"
target_tools="$PROJECT/.unity-simple-mcp"
marker="$PROJECT/ProjectSettings/SimpleUnityMcpSetup.json"
version="$(json_get "$source_package/package.json" /version)"
minimum="$(json_get "$source_package/package.json" /unity)"
major="${PROJECT_VERSION%%.*}"; minor="${PROJECT_VERSION#*.}"; minor="${minor%%.*}"
min_major="${minimum%%.*}"; min_minor="${minimum#*.}"; min_minor="${min_minor%%.*}"
(( major>min_major || (major==min_major && minor>=min_minor) )) || fail "Unity $PROJECT_VERSION is older than package minimum $minimum"
for target in "$target_package" "$target_tools" "$marker" "$PROJECT/.vscode" "$PROJECT/.vscode/tasks.json" "$PROJECT/.vscode/unity-simple-mcp.code-workspace"; do
  [[ ! -L "$target" ]] || fail "Refusing linked setup destination: $target"
done
# Stage outside the project during inspection, keeping --dry-run read-only there.
stage="$(mktemp -d "${TMPDIR:-/tmp}/unity-simple-mcp.XXXXXXXX")"
[[ -d "$stage" && "$stage" == "${TMPDIR:-/tmp}"/unity-simple-mcp.* ]] || fail "Unsafe staging path: $stage"
cleanup() {
  rm -rf -- "$stage"
  if [[ -n "${lock:-}" && -d "$lock" ]]; then rmdir "$lock"; fi
}
trap cleanup EXIT
if (( ! dry_run )); then
  [[ ! -d "$PROJECT/ProjectSettings/.SimpleUnityMcpRun.lock" ]] || fail "Verification is active: $PROJECT/ProjectSettings/.SimpleUnityMcpRun.lock"
  lock="$PROJECT/ProjectSettings/.SimpleUnityMcpSetup.lock"
  if ! mkdir "$lock" 2>/dev/null; then
    # Do not remove a lock owned by another process in cleanup.
    lock=''
    fail "Setup already running or stale lock: $PROJECT/ProjectSettings/.SimpleUnityMcpSetup.lock. Check processes before removing it."
  fi
fi
mkdir -p "$stage/tools/CI" "$stage/tools/scripts"
cp -R "$PLUGIN_ROOT/CI/bash" "$stage/tools/CI/bash"
cp "$TOOLS_SCRIPT_DIR/common.sh" "$TOOLS_SCRIPT_DIR/json.awk" "$TOOLS_SCRIPT_DIR/unity.sh" "$stage/tools/scripts/"
cp "$PLUGIN_ROOT/templates/tools.env" "$stage/tools/tools.env"
cp "$PLUGIN_ROOT/templates/tasks.json" "$stage/tools/tasks.json"
cp "$PLUGIN_ROOT/templates/unity-simple-mcp.code-workspace" "$stage/tools/unity-simple-mcp.code-workspace"
cp "$PLUGIN_ROOT/templates/gitignore" "$stage/tools/.gitignore"
if [[ -f "$target_tools/tools.env" ]]; then cp "$target_tools/tools.env" "$stage/tools/tools.env"; fi
source_digest="$(tree_digest "$source_package")"
tools_digest="$(tree_digest "$stage/tools")"
package_state=not_installed; tools_state=not_installed
if [[ -e "$target_package" ]]; then
  package_state=conflict
  if [[ -d "$target_package" ]] && [[ "$(tree_digest "$target_package")" == "$source_digest" ]]; then package_state=installed; fi
fi
if [[ -e "$target_tools" ]]; then
  tools_state=conflict
  if [[ -d "$target_tools" ]] && [[ "$(tree_digest "$target_tools")" == "$tools_digest" ]]; then tools_state=installed; fi
fi
state=not_installed
if [[ "$package_state" == installed && "$tools_state" == installed ]]; then state=installed; fi
if [[ "$package_state" == conflict || "$tools_state" == conflict ]]; then state=conflict; fi
report() {
  printf '{"state":"%s","action":"%s","projectPath":%s,"unityVersion":"%s","packageVersion":"%s","sourceDigest":"%s","toolsDigest":"%s","configPath":%s}\n' \
    "$state" "$1" "$(quote "$PROJECT")" "$PROJECT_VERSION" "$version" "$source_digest" "$tools_digest" "$(quote "$target_tools/tools.env")"
}
if (( dry_run )); then report "inspection"; exit 0; fi
if [[ "$state" == conflict ]] && (( ! replace )); then
  fail "Setup conflict: package=$package_state ($target_package), tools=$tools_state ($target_tools). Inspect local changes; use --replace only for an intentional replacement. tools.env is preserved."
fi
workspace="$PROJECT/.vscode/unity-simple-mcp.code-workspace"
if [[ -e "$workspace" ]] && ! cmp -s "$workspace" "$stage/tools/unity-simple-mcp.code-workspace"; then
  fail "Workspace conflict: $workspace. Move your custom workspace aside before setup; existing tasks.json is always preserved."
fi
if [[ "$state" == installed && -f "$workspace" && -f "$marker" ]]; then report already_installed; exit 0; fi
# Same-filesystem staging makes the directory renames atomic. Retain replacement
# backups for recovery; never recursively delete consumer data during setup.
transaction="$PROJECT/Packages/.simple-unity-mcp-setup-$$"
[[ "$transaction" == "$PROJECT/Packages/".simple-unity-mcp-setup-* && ! -e "$transaction" ]] || fail "Unsafe transaction path: $transaction"
mkdir "$transaction"
package_moved=0; tools_moved=0; package_written=0; tools_written=0; workspace_written=0; tasks_written=0; committed=0
rollback() {
  if (( ! committed )); then
    if (( workspace_written )); then rm -f -- "$workspace"; fi
    if (( tasks_written )); then rm -f -- "$PROJECT/.vscode/tasks.json"; fi
    if (( package_written )); then mv "$target_package" "$transaction/failed-package"; fi
    if (( tools_written )); then mv "$target_tools" "$transaction/failed-tools"; fi
    if (( package_moved )); then mv "$transaction/previous-package" "$target_package"; fi
    if (( tools_moved )); then mv "$transaction/previous-tools" "$target_tools"; fi
    printf 'Setup interrupted. Recovery files: %s\n' "$transaction" >&2
  fi
  cleanup
}
trap rollback EXIT
cp -R "$source_package" "$transaction/package"
cp -R "$stage/tools" "$transaction/tools"
[[ "$(tree_digest "$transaction/package")" == "$source_digest" && "$(tree_digest "$transaction/tools")" == "$tools_digest" ]] || fail "Staged copy verification failed: $transaction"
if [[ "$package_state" != installed ]]; then
  if [[ -e "$target_package" ]]; then mv "$target_package" "$transaction/previous-package"; package_moved=1; fi
  mv "$transaction/package" "$target_package"; package_written=1
fi
if [[ "$tools_state" != installed ]]; then
  if [[ -e "$target_tools" ]]; then mv "$target_tools" "$transaction/previous-tools"; tools_moved=1; fi
  mv "$transaction/tools" "$target_tools"; tools_written=1
fi
mkdir -p "$PROJECT/.vscode"
if [[ ! -e "$workspace" ]]; then workspace_written=1; cp "$stage/tools/unity-simple-mcp.code-workspace" "$workspace"; fi
if [[ ! -e "$PROJECT/.vscode/tasks.json" ]]; then tasks_written=1; cp "$stage/tools/tasks.json" "$PROJECT/.vscode/tasks.json"; fi
printf '{"schemaVersion":2,"packageVersion":"%s","sourceDigest":"%s","toolsDigest":"%s"}\n' "$version" "$source_digest" "$tools_digest" > "$transaction/marker.json"
mv "$transaction/marker.json" "$marker"
committed=1
if (( package_moved || tools_moved )); then
  printf 'Previous installation retained for review: %s\n' "$transaction" >&2
else
  # The checked path was created by this invocation and contains only our copies.
  [[ "$transaction" == "$PROJECT/Packages/".simple-unity-mcp-setup-* && -d "$transaction" && ! -L "$transaction" ]] || fail "Unsafe staging cleanup: $transaction"
  rm -rf -- "$transaction"
fi
state=installed; report installed
printf 'Tool settings: %s\nVS Code: open %s\n' "$target_tools/tools.env" "$workspace" >&2
