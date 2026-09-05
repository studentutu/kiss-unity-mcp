#!/usr/bin/env bash
# Filesystem/protocol/log regression tests; never launches an installed editor.
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/common.sh"
root="$(cd "$TOOLS_SCRIPT_DIR/.." && pwd -P)"
work="$(mktemp -d "${TMPDIR:-/tmp}/unity-mcp-tests.XXXXXXXX")"
[[ "$work" == "${TMPDIR:-/tmp}"/unity-mcp-tests.* ]] || fail 'Unsafe test directory'
trap 'rm -rf -- "$work"' EXIT
checks=0
expect_exit() {
  local expected="$1" actual; shift
  set +e; ("$@") > "$work/last.log" 2>&1; actual=$?; set -e
  if (( actual!=expected )); then cat "$work/last.log" >&2; fail "Expected exit $expected, got $actual: $*"; fi
  checks=$((checks+1))
}
project="$work/Project with spaces"
mkdir -p "$project/Assets" "$project/Packages" "$project/ProjectSettings"
printf 'm_EditorVersion: 6000.3.15f1\r\n' > "$project/ProjectSettings/ProjectVersion.txt"
printf '{"dependencies":{}}\n' > "$project/Packages/manifest.json"
manifest_before="$(git hash-object "$project/Packages/manifest.json")"
expect_exit 0 bash "$root/scripts/setup-unity-project.sh" "$project" --dry-run
[[ "$(json_get "$work/last.log" /state)" == not_installed && ! -e "$project/.unity-simple-mcp" ]] || fail 'Dry run mutated project'
expect_exit 0 bash "$root/scripts/setup-unity-project.sh" "$project"
[[ -f "$project/.vscode/tasks.json" && -f "$project/.unity-simple-mcp/tools.env" ]] || fail 'Manual workflow missing'
expect_exit 0 bash "$root/scripts/setup-unity-project.sh" "$project"
[[ "$(json_get "$work/last.log" /action)" == already_installed ]] || fail 'Setup not idempotent'
printf '\nRIDER_ROOT=/custom rider\n' >> "$project/.unity-simple-mcp/tools.env"
expect_exit 0 bash "$root/scripts/setup-unity-project.sh" "$project"
grep -q '/custom rider' "$project/.unity-simple-mcp/tools.env" || fail 'Setup overwrote config'
printf '\nchanged\n' >> "$project/Packages/com.studentutu.unitysimplemcp/README.md"
expect_exit 1 bash "$root/scripts/setup-unity-project.sh" "$project"
expect_exit 0 bash "$root/scripts/setup-unity-project.sh" "$project" --replace
[[ "$manifest_before" == "$(git hash-object "$project/Packages/manifest.json")" ]] || fail 'Setup mutated manifest'

# Existing JSONC user tasks must be preserved byte-for-byte.
project2="$work/Existing tasks"
mkdir -p "$project2/Assets" "$project2/Packages" "$project2/ProjectSettings" "$project2/.vscode"
cp "$project/ProjectSettings/ProjectVersion.txt" "$project2/ProjectSettings/"
printf '// personal tasks\n{"tasks":[]}\n' > "$project2/.vscode/tasks.json"
before="$(git hash-object "$project2/.vscode/tasks.json")"
expect_exit 0 bash "$root/scripts/setup-unity-project.sh" "$project2"
[[ "$before" == "$(git hash-object "$project2/.vscode/tasks.json")" && -f "$project2/.vscode/unity-simple-mcp.code-workspace" ]] || fail 'Existing tasks not preserved'

# JSON grammar, Unicode escapes, and transport framing; no shell evaluation.
printf '%s\n' '{"x":"C:\\A \u03b1 \ud83d\ude80","id":"q\"\\id"}' > "$work/json"
expect_exit 0 json_get "$work/json" '' validate
[[ "$(json_get "$work/json" /x)" == 'C:\A α 🚀' ]] || fail 'Unicode or Windows path decoding failed'
for invalid in '{"x":1,"x":2}' '{"x":01}' '{"x":1,}' '[1,]' '{"x":"\u0000"}' '{"x":"\ud800"}' '{"x":true} garbage'; do
  printf '%s\n' "$invalid" > "$work/json"; expect_exit 1 json_get "$work/json" '' validate
done
printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18"}}' \
  '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
  '{"jsonrpc":"2.0","id":"quoted\"id","method":"tools/list"}' \
  '{"jsonrpc":"2.0","id":3,"method":"ping"}' \
  '{broken}' > "$work/requests"
bash "$root/scripts/mcp-server.sh" < "$work/requests" > "$work/responses"
[[ "$(wc -l < "$work/responses" | tr -d ' ')" == 4 ]] || fail 'MCP framing or notification handling failed'
while IFS= read -r line; do printf '%s\n' "$line" > "$work/json"; expect_exit 0 json_get "$work/json" '' validate; done < "$work/responses"
printf '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"inspect_unity_project","arguments":{"project_path":%s}}}\n' "$(quote "$project2")" > "$work/requests"
bash "$root/scripts/mcp-server.sh" < "$work/requests" > "$work/response"
[[ "$(json_get "$work/response" /result/isError)" == false ]] || fail 'MCP inspection failed'
printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"setup_unity_project","arguments":{"project_path":42}}}' > "$work/requests"
bash "$root/scripts/mcp-server.sh" < "$work/requests" > "$work/response"
[[ "$(json_get "$work/response" /result/isError)" == true ]] || fail 'MCP accepted invalid path type'

