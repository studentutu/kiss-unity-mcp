# kiss-unity-mcp

Separate marketplace that contains `kiss-unity-mcp` plugin.

Use `kiss-unity-mcp` for the plugin and MCP server, `kiss-unity-mcp-*` for
skills (for example, `$kiss-unity-mcp-import`), and `kiss-unity-mcp:` for VS Code
tasks. This is a separate integration from `unity-mcp` / `unity-cli`.
MCP tool names such as `unity_import` belong to the `kiss-unity-mcp` server.

Editor-side tools for a headless, agent-friendly Unity workflow.
The package is the Unity boundary: reusable Bash orchestration stays in the consumer repository's CI/bash directory and calls only stable, fully qualified methods.

## Why this exists?

All unity related MCP always skip proper manual validations/ci/different-os/tries to sell bloatware.

**All you need is bash, unity and Rider(MsBuild).**

Developer must have a proper control over the tools used, including:

- optional override path to the tools such as unity-editor, rider(msbuild), so it will work in cases for CI/OS/headless/ssh(docker, podman).
- the same compilation and verification tools as is used by the agent.

## Quick Navigation

- [Requirements](#requirements)
- [Install](#install)
- [Use Cases](#use-cases)
- [Optional overwrite tool path](#optional-overwrite-tool-path)
- [Repository development](#repository-development)

## Requirements

- **Bash 3.2+, Git, and standard Unix
utilities**. Git for Windows supplies these on Windows; macOS/Linux need Git and
Bash. No Node, Python, jq, package manager, or runtime download is used.
- Unity Editor
- MSBuild/Rider

Optionally:

- vscode for friendly developer compilation workflows.

## Install

### Agents

1. Add this repository as a **marketplace**. Different setup for each of the harnesses codex/claude/gemini.
2. Enable **`kiss-unity-mcp` plugin** from **@studentutu** marketplace.
3. Ask agent to setup a given unity project afterwards (one time setup per unity project is required).

### Manual setup (without agents)

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

## Use Cases

Full logs live in `Logs/SimpleUnityMcp` inside the Unity project:

| Operation | Authoritative evidence |
| --- | --- |
| Import | `UnityCompile.log`, long compilation (scripts/dll/plugins added/removed), generated solution, clean diagnostics |
| Fast build | `RiderMsBuild.log` fast-compilation (change in existing scripts), process status, success summary |
| Tests | `UnityTests.log`, fresh `CITestOutput.xml`, completion marker, consistent NUnit counts |
| Shaders | `UnityShaders.log`, shader pass marker, clean diagnostics |

The equivalent commands from the Unity project root (after setup) are:

```bash
bash .unity-simple-mcp/scripts/unity.sh doctor
bash .unity-simple-mcp/scripts/unity.sh import
bash .unity-simple-mcp/scripts/unity.sh build
bash .unity-simple-mcp/scripts/unity.sh tests
bash .unity-simple-mcp/scripts/unity.sh shaders
bash .unity-simple-mcp/scripts/unity.sh parse-tests
```

### Manual use without agents

Open the project in VS Code and choose **Terminal > Run Task > kiss-unity-mcp**.

### Details on vscode and bash use

If the project already had tasks, open its generated
`.vscode/unity-simple-mcp.code-workspace` to access the additional tasks (copy them to your `.vscode/tasks.json` in case you don't want to override it, but need them).
Use **Check tool paths**, **Import and generate solution**, then **Fast MSBuild**.
Use **EditMode tests** to run all tests, or **Parse test results** to inspect
existing NUnit XML and the matching Unity log without launching Unity.
**Open tool settings** opens the one configuration file. It uses VS Code's `code`
CLI; if that CLI is not on PATH, open `.unity-simple-mcp/tools.env` in the Explorer.

Commands work from another directory when given an explicit project path. The
installed scripts do not depend on the marketplace cache or this checkout.
Windows tasks launch through Git's temporary Bash alias to avoid the Windows WSL
`bash.exe` launcher. `git` must be on PATH. Use Git Bash, not WSL, for Windows Unity.

For already set projects, deliberately merge the new task from the templates
into their existing tasks/workspace. Verify that setup command was successful and that user can run task from within the bash shell and reach unity compilation.

### Agents and end-user task skills

The [skill catalog](skills/README.md) exposes the seven actions in
`templates/tasks.json`: tool-path checks, import, fast MSBuild, EditMode tests,
parsing saved test results, shader compilation, and tool settings, plus the
[explicit one-time setup skill](skills/kiss-unity-mcp-setup/SKILL.md). Each includes
manual usage, prerequisites, and evidence to check; MCP is optional. Start with the
[shared manual workflow](skills/manual-workflow.md) for absolute paths, VS Code,
CI/SSH usage, and the exact editor gate. Setup is the sole non-task skill and never
a routine preamble. The
[run-parsetests skill](skills/kiss-unity-mcp-run-parsetests/SKILL.md) uses the
same `parse-tests` action as the manual task. Compatibility wrappers and repository
maintenance remain documented manual APIs, not skills.

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

The marketplace entry stays at `.agents/plugins/marketplace.json`, uses the remote
repository URL, and tracks `master`. Keep plugin/package versions equal. Local
edits do not publish a release. Publish only after explicit authorization and
successful validation; installation/upgrading the developer's marketplace is a
separate user action.

## Optional overwrite tool path

Sometimes CI/docker/podman requires more strict access and thus requires custom path to tools.

Unity and a compatible Rider/MSBuild toolchain are required only for build work.
A Bash script cannot compile C# without a compiler. Setup installs only template files and local package for this mcp.
Tests require the consuming project to already have Unity
Test Framework. The embedded package has no package dependencies.

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

## Repository development

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

### What a passing command proves (what all of this actual do)

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