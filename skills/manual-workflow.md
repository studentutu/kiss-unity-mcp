# Shared manual and agent workflow

Read this before following a command skill. The repository manual is
`<plugin-root>/Readme.md`; CI details are in
`<plugin-root>/CI/RunUnityTestsReadme.md`, and editor capabilities and dependencies
are in `<plugin-root>/com.studentutu.kissunitymcp/README.md`.

These are the `kiss-unity-mcp` skills. Select MCP tools from the
`kiss-unity-mcp` server; `unity-mcp` / `unity-cli` are separate integrations.
Tool names such as `unity_import` and all Bash commands retain their existing
names. The installed `.kissunitymcp/` directory and
`kissunitymcp.code-workspace` filename are stable filesystem paths.

## Resolve paths, not the current working directory

`<plugin-root>` is the absolute plugin checkout/installation directory, two
directories above a skill's SKILL.md. `<project>` is the selected consumer Unity
project, not the plugin repository. Replace the example paths with actual absolute
paths before running commands in Bash 3.2+ or Git Bash:

```bash
PLUGIN_ROOT="/absolute/path/to/kiss-unity-mcp"
PROJECT_PATH="/absolute/path/to/Unity project"
TOOL_ROOT="$PROJECT_PATH/.kissunitymcp"
```

The installed `TOOL_ROOT` contains the manual dispatcher and authoritative CI
scripts plus their dependencies. It works without an agent, MCP, plugin cache,
Node, Python, jq, or downloads. To use the checkout's commands instead, set
`TOOL_ROOT="$PLUGIN_ROOT"`; still pass the consumer project explicitly.
Use Git Bash, not WSL, with Windows Unity. Quote paths containing spaces and pass
the project explicitly when using the dispatcher from another directory. Never
run two verification operations for one project concurrently.

## Setup is separate

Use `<plugin-root>/skills/kiss-unity-mcp-setup/SKILL.md` for inspection and
explicitly requested installation; the manual commands are also in
`<plugin-root>/Readme.md`. Do not install, replace, or rerun setup as a routine
preamble to import, build, or tests.
Missing tooling is a reason to report the setup requirement, not silently install
it. The project must already contain Assets, Packages, and
`<project>/ProjectSettings/ProjectVersion.txt`. The package supports Unity 2023.1+.
Tests require the project's existing Unity Test Framework; solution generation
requires its selected IDE integration. Setup installs neither dependency.

## Tool selection and exact editor gate

Edit `<project>/.kissunitymcp/tools.env` manually. It accepts `KEY=value` with
optional surrounding quotes, absolute native/Unix paths, no expansion, and no
shell commands. Never source it. Nonempty environment overrides take precedence.
Only these keys belong in that file:

| Key | Selection |
| --- | --- |
| `UNITY_HUB_EDITOR_ROOT` | Root containing versioned editor directories |
| `UNITY_EDITOR_PATH` | Optional exact versioned Unity executable |
| `RIDER_ROOT` | Rider application/installation directory |
| `RIDER_MSBUILD` | Explicit MSBuild executable, launcher, or DLL |
| `MSBUILD_RUNTIME` | Compatible runtime for a DLL or non-Windows Mono EXE |
| `UNITY_SOLUTION_PATH` | Explicit solution when automatic selection is ambiguous |

Before every Unity-backed operation, including fast MSBuild, read the exact
`m_EditorVersion` from `<project>/ProjectSettings/ProjectVersion.txt`. The supported
wrappers list every installed editor and resolve/export `UNITY_EDITOR_PATH`
before launching a tool. Require an exact version directory and executable:

| Platform | Default Hub editor root | Executable below the exact version |
| --- | --- | --- |
| Windows / Git Bash | `/c/Program Files/Unity/Hub/Editor` | `Editor/Unity.exe` |
| macOS | `/Applications/Unity/Hub/Editor` | `Unity.app/Contents/MacOS/Unity` |
| Linux | `$HOME/Unity/Hub/Editor` | `Editor/Unity` |

Custom installations must preserve the versioned layout and configure the Hub
root as well as any editor override. An explicit executable does not bypass the
Hub-root check. Never select the nearest/newest editor or Unity from PATH. On
failure, stop and report the required version, installed versions, and settings
path. Do not change ProjectVersion.txt to make a command pass.

Save work and close interactive Unity for this project before headless operations.
Never kill an editor or delete its lock automatically. Check active processes
before handling stale `<project>/Temp/UnityLockfile`,
`<project>/ProjectSettings/.kissunitymcp-run.lock`, or setup locks.
Filesystem-only inspection/setup, parsing existing test results, and opening tool
settings do not require an installed Unity editor. Parse-only does not take a run
lock; wait for test/import operations to finish writing the selected artifacts.

## Manual VS Code, CI, SSH, and headless use

Open `<project>/.vscode/kissunitymcp.code-workspace` and use **Terminal > Run
Task > kiss-unity-mcp**. Existing `<project>/.vscode/tasks.json` is preserved; use the
dedicated workspace or deliberately merge selected tasks yourself. **Open tool
settings** needs the `code` CLI; otherwise open tools.env in the Explorer.

The CLI examples run the same workflow as the tasks. MCP equivalents are listed
where available; opening settings and parse-only have no MCP tool. CI, SSH,
containers, and custom installations use explicit paths and the existing licensed toolchain;
these scripts do not install a compiler, runtime, or license.

**kiss-unity-mcp: Parse test results** uses `unity.sh parse-tests`, not test execution.
Follow `<plugin-root>/skills/kiss-unity-mcp-run-parsetests/SKILL.md` to inspect
saved log/XML pairs. It overwrites extracted diagnostics but does not rerun tests.

## Evidence and reporting

Full logs default to `<project>/Logs/kissunitymcp`. `CI_OUTPUT_DIR` is an
environment override, not a tools.env key. Keep the same output directory between
import and build so they share the import snapshot. Per-operation log overrides,
`UNITY_TEST_PLATFORM`, and `FAIL_ON_SKIPPED` also belong in the environment.

Capture the wrapper's actual exit status immediately; do not hide it with a later
command or an unchecked pipe. Exit `0` means verified success, `1` means tool /
compile / infrastructure failure, and `2` means failed or inconclusive tests
(including skipped-test policy rejection). Full logs, fresh nonempty artifacts,
expected markers, diagnostics, and process status must agree. Parsing old results
alone never proves a new run succeeded.

On failure, read the full named logs and extracted diagnostics, not just console
tails. Use the existing classifier; a filename containing Error is not itself a
failure. Record the exact command, project, resolved tools, exit status, evidence
paths, and scope of what passed. Keep logs/XML/snapshots out of source control.
