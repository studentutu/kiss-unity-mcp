---
name: kiss-unity-mcp-shaders
description: Reimport all project shaders headlessly and report Unity shader compiler errors through kiss-unity-mcp. Use after editing .shader, .hlsl, .cginc, or Shader Graph files; close the Unity editor first.
---

# Compile and check shaders

Read `<plugin-root>/skills/manual-workflow.md` first. This checks the shaders
Unity imports for the editor platform, not every player platform and keyword
variant.

Task: kiss-unity-mcp: Compile shaders

## Procedure

1. Make sure the interactive Unity editor for this project is closed.
2. Call MCP server `kiss-unity-mcp` tool `unity_shaders` with absolute
   `project_path`.
3. Report the verdict line and each `Shader error in '...'` line (shader name,
   message, line) from the result. Fix and call again.

## Manual usage

```bash
bash "$TOOL_ROOT/scripts/unity.sh" shaders "$PROJECT_PATH"
```

VS Code: **kiss-unity-mcp: Compile shaders**.

## Verification

Exit `0` prints `Unity shader compilation passed.` Exit `1` lists the shader,
import, or compiler diagnostics that were found, or reports a missing success
marker (package not installed in the project). Do not open `UnityShaders.log`.
Shader changes also invalidate the fast-build snapshot; the next C# check
needs `unity_import` before `unity_build`.
