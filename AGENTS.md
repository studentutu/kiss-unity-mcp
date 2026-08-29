# Agent workflow

This repository is both a Codex plugin and the source of the embedded Unity
package `com.studentutu.unitysimplemcp`. Keep the plugin boundary and the Unity
package boundary separate.

## Non-negotiable setup contract

- Project setup is explicit and runs once per Unity project. Never run it as a
  routine preamble to Unity work.
- Inspect first with `inspect_unity_project` or
  `node scripts/setup-unity-project.mjs <project> --dry-run`.
- Setup may write only the selected project's
  `Packages/com.studentutu.unitysimplemcp` and
  `ProjectSettings/SimpleUnityMcpSetup.json`.
- An identical package is a no-op. A conflicting destination is a hard stop.
  Use `--replace` only after the user explicitly requests replacement.
- Setup is filesystem-only. It must not open Unity, edit `Packages/manifest.json`,
  copy CI scripts into the consumer, or mutate unrelated project settings.

The package source is `com.studentutu.unitysimplemcp/`. Do not create a second
copy inside the plugin repository. The setup implementation stages and hashes a
copy before swapping it into the consumer project's `Packages/` directory.

## Repository entry points

- Plugin metadata: `.codex-plugin/plugin.json`
- Bundled MCP configuration: `.mcp.json`
- MCP server: `scripts/mcp-server.mjs`
- Setup CLI and implementation: `scripts/setup-unity-project.mjs` and
  `scripts/unity-project.mjs`
- Plugin validation: `scripts/validate-plugin.mjs`
- Setup skill: `skills/unity-simple-mcp-setup/SKILL.md`
- Unity package: `com.studentutu.unitysimplemcp/`
- Unity CI: `CI/bash/`

Use `rg` for search. Keep changes surgical. Do not add dependencies to the MCP
server without a demonstrated need; the current server intentionally uses only
Node built-ins. Do not duplicate the authoritative `CI/bash` scripts into
`scripts/`.

## Prerequisite: resolve the exact Unity editor

This gate is mandatory before every Unity-backed tool call. It is not needed for
the filesystem-only inspect/setup workflow.

Read the target project's `ProjectSettings/ProjectVersion.txt`, extract its
exact `m_EditorVersion`, and scan the platform's Unity Hub editor root:

| Platform | Unity Hub editor root | Executable below the version directory |
| --- | --- | --- |
| macOS | `/Applications/Unity/Hub/Editor` | `Unity.app/Contents/MacOS/Unity` |
| Windows (Git Bash) | `/c/Program Files/Unity/Hub/Editor` | `Editor/Unity.exe` |
| Linux | `~/Unity/Hub/Editor` | `Editor/Unity` |

List every installed editor. Require an exact directory match for the project's
version and export that executable as `UNITY_EDITOR_PATH`. Never assume `Unity`
is on `PATH` and never substitute the newest or closest installed editor. If the
exact version is absent, stop and report the required and installed versions.

Do not start Unity, MSBuild, tests, shader compilation, or another Unity-driven
tool until this gate passes. Close an interactive Unity instance for the same
project before launching a headless process.

## Verification API

Run repository commands only through these entry points:

| Intent | Command | Evidence |
| --- | --- | --- |
| Plugin and skill structure | `node scripts/validate-plugin.mjs` | Validator exit `0` |
| Setup behavior | `node scripts/setup-unity-project.mjs <temp-project>` | JSON action/state plus copied digest |
| Long Unity compile/import | `bash ./CI/bash/rebuildSolutionFromUnityItself.sh` | `CI/UnityCompile.log`, diagnostics, `PROJECT_FILES_SYNCED` |
| Quick C# follow-up | `bash ./CI/bash/rebuildSolutionWithRiderMsBuild.sh` | `CI/RiderMsBuild.log`, diagnostics |
| EditMode tests | `bash ./CI/bash/runTestsBash.sh` | `CI/UnityTests.log`, fresh NUnit XML |
| Test parse only | `bash ./CI/bash/parseTestErrors.sh` | Parsed current log/XML |
| Shader compile | `bash ./CI/bash/compileShaders.sh` | `CI/UnityShaders.log`, diagnostics, pass marker |

The quick MSBuild path is valid only when generated solution files are current
and no script, asmdef, package, shader, or asset was added or removed. Unity
commands succeed only when the process exit, fresh non-empty log, expected
marker/artifact, and extracted diagnostics all agree. Tests also require valid
NUnit XML, at least one discovered test, and a passing root `test-run`.

Exit codes are API: `0` verified success, `1` tool/compile/infrastructure
failure, and `2` failed or inconclusive tests. Read the named logs and diagnostic
artifacts on failure. Do not classify every line containing `Error` as fatal;
use the existing script classifier.

## Evolution rules

Add one thin vertical slice at a time:

1. Put reusable editor behavior under
   `com.studentutu.unitysimplemcp/Editor` with a stable fully qualified method.
2. Emit one stable pass/fail marker and preserve real process exit codes. Persist
   reload-spanning state with `SessionState`.
3. Add or extend one wrapper under `CI/bash`; do not invoke Unity with ad-hoc
   command lines.
4. If the capability belongs on the plugin surface, expose one narrowly scoped
   MCP tool and update the setup skill only when its decisions change.
5. Red/green test intentional failure and restored success. Stale artifacts may
   never satisfy verification.

Avoid speculative abstraction. Keep project-specific build scenes, targets, and
outputs outside this reusable package.
