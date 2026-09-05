#!/usr/bin/env bash
# Filesystem/protocol/log regression tests; never launches an installed editor.
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/common.sh"
root="$(cd "$TOOLS_SCRIPT_DIR/.." && pwd -P)"
work="$(mktemp -d "${TMPDIR:-/tmp}/kissunitymcp-tests.XXXXXXXX")"
[[ "$work" == "${TMPDIR:-/tmp}"/kissunitymcp-tests.* ]] || fail 'Unsafe test directory'
trap 'rm -rf -- "$work"' EXIT
checks=0
expect_exit() {
  local expected="$1" actual; shift
  set +e; ("$@") > "$work/last.log" 2>&1; actual=$?; set -e
  if (( actual!=expected )); then cat "$work/last.log" >&2; fail "Expected exit $expected, got $actual: $*"; fi
  checks=$((checks+1))
}

# Validate task skills plus the setup exception in an isolated copy.
validation_root="$work/Plugin validation"
mkdir "$validation_root"
cp -R "$root/.codex-plugin" "$root/.agents" "$root/.mcp.json" "$root/scripts" \
  "$root/templates" "$root/com.studentutu.kissunitymcp" "$root/CI" \
  "$root/bash" "$root/skills" "$validation_root/"
validator="$validation_root/scripts/validate-plugin.sh"
skill="$validation_root/skills/kiss-unity-mcp-doctor/SKILL.md"
cp "$skill" "$work/doctor-skill.md"
expect_exit 0 bash "$validator"
setup_skill="$validation_root/skills/kiss-unity-mcp-setup"
mv "$setup_skill" "$work/setup-skill"
expect_exit 1 bash "$validator"
grep -qF 'Missing required setup skill' "$work/last.log" || fail 'Missing setup skill accepted'
mv "$work/setup-skill" "$setup_skill"
cp "$setup_skill/SKILL.md" "$work/setup-skill.md"
printf '\nTask: kiss-unity-mcp: Check tool paths\n' >> "$setup_skill/SKILL.md"
expect_exit 1 bash "$validator"
grep -qF 'Setup skill must remain separate from VS Code tasks' "$work/last.log" || fail 'Setup claimed a task'
cp "$work/setup-skill.md" "$setup_skill/SKILL.md"
expect_exit 0 bash "$validator"
sed 's/^name: kiss-unity-mcp-doctor$/name: wrong-name/' "$work/doctor-skill.md" > "$skill"
expect_exit 1 bash "$validator"
grep -qF 'Skill name must match directory' "$work/last.log" || fail 'Wrong skill-name diagnostic'
printf '%s\n' '---' 'name: kiss-unity-mcp-doctor' 'description: Missing closing delimiter' > "$skill"
expect_exit 1 bash "$validator"
grep -qF 'Invalid skill frontmatter' "$work/last.log" || fail 'Unclosed skill frontmatter accepted'
cp "$work/doctor-skill.md" "$skill"
sed '/^## Manual usage$/d' "$work/doctor-skill.md" > "$skill"
expect_exit 1 bash "$validator"
grep -qF 'Missing ## Manual usage' "$work/last.log" || fail 'Missing manual usage accepted'
cp "$work/doctor-skill.md" "$skill"
printf '\n```bash\nif then\n```\n' >> "$skill"
expect_exit 1 bash "$validator"
grep -qF 'Invalid Bash example' "$work/last.log" || fail 'Invalid manual Bash example accepted'
cp "$work/doctor-skill.md" "$skill"
sed 's/^Task: .*/Task: kiss-unity-mcp: Internal maintenance/' "$work/doctor-skill.md" > "$skill"
expect_exit 1 bash "$validator"
grep -qF 'Skill task is not in templates/tasks.json' "$work/last.log" || fail 'Non-task skill accepted'
cp "$work/doctor-skill.md" "$skill"
sed 's/^Task: .*/Task: kiss-unity-mcp: Fast MSBuild/' "$work/doctor-skill.md" > "$skill"
expect_exit 1 bash "$validator"
grep -qF 'End-user task must have exactly one skill' "$work/last.log" || fail 'Duplicate task skills accepted'
cp "$work/doctor-skill.md" "$skill"
mv "$validation_root/skills/kiss-unity-mcp-doctor" "$work/doctor-skill"
expect_exit 1 bash "$validator"
grep -qF 'End-user task must have exactly one skill' "$work/last.log" || fail 'Missing task skill accepted'
mv "$work/doctor-skill" "$validation_root/skills/kiss-unity-mcp-doctor"
mv "$validation_root/skills/kiss-unity-mcp-doctor/agents/openai.yaml" "$work/doctor-ui.yaml"
expect_exit 1 bash "$validator"
grep -qF 'Missing skill UI metadata' "$work/last.log" || fail 'Missing skill UI metadata accepted'
mv "$work/doctor-ui.yaml" "$validation_root/skills/kiss-unity-mcp-doctor/agents/openai.yaml"
expect_exit 0 bash "$validator"

