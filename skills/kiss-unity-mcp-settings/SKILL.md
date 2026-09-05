---
name: kiss-unity-mcp-settings
description: Use kiss-unity-mcp to open and edit the project's Unity and Rider/MSBuild tool settings. Use for custom installations, tool-path overrides, or selecting a solution without launching Unity or changing project setup.
---

# Open tool settings

Read `<plugin-root>/skills/manual-workflow.md` first; use its absolute
`PROJECT_PATH`. Edit only the selected project's existing settings.

Task: kiss-unity-mcp: Open tool settings

## Manual usage

Choose **Terminal > Run Task > kiss-unity-mcp: Open tool settings**, or run:

```bash
code --reuse-window "$PROJECT_PATH/.unity-simple-mcp/tools.env"
```

If the `code` CLI is unavailable, open the same file in VS Code's Explorer.
This operation requires neither Unity nor Rider to be installed and does not
launch them. If the settings file is missing, report the setup requirement;
do not install or replace tooling automatically.

## Procedure

1. Preserve existing values unless the user requests a change. Use absolute
   paths with `KEY=value` or `KEY="value"`; spaces are supported.
2. Select `UNITY_HUB_EDITOR_ROOT` and optionally `UNITY_EDITOR_PATH` for the exact
   version in `<project>/ProjectSettings/ProjectVersion.txt`. Never substitute a
   different editor version or change the project's version to match an install.
3. Select `RIDER_ROOT` or `RIDER_MSBUILD` for custom/ambiguous Rider installations.
   Set `MSBUILD_RUNTIME` when the selected tool needs a compatible host, and
   `UNITY_SOLUTION_PATH` when solution selection is ambiguous.
4. Save the file. It is parsed as data: no shell commands, variable expansion, or
   sourcing. Nonempty environment overrides take precedence. Log/test overrides
   belong in the environment, not this six-key settings file.

## Verification

Confirm the correct project's file opened and requested edits were saved without
changing unrelated settings. Opening the file does not prove the paths work.
Use **kiss-unity-mcp: Check tool paths** when path validation is wanted; it resolves the
exact editor and Rider without launching either. A real build/import remains a
separate operation.