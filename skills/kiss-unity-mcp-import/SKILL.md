---
name: kiss-unity-mcp-import
description: Authoritative headless Unity import, full C# compile, and solution regeneration through kiss-unity-mcp. Use after adding or removing scripts, assets, asmdefs, packages, shaders, or settings, and before the first fast build. Slow (minutes); close the Unity editor first.
---

# Import and compile with Unity

Read `<plugin-root>/skills/manual-workflow.md` first. This is the authoritative
check; it also refreshes the snapshot that enables the fast build skill.

Task: kiss-unity-mcp: unity-import-long-compile

## Procedure

1. Make sure the interactive Unity editor for this project is closed. If the
   tool reports a lock, ask the user to close Unity; never remove the lock.
2. Call MCP server `kiss-unity-mcp` tool `unity_import` with absolute
   `project_path`. Expect several minutes on large projects.
3. Report the verdict line and the extracted diagnostics (compiler errors,
   import failures, exceptions) from the result. Fix and call again.

## Manual usage

```bash
bash "$TOOL_ROOT/scripts/unity.sh" unity-import-long-compile "$PROJECT_PATH"
```

VS Code: **kiss-unity-mcp: unity-import-long-compile**.

## Verification

Exit `0` prints `Unity compilation and IDE project generation passed.` Exit
`1` means a compile or import error, a missing editor, a missing success marker
(package not installed in the project), or an ambiguous solution (`Expected one
.sln`; the user sets `UNITY_SOLUTION_PATH` in `tools.env`). The failing lines
with file and line numbers are already in the result; do not open
`UnityCompile.log`, and do not add `-quit` or other flags by running Unity
yourself.
