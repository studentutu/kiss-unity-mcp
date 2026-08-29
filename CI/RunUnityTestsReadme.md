# Unity CI scripts

All shell tooling lives in `CI/bash`. Editor-side entry points live in the
`com.studentutu.unitysimplemcp` Unity package. The shell layer depends only on
the package's fully qualified execute-method API; it does not depend on project
game code.

## Commands

Run these with Bash from any working directory:

```bash
bash ./CI/bash/rebuildSolutionFromUnityItself.sh
bash ./CI/bash/rebuildSolutionWithRiderMsBuild.sh
bash ./CI/bash/compileShaders.sh
bash ./CI/bash/runTestsBash.sh
bash ./CI/bash/parseTestErrors.sh
```

`rebuildSolutionFromUnityItself.sh` is the authoritative compile/import check.
It launches the Unity version declared in `ProjectSettings/ProjectVersion.txt`,
captures the complete editor log, regenerates IDE files, and fails unless Unity
returns success, emits the editor-tool completion marker, and produces no fatal
diagnostics.

`rebuildSolutionWithRiderMsBuild.sh` is only a fast follow-up check. It cannot
discover newly added/removed Unity scripts or validate asset, shader, package,
or importer errors. Run the Unity check after changes to scripts, asmdefs,
packages, shaders, or assets.

`runTestsBash.sh` runs EditMode tests by default and validates the Unity process,
the real editor log, the test-run completion marker, and the root NUnit result.
Zero discovered tests and inconclusive tests fail. Set `FAIL_ON_SKIPPED=1` when
skipped tests must also fail CI.

`compileShaders.sh` calls
`SimpleUnityMCP.Editor.ShaderCompileTool.CompileAllProjectShaders`, reimports all
project shaders, and requires a zero Unity exit, a clean diagnostic scan, and
the `SIMPLE_UNITY_MCP_CI:SHADER_COMPILATION_PASSED` log marker.

The complete editor/MSBuild logs remain the source of truth and retain warnings.
The fatal scanner is intentionally narrower than a raw search for `Error`:
Unity routinely logs recovered licensing and helper-process errors during a
successful run. CI therefore fails on the process result, missing completion
evidence, compiler/shader/fatal signatures, or failed NUnit data instead of
pretending every line containing `Error` is fatal.

Generated artifacts are deliberately not committed:

- `CI/UnityCompile.log`
- `CI/UnityTests.log`
- `CI/RiderMsBuild.log`
- `CI/UnityShaders.log`
- `CI/CITestOutput.xml`
- `CI/CompileErrorsAfterUnityRun.txt`
- `CI/ShaderCompileErrors.txt`

## Reuse configuration

No source edit is required when this folder moves to another repository.
Defaults support either a Unity project at the repository root or under
`UnityProj`. Override only when the consumer uses a different layout:

```bash
UNITY_PROJECT_PATH=/path/to/project \
UNITY_EDITOR_PATH=/path/to/Unity \
CI_OUTPUT_DIR=/path/to/artifacts \
bash ./CI/bash/runTestsBash.sh
```

Other optional overrides are `UNITY_TEST_PLATFORM`, `UNITY_SOLUTION_PATH`, and
`RIDER_MSBUILD`. Windows overrides supplied to Git Bash may use either Windows
or Unix-style paths.

Close interactive Unity instances for the same project before launching a
headless command. Unity locks a project against concurrent editor processes.

## VS Code tasks

The workspace tasks do not hard-code a Bash executable. They launch scripts via
Git's temporary shell alias:

```text
git -c alias.run-bash=!bash run-bash ./CI/bash/<script>.sh
```

This uses Git for Windows' bundled Bash on Windows and the normal `bash` command
on macOS/Linux. It avoids confusing Windows' `bash.exe` WSL launcher with Git
Bash and does not assume where Git was installed. `git` must be available on
`PATH`; macOS/Linux must also provide `bash`.
