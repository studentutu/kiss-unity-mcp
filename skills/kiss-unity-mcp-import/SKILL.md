---
name: kiss-unity-mcp-import
description: Use kiss-unity-mcp to run authoritative headless Unity import and C# compilation, regenerate IDE solution files, and refresh the fast-build snapshot. Use after setup or changes to files, assets, asmdefs, packages, settings, or Unity editor behavior.
---

# Import and generate the solution

Read `<plugin-root>/skills/manual-workflow.md` first; resolve `PROJECT_PATH` and
`TOOL_ROOT`. This is authoritative Unity verification, not the fast C# check.

Task: kiss-unity-mcp: Import and generate solution (long-compile)

## Procedure

1. Use the already installed package/tools; never run setup automatically.
   Solution generation needs the project's existing IDE integration.
2. Read the exact project editor version and require the wrapper's Hub listing
   and exact executable gate. Save and close interactive Unity for this project.
3. Run import for added/removed scripts, assets, asmdefs, shaders, packages,
   settings, or generated project changes. Also use it for C# edits affecting
   importers, compilation directives, or editor initialization.
4. Let the stable editor method own shutdown and reload-spanning state. Do not
   add `-quit`, bypass errors, or replace the wrapper with an ad-hoc Unity command.

## Manual usage

```bash
bash "$TOOL_ROOT/scripts/unity.sh" import "$PROJECT_PATH"
```

VS Code: **kiss-unity-mcp: Import and generate solution (long-compile)**.
MCP server `kiss-unity-mcp`: `unity_import` with absolute `project_path`.

## Verification

Require wrapper exit `0`, Unity process exit `0`, a fresh nonempty
`<project>/Logs/kissunitymcp/UnityCompile.log`, and
`SIMPLE_UNITY_MCP_CI:PROJECT_FILES_SYNCED` in that log. Require clean
`<project>/Logs/kissunitymcp/CompileErrorsAfterUnityRun.txt`, a nonempty generated
solution, and a newly written `<project>/Logs/kissunitymcp/ImportSnapshot.txt`.
The method is `SimpleUnityMCP.Editor.CiTools.RegenerateProjectFilesAndExit`.

Exit `1` includes missing markers/solutions, bad tool paths, import/compiler
diagnostics, or process failure even if another signal looks successful. Read the
full log and extracted diagnostics. If solution selection is ambiguous, explicitly
set `UNITY_SOLUTION_PATH` in tools.env; do not guess a solution.

Environment overrides: `CI_OUTPUT_DIR`, `UNITY_COMPILE_LOG_PATH`, and
`UNITY_DIAGNOSTICS_PATH`. The snapshot remains under CI_OUTPUT_DIR. Import clears
the old snapshot before launching Unity; a failed import must never enable a fast
build using stale evidence. Keep the same CI_OUTPUT_DIR for the follow-up build.