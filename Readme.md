# Unity Simple MCP

The `studentutu` marketplace contains the `unity-simple-mcp` plugin at this
repository root. Setup and MCP transport use **Bash 3.2+, Git, and standard Unix
utilities**. Git for Windows supplies these on Windows; macOS/Linux need Git and
Bash. No Node, Python, jq, package manager, or runtime download is used.

Unity and a compatible Rider/MSBuild toolchain are required only for build work.
A Bash script cannot compile C# without a compiler. Setup installs neither an SDK
nor Unity packages. Tests require the consuming project to already have Unity
Test Framework. The embedded package has no package dependencies.

## Set up one Unity project

From this checkout or the installed plugin directory, in Bash/Git Bash:

```bash
bash scripts/setup-unity-project.sh "/path/to/Unity project" --dry-run
bash scripts/setup-unity-project.sh "/path/to/Unity project"
```

The project must already contain `Assets`, `Packages`, and
`ProjectSettings/ProjectVersion.txt`. Setup is filesystem-only and writes:

- `Packages/com.studentutu.unitysimplemcp`: reusable editor code.
- `.unity-simple-mcp`: a self-contained copy of the Bash commands and `tools.env`.
- `ProjectSettings/SimpleUnityMcpSetup.json`: installation digests.
- `.vscode/unity-simple-mcp.code-workspace`: a dedicated workspace with tasks.
- `.vscode/tasks.json`: only when that file does not already exist.

The package manifest and existing VS Code tasks stay intact. Repeating setup is
a no-op for matching content, including user-edited `tools.env`. Conflicting
package/tool files stop setup. Review differences before an intentional update:

```bash
bash scripts/setup-unity-project.sh "/path/to/Unity project" --replace
```

Replacement preserves `tools.env` and keeps the previous directories under
`Packages/.simple-unity-mcp-setup-<pid>/` for recovery. Remove those backups after
review. Source/copy byte digests detect damaged copies; they are not signatures.
Symlinks, special files, and newline-containing package filenames are rejected.
Setup never starts Unity or modifies `Packages/manifest.json`.

## Manual use without an agent

Open the project in VS Code and choose **Terminal > Run Task > Unity MCP**.
If the project already had tasks, open its generated
`.vscode/unity-simple-mcp.code-workspace` to access the additional tasks.
Use **Check tool paths**, **Import and generate solution**, then **Fast MSBuild**.
**Open tool settings** opens the one configuration file. It uses VS Code's `code`
CLI; if that CLI is not on PATH, open `.unity-simple-mcp/tools.env` in the Explorer.

The equivalent commands from the Unity project root are:

```bash
bash .unity-simple-mcp/scripts/unity.sh doctor
bash .unity-simple-mcp/scripts/unity.sh import
bash .unity-simple-mcp/scripts/unity.sh build
bash .unity-simple-mcp/scripts/unity.sh tests
bash .unity-simple-mcp/scripts/unity.sh shaders
bash .unity-simple-mcp/scripts/unity.sh parse-tests
```

Commands work from another directory when given an explicit project path. The
installed scripts do not depend on the marketplace cache or this checkout.
Windows tasks launch through Git's temporary Bash alias to avoid the Windows WSL
`bash.exe` launcher. `git` must be on PATH. Use Git Bash, not WSL, for Windows Unity.

## Select tools per project

Edit `.unity-simple-mcp/tools.env`. This is a data file, not sourced shell code:
`KEY=value`, optional surrounding quotes, absolute paths, no variable expansion.
Spaces and Windows paths are supported. Environment overrides take precedence.

| Setting | Purpose |
| --- | --- |
| `UNITY_HUB_EDITOR_ROOT` | Directory containing versioned Unity installations |
| `UNITY_EDITOR_PATH` | Optional exact versioned editor executable |
| `RIDER_ROOT` | Rider installation/application directory |
| `RIDER_MSBUILD` | Explicit MSBuild executable, launcher, or DLL |
| `MSBUILD_RUNTIME` | Compatible runtime executable when using a DLL or Mono EXE |
| `UNITY_SOLUTION_PATH` | Explicit solution when automatic selection is ambiguous |

