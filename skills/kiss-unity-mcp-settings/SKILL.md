---
name: kiss-unity-mcp-settings
description: Open or edit a Unity project's kiss-unity-mcp tool settings (Unity Hub root, editor, Rider/MSBuild, solution) in .kissunitymcp/tools.env. Use when the user wants to point the tools at a custom installation; nothing is launched.
---

# Edit tool settings

Read `<plugin-root>/skills/manual-workflow.md` first. Only the selected
project's existing `tools.env` is edited.

Task: kiss-unity-mcp: Open tool settings

## Manual usage

```bash
code --reuse-window "$PROJECT_PATH/.kissunitymcp/tools.env"
```

VS Code: **kiss-unity-mcp: Open tool settings**. If the file is missing, the
project is not set up; report that instead of creating the file.

## Procedure

1. Change only the key the user asked for. Keys: `UNITY_HUB_EDITOR_ROOT`,
   `UNITY_EDITOR_PATH`, `RIDER_ROOT`, `RIDER_MSBUILD`, `MSBUILD_RUNTIME`,
   `UNITY_SOLUTION_PATH`. Format `KEY=value` or `KEY="value"`, absolute paths.
2. The editor must be the exact version from
   `<project>/ProjectSettings/ProjectVersion.txt`; never change that file or
   pick a different version.
3. The file is data: no shell commands or variable expansion. Do not add
   log, filter, or platform settings; those are tool arguments.

## Verification

Run the `kiss-unity-mcp-doctor` skill afterwards; `TOOL_PATHS_VERIFIED`
proves the paths resolve. Editing the file alone proves nothing.