# Exercise the real resolver for each platform without launching a process.
export UNITY_PROJECT_PATH="$project2"
source "$root/CI/bash/unity-ci-common.sh"
for platform in MINGW64_NT Darwin Linux; do
  case "$platform" in MINGW*) suffix=Editor/Unity.exe;; Darwin) suffix=Unity.app/Contents/MacOS/Unity;; Linux) suffix=Editor/Unity;; esac
  hub="$work/$platform hub"
  mkdir -p "$hub/6000.3.15f1/$(dirname "$suffix")"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$hub/6000.3.15f1/$suffix"
  chmod +x "$hub/6000.3.15f1/$suffix"
  export UNITY_HUB_EDITOR_ROOT="$hub"
  uname() { printf '%s\n' "$platform"; }
  expect_exit 0 resolve_unity_editor
  export UNITY_EDITOR_PATH="$hub/6000.9.99f1/$suffix"
  expect_exit 1 resolve_unity_editor
  unset UNITY_EDITOR_PATH
done
unset -f uname
unset UNITY_HUB_EDITOR_ROOT

printf '%s\n' 'Error: Import failed for Assets/Broken.asset' 'SIMPLE_UNITY_MCP_CI:PROJECT_FILES_SYNCED' > "$work/editor.log"
extract_unity_diagnostics "$work/editor.log" "$work/errors"
[[ -s "$work/errors" ]] || fail 'Missed asset import error with a success marker'
printf '%s\n' 'My import error' 'UnityEngine.Debug:LogError (object)' > "$work/editor.log"
extract_unity_diagnostics "$work/editor.log" "$work/errors"
[[ -s "$work/errors" ]] || fail 'Missed Debug.LogError'
printf '%s\n' '[Licensing::Module] Error: Access token is unavailable; failed to update' '[Licensing::Client] Successfully updated license, isAsync: True' > "$work/editor.log"
extract_unity_diagnostics "$work/editor.log" "$work/errors"
[[ ! -s "$work/errors" ]] || fail 'Recovered licensing misclassified'
printf '%s\n' '[Licensing::Module] Error: Access token is unavailable; failed to update' > "$work/editor.log"
extract_unity_diagnostics "$work/editor.log" "$work/errors"
[[ -s "$work/errors" ]] || fail 'Unrecovered licensing ignored'
printf '%s\n' 'warn: Unity.AspNetCore.NamedPipeSupport.NamedPipeServer[0]' '      Exception occured while accepting client connection: System.IO.IOException: The pipe is being closed.' > "$work/editor.log"
extract_unity_diagnostics "$work/editor.log" "$work/errors"
[[ ! -s "$work/errors" ]] || fail 'Explicit service warning misclassified'
printf '%s\n' "Start importing Packages/Universal/Shaders/FallbackError.shader using Guid(abc) (ShaderImporter) -> (artifact id: 'abc') in 0.01 seconds" > "$work/editor.log"
extract_unity_diagnostics "$work/editor.log" "$work/errors"
[[ ! -s "$work/errors" ]] || fail 'Shader filename misclassified as an import error'

printf '<test-run\n result="Passed" total="1" passed="1" failed="0" inconclusive="0" skipped="0"><test-suite><test-case result="Passed" /></test-suite></test-run>\n' > "$work/results.xml"
expect_exit 0 awk -f "$root/CI/bash/nunit-summary.awk" "$work/results.xml"
sed 's@</test-run>@@' "$work/results.xml" > "$work/truncated.xml"
expect_exit 1 awk -f "$root/CI/bash/nunit-summary.awk" "$work/truncated.xml"
sed 's/total="1"/total="2"/' "$work/results.xml" > "$work/inconsistent.xml"
expect_exit 1 awk -f "$root/CI/bash/nunit-summary.awk" "$work/inconsistent.xml"
printf 'Test run completed. Exiting with code 0\n' > "$work/editor.log"
expect_exit 0 bash "$root/CI/bash/parseTestErrors.sh" --test-results "$work/results.xml" --unity-log "$work/editor.log"
sed 's/result="Passed"/result="Failed"/g;s/passed="1"/passed="0"/;s/failed="0"/failed="1"/' "$work/results.xml" > "$work/failed.xml"
expect_exit 2 bash "$root/CI/bash/parseTestErrors.sh" --test-results "$work/failed.xml" --unity-log "$work/editor.log"
sed 's/result="Failed"/result="Failed(Child)"/' "$work/failed.xml" > "$work/child-failed.xml"
expect_exit 2 bash "$root/CI/bash/parseTestErrors.sh" --test-results "$work/child-failed.xml" --unity-log "$work/editor.log"
printf 'Error: Import failed\n' >> "$work/editor.log"
expect_exit 1 bash "$root/CI/bash/parseTestErrors.sh" --test-results "$work/failed.xml" --unity-log "$work/editor.log"

mkdir -p "$CI_OUTPUT_DIR"
printf 'class Source {}\n' > "$project2/Assets/Source.cs"
printf 'solution\n' > "$project2/a.sln"
write_import_snapshot
expect_exit 0 require_import_snapshot
printf 'class Source { int value; }\n' > "$project2/Assets/Source.cs"
expect_exit 0 require_import_snapshot
printf 'class Added {}\n' > "$project2/Assets/Added.cs"
expect_exit 1 require_import_snapshot
printf 'Workflow regressions passed (%s exit assertions plus content checks). Platform paths: Windows/macOS/Linux. Native editor not invoked.\n' "$checks"
