---
name: kiss-unity-mcp-doctor
description: Use kiss-unity-mcp to diagnose Unity Hub, exact editor version, and Rider/MSBuild tool paths without launching them. Use for manual tools.env configuration, missing tools, custom installations, or ambiguous Rider discovery.
---

# Check tool paths

Read `<plugin-root>/skills/manual-workflow.md` first; use its absolute
`PROJECT_PATH` and `TOOL_ROOT`. This checks paths, not compilation or licensing.

Task: kiss-unity-mcp: Check tool paths

## Manual usage

```bash
bash "$TOOL_ROOT/scripts/unity.sh" doctor "$PROJECT_PATH"
```

VS Code: **kiss-unity-mcp: Check tool paths**. MCP server `kiss-unity-mcp`: `unity_doctor` with absolute
`project_path`. No Unity or MSBuild process is launched.

## Procedure

1. Read the project's exact m_EditorVersion. Require the platform's exact
   versioned Hub executable; doctor lists installed versions and exports the
   resolved editor for its own process. No nearest-version fallback is allowed.
2. Resolve Rider/MSBuild. If there are zero or multiple candidates, have the
   developer select the actual tool in `<project>/.kissunitymcp/tools.env`
   with `RIDER_ROOT` or `RIDER_MSBUILD`.
3. For custom/Toolbox installs, use Rider's **Settings > Build, Execution,
   Deployment > Toolset and Build**. DLLs need a compatible executable
   `MSBUILD_RUNTIME`; non-Windows MSBuild.exe needs a compatible Mono host for
   actual builds. Use the existing toolchain, never download one automatically.
4. Repeat doctor after the deliberate configuration change. Environment overrides
   take precedence; do not source tools.env or add output/test settings to it.

## Verification

Require exit `0`, the required/installed editor listing, resolved configuration,
editor and MSBuild paths, and `TOOL_PATHS_VERIFIED`. Exit `1` means path or
configuration failure; report the exact missing/ambiguous candidates and settings
path. An explicit editor override does not bypass the Hub-root/version gate.

Doctor also requires Rider/MSBuild even if the next intended operation is only
Unity import. It does not select/validate a solution, compile code, test runtime
compatibility fully, verify a license, or establish an import snapshot. Use the
appropriate operation skill to prove those outcomes, not the doctor marker.