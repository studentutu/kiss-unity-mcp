# Agent workflow

Use `rg` for search. Keep changes surgical. Verify through the repository entry
points below; do not call Unity or MSBuild with ad-hoc paths.

## Prerequisite: resolve the Unity editor

Before any CI/tool workflow, read the project's required Unity version and scan
the platform's Unity Hub editor root. This is mandatory before every Unity-backed
tool call. Never assume `Unity` is on `PATH`, and never substitute the newest or
closest installed version for the project's exact `m_EditorVersion`.

| Platform | Unity Hub editor root | Editor executable below the version directory |
| --- | --- | --- |
| macOS | `/Applications/Unity/Hub/Editor` | `Unity.app/Contents/MacOS/Unity` |
| Windows (Git Bash) | `/c/Program Files/Unity/Hub/Editor` | `Editor/Unity.exe` |
| Linux | `~/Unity/Hub/Editor` | `Editor/Unity` |

Run this once at the start of the workflow. It lists every installed editor,
requires an exact project-version match, and gives all later scripts one explicit
editor path:

```bash
unity_project="${UNITY_PROJECT_PATH:-./UnityProj}"
version_file="$unity_project/ProjectSettings/ProjectVersion.txt"
required_version="$(sed -n 's/^m_EditorVersion:[[:space:]]*//p' "$version_file" | tr -d '\r' | head -n 1)"

case "$(uname -s)" in
  Darwin*) unity_hub_root="/Applications/Unity/Hub/Editor"; editor_suffix="Unity.app/Contents/MacOS/Unity" ;;
  MINGW*|MSYS*|CYGWIN*) unity_hub_root="/c/Program Files/Unity/Hub/Editor"; editor_suffix="Editor/Unity.exe" ;;
  Linux*) unity_hub_root="$HOME/Unity/Hub/Editor"; editor_suffix="Editor/Unity" ;;
  *) printf 'Unsupported host OS: %s\n' "$(uname -s)" >&2; exit 1 ;;
esac

[[ -n "$required_version" ]] || { printf 'Missing m_EditorVersion in %s\n' "$version_file" >&2; exit 1; }
[[ -d "$unity_hub_root" ]] || { printf 'Unity Hub editor root not found: %s\n' "$unity_hub_root" >&2; exit 1; }

shopt -s nullglob
installed_editors=("$unity_hub_root"/*)
shopt -u nullglob
printf 'Installed Unity editors under %s:\n' "$unity_hub_root"
((${#installed_editors[@]})) && printf '  %s\n' "${installed_editors[@]##*/}"

unity_editor="$unity_hub_root/$required_version/$editor_suffix"
[[ -x "$unity_editor" ]] || {
  printf 'Required Unity %s is not installed at %s\n' "$required_version" "$unity_editor" >&2
  exit 1
}
export UNITY_EDITOR_PATH="$unity_editor"
```

If the exact editor is absent, stop and report the required and installed versions.
Do not start `process_task`, Unity, MSBuild, tests, shader compilation, or a new
Unity-driven tool call until this gate passes.

## CI quick reference

Run commands from the repository root. Direct Bash and the matching VS Code task
execute the same script. VS Code uses the portable transport
`git -c alias.run-bash=!bash run-bash <script>` so Git for Windows selects its
bundled Bash without a hard-coded installation path.

| Intent | Bash command | Cost and use | Evidence |
|---|---|---|---|
| Quick C# compile | `bash ./CI/bash/rebuildSolutionWithRiderMsBuild.sh` | Fast. Use only when the generated solution is current and no `.cs`, asmdef, package, shader, or asset was added/removed. | `CI/RiderMsBuild.log`, `CI/CompileErrorsAfterUnityRun.txt` |
| Long Unity compile/import | `bash ./CI/bash/rebuildSolutionFromUnityItself.sh` | Authoritative after new/deleted script/asmdef/package/asset changes. Regenerates IDE files. Close this project's interactive Unity editor first. | `CI/UnityCompile.log`, `CI/CompileErrorsAfterUnityRun.txt`, `PROJECT_FILES_SYNCED` marker |
| Test run | `bash ./CI/bash/runTestsBash.sh` | Launches Unity EditMode tests and immediately parses the fresh result. Close this project's editor first. | `CI/UnityTests.log`, `CI/CITestOutput.xml`, terminal summary |
| Test parse only | `bash ./CI/bash/parseTestErrors.sh` | Fast; does not launch Unity. Re-checks the most recent test log/XML and prints failed test details. | Reads `CI/UnityTests.log` and `CI/CITestOutput.xml`; updates `CI/CompileErrorsAfterUnityRun.txt` |
| Long shader compile | `bash ./CI/bash/compileShaders.sh` | Reimports and validates every project shader. Use after shader/HLSL changes. Close this project's editor first. | `CI/UnityShaders.log`, `CI/ShaderCompileErrors.txt`, `SHADER_COMPILATION_PASSED` marker |

Exit codes are part of the API: `0` means verified success, `1` means tool,
compile, log, or infrastructure failure, and `2` means failed/inconclusive tests.
Never report success from terminal appearance alone. Generated CI artifacts are
ignored by Git and must be fresh for the current process invocation.

