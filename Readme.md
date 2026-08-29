# Simple Unity MCP

Editor-side tools for a headless, agent-friendly Unity workflow. The package is
the Unity boundary: reusable Bash orchestration stays in the consumer
repository's `CI/bash` directory and calls only stable, fully qualified methods.

## Requirements

- Unity 2023.1 or newer (required by Addressables 2.9.1)
- Unity Test Framework for the included package tests
- Addressables and Scriptable Build Pipeline (declared package dependencies) for
  the cache-cleaning editor utilities

See the consumer repository's `CI/RunUnityTestsReadme.md` for command-line use
and environment overrides.

## Optional (quality of life)

- VsCode as this repository provides manual tasks to run the actual tools from the `.vscode/tasks.json`, handy to for manual check/debugging/diagnostics

## Tool reference

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
