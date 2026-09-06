# Agent workflow

This repository is a shared Codex and Claude Code plugin and the source of the
embedded Unity package `com.studentutu.kissunitymcp`. Keep harness metadata, the
shared plugin implementation, and the Unity package boundary separate.

## Non-negotiable setup contract

- Project setup is explicit and runs once per Unity project. Never run it as a
  routine preamble to Unity work.
- Inspect first with `inspect_unity_project` on MCP server `kiss-unity-mcp` or
  `bash scripts/setup-unity-project.sh <project> --dry-run`.
- Setup writes the selected project's `Packages/com.studentutu.kissunitymcp`,
  `.kissunitymcp/` (Bash tools and `tools.env`),
  `ProjectSettings/kissunitymcp.json`, and the dedicated VS Code workspace.
  Create `.vscode/tasks.json` only when absent; preserve existing tasks and tool settings.
  Temporary setup locks/staging and replacement backups remain within the project.
- An identical package is a no-op. A conflicting destination is a hard stop.
  Use `--replace` only after the user explicitly requests replacement.
- Setup is filesystem-only. It must not open Unity, edit `Packages/manifest.json`,
  mutate unrelated project settings. Install the authoritative `CI/bash` into
  `.kissunitymcp/CI/bash` so manual use survives marketplace cache removal.

The package source is `com.studentutu.kissunitymcp/`. Do not create a second
copy inside the plugin repository. The setup implementation stages and hashes a
copy before swapping it into the consumer project's `Packages/` directory.

## Repository entry points

- Plugin metadata: `.codex-plugin/plugin.json`, `.claude-plugin/plugin.json`
- Marketplace catalogs: `.agents/plugins/marketplace.json`, `.claude-plugin/marketplace.json`
- Bundled MCP configurations: `.mcp.codex.json`, `.mcp.claude.json` (explicit manifest paths;
  no root `.mcp.json`, which both harnesses would auto-discover)
- Both harnesses use the root `skills/`, `scripts/`, `CI/bash/`, and Unity package.
  Never create harness-specific copies of that implementation.
- Plugin/MCP server namespace: `kiss-unity-mcp`; skills: `kiss-unity-mcp-*`.
  Keep installed filesystem paths and the Unity package identity stable.
- MCP server: `scripts/mcp-server.sh` (thin stdio adapter)
- Setup CLI: `scripts/setup-unity-project.sh`
- Manual API: `scripts/unity.sh <doctor|unity-import-long-compile|build|tests|shaders|parse-tests> <project>`
- Plugin validation: `scripts/validate-plugin.sh`
- Workflow regression tests: `scripts/test-workflow.sh`
- End-user task skills and manual workflow: `skills/README.md`, `skills/manual-workflow.md`
- Skill scope: actions exposed by `templates/tasks.json`, plus explicit one-time setup
  in `skills/kiss-unity-mcp-setup/SKILL.md`; no maintenance or compatibility skills.
- Unity package: `com.studentutu.kissunitymcp/`
- Unity CI: `CI/bash/`

Use `rg` for search. Keep changes surgical. Runtime tooling uses Bash 3.2+,
Git and standard Unix utilities bundled with Git Bash / macOS / Linux.
No Node, Python, jq, GNU-awk-only features, downloaded runtimes or packages.
Do not duplicate the authoritative `CI/bash` implementation under `scripts/`.

## Marketplace release contract

- The repository is the `studentutu` marketplace and the Git-backed
  `kiss-unity-mcp` plugin source.
- Keep the plugin at the repository root. The marketplace entry uses the remote
  repository URL with `source: "url"`; do not create a duplicate plugin copy
  under `plugins/`.
- `master` is the published source ref. Feature branches are not releases.
- Keep `.codex-plugin/plugin.json`, `.claude-plugin/plugin.json`, and
  `com.studentutu.kissunitymcp/package.json` versions identical.
- Run `bash scripts/validate-plugin.sh` before publishing. Merge and push the
  verified commit before asking users to upgrade the marketplace.
- Do not mutate a developer's Codex or Claude Code marketplace configuration as part of normal
  repository validation. Installation is an explicit user action.

## Prerequisite: resolve the exact Unity editor

This gate is mandatory before every Unity-backed tool call. It is not needed for
filesystem-only inspect/setup or parsing existing test artifacts without Unity.

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
| Plugin and skill structure | `bash scripts/validate-plugin.sh` | Validator exit `0` |
| Setup behavior and portable contracts | `bash scripts/test-workflow.sh` | Regression suite exit `0` |
| Real failure/restoration checks | `bash scripts/verify-unity-workflow.sh <disposable-project>` | Per-step full logs, process exits, `UNITY_WORKFLOW_VERIFIED` |
| Setup behavior | `bash scripts/setup-unity-project.sh <temp-project>` | JSON action/state plus copied digest |
| Long Unity compile/import | `bash ./CI/bash/rebuildSolutionFromUnityItself.sh` | `Logs/kissunitymcp/UnityCompile.log`, diagnostics, `PROJECT_FILES_SYNCED` |
| Quick C# follow-up | `bash ./CI/bash/rebuildSolutionWithRiderMsBuild.sh` | `Logs/kissunitymcp/RiderMsBuild.log`, diagnostics |
| EditMode tests | `bash ./CI/bash/runTestsBash.sh` | `Logs/kissunitymcp/UnityTests.log`, fresh NUnit XML |
| Test parse only | `bash ./CI/bash/parseTestErrors.sh` | Parsed existing log/XML; no new Unity run |
| Shader compile | `bash ./CI/bash/compileShaders.sh` | `Logs/kissunitymcp/UnityShaders.log`, diagnostics, pass marker |

Logs and diagnostics live in `<project>/Logs/kissunitymcp/` by default.
All tool selections live in `<project>/.kissunitymcp/tools.env`; explicit
environment overrides take precedence. This file is parsed as data, never sourced.

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
   `com.studentutu.kissunitymcp/Editor` with a stable fully qualified method.
2. Emit one stable pass/fail marker and preserve real process exit codes. Persist
   reload-spanning state with `SessionState`.
3. Add or extend one wrapper under `CI/bash`; do not invoke Unity with ad-hoc
   command lines.
4. If the capability belongs on the plugin surface, expose one narrowly scoped
   MCP tool. Add a skill only for an end-user action in `templates/tasks.json`;
   explicit one-time setup is the sole exception. Update its skill and manual
   setup instructions only when their decisions change.
5. Red/green test intentional failure and restored success. Stale artifacts may
   never satisfy verification.

Avoid speculative abstraction. Keep project-specific build scenes, targets, and
outputs outside this reusable package.