project="$work/Project with spaces"
mkdir -p "$project/Assets" "$project/Packages" "$project/ProjectSettings"
printf 'm_EditorVersion: 6000.3.15f1\r\n' > "$project/ProjectSettings/ProjectVersion.txt"
printf '{"dependencies":{}}\n' > "$project/Packages/manifest.json"
manifest_before="$(git hash-object "$project/Packages/manifest.json")"
expect_exit 0 bash "$root/scripts/setup-unity-project.sh" "$project" --dry-run
[[ "$(json_get "$work/last.log" /state)" == not_installed && ! -e "$project/.kissunitymcp" ]] || fail 'Dry run mutated project'
expect_exit 0 bash "$root/scripts/setup-unity-project.sh" "$project"
[[ -f "$project/.vscode/tasks.json" && -f "$project/.kissunitymcp/tools.env" ]] || fail 'Manual workflow missing'
[[ -f "$project/ProjectSettings/kissunitymcp.json" &&
   "$(json_get "$project/Packages/com.studentutu.kissunitymcp/package.json" /name)" == com.studentutu.kissunitymcp ]] || fail 'Installed package or setup marker has the wrong identity'
expect_exit 0 bash "$root/scripts/setup-unity-project.sh" "$project"
[[ "$(json_get "$work/last.log" /action)" == already_installed ]] || fail 'Setup not idempotent'
printf '\nRIDER_ROOT=/custom rider\n' >> "$project/.kissunitymcp/tools.env"
expect_exit 0 bash "$root/scripts/setup-unity-project.sh" "$project"
grep -q '/custom rider' "$project/.kissunitymcp/tools.env" || fail 'Setup overwrote config'
printf '\nchanged\n' >> "$project/Packages/com.studentutu.kissunitymcp/README.md"
expect_exit 1 bash "$root/scripts/setup-unity-project.sh" "$project"
expect_exit 0 bash "$root/scripts/setup-unity-project.sh" "$project" --replace
[[ "$manifest_before" == "$(git hash-object "$project/Packages/manifest.json")" ]] || fail 'Setup mutated manifest'

# Former paths must block duplicate installs, including an explicit --replace.
legacy_project="$work/Legacy installation"
mkdir -p "$legacy_project/Assets" "$legacy_project/Packages" "$legacy_project/ProjectSettings" "$legacy_project/.vscode"
cp "$project/ProjectSettings/ProjectVersion.txt" "$legacy_project/ProjectSettings/"
for legacy_path in Packages/com.studentutu.unitysimplemcp .unity-simple-mcp \
  ProjectSettings/SimpleUnityMcpSetup.json .vscode/unity-simple-mcp.code-workspace \
  ProjectSettings/.SimpleUnityMcpRun.lock ProjectSettings/.SimpleUnityMcpSetup.lock; do
  mkdir "$legacy_project/$legacy_path"
  legacy_before="$(tree_digest "$legacy_project")"
  expect_exit 0 bash "$root/scripts/setup-unity-project.sh" "$legacy_project" --dry-run
  sed -n '/^{/p' "$work/last.log" > "$work/inspection.json"
  [[ "$(json_get "$work/inspection.json" /state)" == conflict ]] || fail 'Inspection missed legacy installation'
  expect_exit 1 bash "$root/scripts/setup-unity-project.sh" "$legacy_project"
  expect_exit 1 bash "$root/scripts/setup-unity-project.sh" "$legacy_project" --replace
  grep -qF 'Legacy installation paths require migration' "$work/last.log" || fail 'Missing migration diagnostic'
  [[ "$legacy_before" == "$(tree_digest "$legacy_project")" &&
     ! -e "$legacy_project/Packages/com.studentutu.kissunitymcp" &&
     ! -e "$legacy_project/.kissunitymcp" ]] || fail 'Legacy installation was mutated'
  rmdir "$legacy_project/$legacy_path"
done

# Existing JSONC user tasks must be preserved byte-for-byte.
project2="$work/Existing tasks"
mkdir -p "$project2/Assets" "$project2/Packages" "$project2/ProjectSettings" "$project2/.vscode"
cp "$project/ProjectSettings/ProjectVersion.txt" "$project2/ProjectSettings/"
printf '// personal tasks\n{"tasks":[]}\n' > "$project2/.vscode/tasks.json"
before="$(git hash-object "$project2/.vscode/tasks.json")"
expect_exit 0 bash "$root/scripts/setup-unity-project.sh" "$project2"
[[ "$before" == "$(git hash-object "$project2/.vscode/tasks.json")" && -f "$project2/.vscode/kissunitymcp.code-workspace" ]] || fail 'Existing tasks not preserved'

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
# Manual installed CLI and compatibility aliases must parse without an editor.
expect_exit 0 bash "$project2/.kissunitymcp/scripts/unity.sh" help
expect_exit 0 bash "$project2/.kissunitymcp/scripts/unity.sh" parse-tests "$project2" --test-results "$work/results.xml" --unity-log "$work/editor.log"
expect_exit 0 bash "$project2/.kissunitymcp/CI/bash/runParsetests.sh" --test-results "$work/results.xml" --unity-log "$work/editor.log"
expect_exit 0 bash "$root/bash/parseTestErrors.sh" --test-results "$work/results.xml" --unity-log "$work/editor.log"
expect_exit 0 bash "$root/bash/runParsetests.sh" --test-results "$work/results.xml" --unity-log "$work/editor.log"
sed 's/result="Passed"/result="Failed"/g;s/passed="1"/passed="0"/;s/failed="0"/failed="1"/' "$work/results.xml" > "$work/failed.xml"
expect_exit 2 bash "$root/CI/bash/parseTestErrors.sh" --test-results "$work/failed.xml" --unity-log "$work/editor.log"
sed 's/result="Failed"/result="Failed(Child)"/' "$work/failed.xml" > "$work/child-failed.xml"
expect_exit 2 bash "$root/CI/bash/parseTestErrors.sh" --test-results "$work/child-failed.xml" --unity-log "$work/editor.log"