More information on the specific tasks: read `CI\RunUnityTestsReadme.md`.

### Agent execution contract

```text
agent tool-call / VS Code process task
  -> Bash entry point in CI/bash
  -> unity-ci-common.sh resolves repo, project, editor, and output paths
  -> truncate explicit output files (stale evidence cannot pass)
  -> run Unity/MSBuild and wait for process end
  -> capture the real process exit code (might be un-available, then see actual full log-artifact)
  -> require a non-empty full log plus command-specific marker/artifact
  -> extract actionable diagnostics into CI/*.txt (from full log-artifact)
  -> Bash exits with the verified result
  -> agent reads terminal summary, then the named log/XML (output from artifact-lof from CI/*.txt) on any failures
```

For Unity commands, success requires all relevant signals: process exit `0`, a
fresh non-empty real log, the expected success marker, and no extracted fatal
diagnostics. Tests additionally require valid NUnit XML, at least one discovered
test, and a passing root `<test-run>`. A raw search for `Error` is not sufficient:
Unity logs recovered licensing/helper errors during successful runs, so use the
script's classifier and preserve the complete log for investigation.

Default paths can be overridden without editing scripts:

```bash
UNITY_PROJECT_PATH=/path/to/UnityProject \
UNITY_EDITOR_PATH=/path/to/Unity \
CI_OUTPUT_DIR=/path/to/artifacts \
bash ./CI/bash/runTestsBash.sh
```

## Adding a new tool call

Example of adding unity-driven tool call:

Add one thin vertical slice; do not invent a framework.

1. Add the editor method under
   `UnityProj/Packages/com.studentutu.unitysimplemcp/Editor` and its existing
   editor asmdef. Use a fully qualified stable name such as
   `SimpleUnityMCP.Editor.BuildTool.BuildAndExit`.
2. Make the method synchronous when possible. Emit exactly one stable pass or
   fail marker and call `EditorApplication.Exit(0|1)`. If compilation/domain
   reload is required, persist state with `SessionState`; normal static callbacks
   are destroyed by reload. See `CiTools.ForceCompileAndExit`.
3. Add one Bash wrapper only under `CI/bash`. Source `unity-ci-common.sh`, use a
   unique full log and diagnostic file, preserve the Unity exit code, require the
   pass marker, run `extract_unity_diagnostics`, and propagate failure.
4. Add a VS Code `process` task using the same portable Git/Bash transport.
5. Ignore generated artifacts, document their paths, then red/green test the
   complete task: intentional failure must produce non-zero exit plus actionable
   real-log evidence; restored input must produce exit `0`, pass marker, and an
   empty diagnostic file.

Minimal editor-side build shape:

```csharp
using UnityEditor;
using UnityEditor.Build.Reporting;
using UnityEngine;

namespace SimpleUnityMCP.Editor
{
    public static class BuildTool
    {
        public const string Passed = "SIMPLE_UNITY_MCP_CI:BUILD_PASSED";
        public const string Failed = "SIMPLE_UNITY_MCP_CI:BUILD_FAILED";

        public static void BuildAndExit()
        {
            BuildReport report = BuildPipeline.BuildPlayer(CreateBuildOptions());
            bool passed = report.summary.result == BuildResult.Succeeded;
            Debug.Log($"{(passed ? Passed : Failed)} result={report.summary.result}");
            EditorApplication.Exit(passed ? 0 : 1);
        }

        private static BuildPlayerOptions CreateBuildOptions()
        {
            // Project-specific scenes, target, and output belong here.
            throw new System.NotImplementedException();
        }
    }
}
```

Minimal Bash wrapper shape (copy an existing wrapper and keep this contract):

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "$SCRIPT_DIR/unity-ci-common.sh"
require_unity_project

UNITY_EDITOR="$(resolve_unity_editor)"
LOG="$(to_unix_path "${UNITY_BUILD_LOG_PATH:-$CI_OUTPUT_DIR/UnityBuild.log}")"
DIAGNOSTICS="$(to_unix_path "${UNITY_BUILD_DIAGNOSTICS_PATH:-$CI_OUTPUT_DIR/BuildErrors.txt}")"
prepare_output_file "$LOG"

set +e
"$UNITY_EDITOR" -batchmode -nographics -projectPath "$UNITY_PROJECT_PATH" \
  -logFile "$LOG" -executeMethod SimpleUnityMCP.Editor.BuildTool.BuildAndExit
tool_exit=$?
set -e

require_nonempty_file "$LOG" "Unity build log"
extract_unity_diagnostics "$LOG" "$DIAGNOSTICS"
(( tool_exit == 0 )) || exit "$tool_exit"
grep -qF 'SIMPLE_UNITY_MCP_CI:BUILD_PASSED' "$LOG" || exit 1
[[ ! -s "$DIAGNOSTICS" ]] || exit 1
```

Matching VS Code task shape:

```json
{
  "label": "Build Unity Player",
  "type": "process",
  "command": "git",
  "args": ["-c", "alias.run-bash=!bash", "run-bash", "./CI/bash/buildPlayer.sh"],
  "options": { "cwd": "${workspaceFolder}" },
  "problemMatcher": []
}
```
