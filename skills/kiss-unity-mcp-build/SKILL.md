---
name: kiss-unity-mcp-build
description: Fast incremental C# compile of a Unity project with Rider's MSBuild through kiss-unity-mcp, without launching Unity. Use after editing existing .cs files when a successful unity_import snapshot exists; a stale-snapshot error means run the import skill instead.
---

# Fast MSBuild follow-up

Read `<plugin-root>/skills/manual-workflow.md` first. This compiles the
generated C# solution in seconds. It is not a player build and does not
validate assets, imports, or editor initialization.

Task: kiss-unity-mcp: Fast MSBuild

## Procedure

1. Use it only for edits to existing `.cs` contents. Added or removed files,
   asmdef, package, asset, shader, or settings changes need `unity_import`.
2. Call MCP server `kiss-unity-mcp` tool `unity_build` with absolute
   `project_path`.
3. Report the verdict line and the listed compiler errors (`error CSxxxx`
   with file and line). Fix the code and call the tool again.

## Manual usage

```bash
bash "$TOOL_ROOT/scripts/unity.sh" build "$PROJECT_PATH"
```

VS Code: **kiss-unity-mcp: Fast MSBuild**.

## Verification

Exit `0` prints `SIMPLE_UNITY_MCP_CI:MSBUILD_PASSED`. Exit `1` with
`Unity inputs or generated projects changed` or `No verified Unity import
snapshot` means call `unity_import`, never bypass the snapshot. Exit `1` with
`Set RIDER_ROOT or RIDER_MSBUILD` means call `unity_doctor` and have the user
fix `<project>/.kissunitymcp/tools.env`. Other exit `1` output lists the
compiler errors; do not open `RiderMsBuild.log`.