# Execute the actual manual task definitions, substituting VS Code variables as
# data. No eval, installed editor, or test execution is involved.
run_parse_task() (
  unset CI_OUTPUT_DIR UNITY_TEST_RESULTS_PATH UNITY_TEST_LOG_PATH UNITY_DIAGNOSTICS_PATH FAIL_ON_SKIPPED
  export UNITY_EDITOR_PATH="$work/missing-editor" RIDER_MSBUILD="$work/missing-msbuild"
  cd "$work"
  "${task_command[@]}"
)
cmp -s "$root/templates/tasks.json" "$project/.kissunitymcp/tasks.json" || fail 'Installed task template differs'
for task_file in "$project/.vscode/tasks.json" "$project2/.vscode/kissunitymcp.code-workspace" "$root/.vscode/tasks.json"; do
  task_list=/tasks; task_project="$project"; workspace_folder="$project"
  case "$task_file" in
    *.code-workspace) task_list=/tasks/tasks; task_project="$project2"; workspace_folder="$project2";;
    "$root/.vscode/tasks.json") task_project="$project2"; workspace_folder="$root";;
  esac
  json_get "$task_file" '' validate || fail "Invalid manual task JSON: $task_file"
  task_index=0; parse_task=''
  while task_label="$(json_get "$task_file" "$task_list/$task_index/label" 2>/dev/null)"; do
    if [[ "$task_label" == 'kiss-unity-mcp: Parse test results' ]]; then
      [[ -z "$parse_task" ]] || fail "Duplicate parse task: $task_file"
      parse_task="$task_list/$task_index"
    fi
    task_index=$((task_index+1))
  done
  [[ -n "$parse_task" ]] || fail "Missing parse task: $task_file"
  [[ "$(json_get "$task_file" "$parse_task/type")" == process &&
     "$(json_get "$task_file" "$parse_task/command")" == git &&
     "$(json_get "$task_file" "$parse_task/args/4")" == parse-tests ]] || fail "Parse task must use Git Bash and parse-tests: $task_file"
  [[ "$(json_get "$task_file" "$parse_task/args/3")" == '${workspaceFolder}/'*scripts/unity.sh ]] || fail "Parse task bypasses dispatcher: $task_file"
  if json_get "$task_file" "$parse_task/dependsOn" >/dev/null 2>&1; then fail "Parse task must not start another task: $task_file"; fi
  task_command=("$(json_get "$task_file" "$parse_task/command")")
  argument_index=0
  while argument="$(json_get "$task_file" "$parse_task/args/$argument_index" 2>/dev/null)"; do
    argument="${argument//'${workspaceFolder}'/$workspace_folder}"
    argument="${argument//'${input:unityProject}'/$task_project}"
    task_command+=("$argument")
    argument_index=$((argument_index+1))
  done
  task_output="$task_project/Logs/kissunitymcp"
  mkdir -p "$task_output"
  cp "$work/editor.log" "$task_output/UnityTests.log"
  cp "$work/results.xml" "$task_output/CITestOutput.xml"
  expect_exit 0 run_parse_task
  grep -qF 'Test result and Unity log are valid.' "$work/last.log" || fail 'Parse task missed success evidence'
  cp "$work/failed.xml" "$task_output/CITestOutput.xml"
  expect_exit 2 run_parse_task
  cp "$work/truncated.xml" "$task_output/CITestOutput.xml"
  expect_exit 1 run_parse_task
  cp "$work/results.xml" "$task_output/CITestOutput.xml"
  rm "$task_output/UnityTests.log"
  expect_exit 1 run_parse_task
  cp "$work/editor.log" "$task_output/UnityTests.log"
  expect_exit 0 run_parse_task
  cmp -s "$work/results.xml" "$task_output/CITestOutput.xml" &&
    cmp -s "$work/editor.log" "$task_output/UnityTests.log" || fail 'Parse task changed its inputs'
  [[ -f "$task_output/CompileErrorsAfterUnityRun.txt" && ! -s "$task_output/CompileErrorsAfterUnityRun.txt" ]] || fail 'Parse task diagnostics missing or dirty'
done

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
