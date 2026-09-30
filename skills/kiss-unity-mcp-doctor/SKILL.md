---
name: kiss-unity-mcp-doctor
description: Resolve the exact Unity editor and Rider/MSBuild paths for a Unity project with kiss-unity-mcp, without launching them. Use when another kiss-unity-mcp tool reports a missing editor version or an ambiguous MSBuild, before asking the user to edit tools.env.
---

# Check tool paths

Read `<plugin-root>/skills/manual-workflow.md` first. Nothing is launched,
compiled, or installed.

Task: kiss-unity-mcp: Check tool paths

## Manual usage

```bash
bash "$TOOL_ROOT/scripts/unity.sh" doctor "$PROJECT_PATH"
```

VS Code: **kiss-unity-mcp: Check tool paths**.

## Procedure

1. Call MCP server `kiss-unity-mcp` tool `unity_doctor` with absolute
   `project_path`.
2. Read the required Unity version, the installed editors list, and the
   resolved MSBuild from the result.
3. If the exact editor version is missing, tell the user to install that
   version in Unity Hub or set `UNITY_HUB_EDITOR_ROOT` in
   `<project>/.kissunitymcp/tools.env`. Never pick a different version.
4. If MSBuild has zero or several candidates, tell the user to set
   `RIDER_ROOT` or `RIDER_MSBUILD` (plus `MSBUILD_RUNTIME` for a `.dll`) in
   `tools.env`, copied from Rider's **Toolset and Build** settings. Never
   download a toolchain.

## Verification

Exit `0` prints `TOOL_PATHS_VERIFIED` with both resolved paths. Exit `1`
names the missing or ambiguous tool and the settings file. Doctor proves paths
only; use the import, build, tests, or shaders skill to prove the code.
