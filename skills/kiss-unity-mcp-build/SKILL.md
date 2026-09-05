---
name: kiss-unity-mcp-build
description: Use kiss-unity-mcp to run fast incremental Rider/MSBuild C# verification after a successful Unity import. Use only for edits to existing C# contents with a current import snapshot; route asset or project membership changes back to Unity import.
---

# Fast Rider/MSBuild follow-up

Read `<plugin-root>/skills/manual-workflow.md` first; use absolute `PROJECT_PATH`
and `TOOL_ROOT`. This checks generated C# projects, not player builds or Unity
asset/import semantics.

Task: kiss-unity-mcp: Fast MSBuild

## Procedure

1. Require a successful Unity import and a matching ImportSnapshot.txt. Only
   existing `.cs` contents may change. Added/removed files or changed assets,
   asmdefs, packages, settings, or generated projects require another import.
2. Also choose import for changed compilation directives, importers, or editor
   initialization. The fingerprint cannot detect those C# semantic changes.
3. Read the exact project editor version. Even MSBuild must pass the wrapper's
   exact Unity Hub/executable gate; no Unity-from-PATH or version substitution.
4. Resolve the actual solution and compatible Rider toolchain using tools.env.
   DLLs need `MSBUILD_RUNTIME`; non-Windows EXEs need a compatible Mono host.
   Do not download runtimes or manufacture/edit an import snapshot.

## Manual usage

```bash
bash "$TOOL_ROOT/scripts/unity.sh" build "$PROJECT_PATH"
```

VS Code: **kiss-unity-mcp: Fast MSBuild**. MCP server `kiss-unity-mcp`: `unity_build` with absolute
`project_path`. The wrapper uses incremental `/t:Build`, Debug / Any CPU, and a full
diagnostic file logger; arbitrary MSBuild switches are not a supported CLI surface.

## Verification

Require exit `0`, both MSBuild and console-capture status `0`, fresh nonempty
`<project>/Logs/SimpleUnityMcp/RiderMsBuild.log`, its `Build succeeded.` summary,
empty `<project>/Logs/SimpleUnityMcp/MsBuildErrors.txt`, and console marker
`SIMPLE_UNITY_MCP_CI:MSBUILD_PASSED`. Console navigation is retained separately in
`<project>/Logs/SimpleUnityMcp/RiderMsBuild.console.log`.

Exit `1` is a configuration, stale-input, compile, logging, or infrastructure
failure. Read the full diagnostic log; a quiet console or a process exit alone is
not proof. A missing/mismatched snapshot calls for import, not a bypass. Use the
same `CI_OUTPUT_DIR` environment override as import. Successful MSBuild does not
prove editor initialization, asset imports, tests, shaders, or a player build.