Unity always matches `m_EditorVersion` exactly. The default Hub roots are
`C:/Program Files/Unity/Hub/Editor`, `/Applications/Unity/Hub/Editor`, and
`~/Unity/Hub/Editor`. Every Unity-backed operation, including fast MSBuild, lists
installed editors and verifies the required executable. It never substitutes
another version or searches PATH for Unity. Change the project version through
Unity's normal upgrade workflow; changing tool settings does not upgrade it.

Rider auto-discovery covers common installation locations and stops on ambiguity.
For Toolbox/custom installations, copy the actual MSBuild path from Rider's
**Settings > Build, Execution, Deployment > Toolset and Build**. macOS/Linux
installations may require a compatible Mono or dotnet host and reference
assemblies from the existing toolchain. Configure those explicitly; setup does
not download them. See [Rider's toolset documentation](https://www.jetbrains.com/help/rider/Settings_Toolset_and_Build.html).

## What a passing command proves

Full logs live in `Logs/SimpleUnityMcp` inside the Unity project:

| Operation | Authoritative evidence |
| --- | --- |
| Import | `UnityCompile.log`, completion marker, generated solution, clean diagnostics |
| Fast build | `RiderMsBuild.log` at diagnostic verbosity, process status, success summary |
| Tests | `UnityTests.log`, fresh `CITestOutput.xml`, completion marker, consistent NUnit counts |
| Shaders | `UnityShaders.log`, shader pass marker, clean diagnostics |

Console output and extracted diagnostics are indexes into those logs. The Unity
scanner catches import failures, script exceptions, compiler and shader errors,
including errors emitted despite exit code zero. Specific licensing startup
errors are treated as recovered only when the same log proves license recovery.
Unity has no universal structured log schema; retain the complete logs when
reporting a new failure signature. Shader checking covers imported shaders and
Unity's reported errors, not every platform/keyword variant in a player build.

Import records a snapshot of file names, non-C# inputs, resolved package data,
and generated projects. Fast build uses incremental `/t:Build` and accepts edits
to existing `.cs` contents. Added/removed files or changed assets, asmdefs,
packages, settings, or generated projects require another import. C# changes to
importers, compilation directives, or editor initialization also require import;
MSBuild cannot detect or execute those Unity semantics.

Close interactive Unity before headless commands. The scripts refuse an existing
Unity lock and serialize verification per project. They never kill your editor.
Failures keep full logs. Exit codes are `0` verified success, `1` infrastructure /
compile / import failure, and `2` failed or inconclusive tests. No discovered tests
is a failure. `FAIL_ON_SKIPPED=1` also rejects skipped tests.

## Agent and repository development

MCP exposes inspection, explicit setup, doctor, import, fast build, tests, and
shader checks. It is a thin sequential adapter over the same Bash API, using
[newline-delimited JSON-RPC over stdio](https://modelcontextprotocol.io/specification/2025-06-18/basic/transports).
Run it with `bash scripts/mcp-server.sh`; stdout contains protocol messages only.
No conflicting replacement operation is exposed through MCP.

```bash
bash scripts/validate-plugin.sh
bash scripts/test-workflow.sh
bash scripts/unity.sh doctor "/path/to/project"
bash scripts/verify-unity-workflow.sh "/path/to/disposable-project"
```

`CI/bash` is authoritative; legacy `bash/` commands forward there. Automated
portable contracts cover setup, protocol handling, platform path resolution,
log classification, NUnit structure/counts, and stale input rejection. The CI
matrix runs these Bash contracts on Windows, macOS, and Linux. Actual editor and
Rider validation must also run on each target OS before claiming native coverage.
The integration script temporarily adds a compiler/importer/test/shader fixture,
checks intentional failure and restored success, removes the fixture, and leaves
per-step full logs under `Logs/SimpleUnityMcp/Verification-<timestamp>`.
The package ships no runtime scaffolding or empty sample tests; projects with no
tests fail the test command instead of receiving an artificial green result.

The marketplace entry stays at `.agents/plugins/marketplace.json`, uses the remote
repository URL, and tracks `master`. Keep plugin/package versions equal. Local
edits do not publish a release. Publish only after explicit authorization and
successful validation; installation/upgrading the developer's marketplace is a
separate user action.
