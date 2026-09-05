---
name: kiss-unity-mcp-shaders
description: Use kiss-unity-mcp to reimport project shaders and verify Unity shader diagnostics headlessly. Use after shader changes or to investigate shader/import errors; this does not prove every player-build platform and keyword variant compiles.
---

# Compile and check imported shaders

Read `<plugin-root>/skills/manual-workflow.md` first; use absolute `PROJECT_PATH`
and `TOOL_ROOT` from that guide.

Task: kiss-unity-mcp: Compile shaders

## Procedure

1. Use an already set-up project and its embedded editor package. Do not rerun
   setup automatically or add project-specific build targets to the package.
2. Read the exact m_EditorVersion and require the wrapper's versioned Hub editor
   gate. Save and close interactive Unity before the headless run.
3. Invoke the wrapper, which calls
   `SimpleUnityMCP.Editor.ShaderCompileTool.CompileAllProjectShaders`. The method
   owns shutdown; do not append `-quit` or use an ad-hoc Unity command.
4. Inspect Unity's entire log, not just shader-named lines; importer or compiler
   failures can invalidate an otherwise successful shader marker.

## Manual usage

```bash
bash "$TOOL_ROOT/scripts/unity.sh" shaders "$PROJECT_PATH"
```

VS Code: **kiss-unity-mcp: Compile shaders**. MCP server `kiss-unity-mcp`: `unity_shaders` with absolute
`project_path`.

## Verification

Require exit `0`, Unity process exit `0`, a fresh nonempty
`<project>/Logs/SimpleUnityMcp/UnityShaders.log`, its
`SIMPLE_UNITY_MCP_CI:SHADER_COMPILATION_PASSED` marker, and clean
`<project>/Logs/SimpleUnityMcp/ShaderCompileErrors.txt`. Exit `1` includes process,
marker, shader/import/compiler, or infrastructure failure. Keep both full log and
diagnostics and report actual errors, not every filename containing Error.

Environment overrides: `CI_OUTPUT_DIR`, `UNITY_SHADER_LOG_PATH`, and
`UNITY_SHADER_DIAGNOSTICS_PATH`. These are not tools.env settings. This checks
imported shaders and Unity-reported errors, not every platform/keyword combination
in a player build. Shader changes also invalidate the fast-build input snapshot;
run import before a subsequent fast MSBuild if inputs changed.