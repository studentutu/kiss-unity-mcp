---
name: unity-simple-mcp-setup
description: Inspect or perform the one-time installation of the bundled com.studentutu.unitysimplemcp package in a local Unity project. Use for setup, installation, repair, or verification requests; do not use for ordinary Unity work after setup.
---

# Unity Simple MCP setup

Treat setup as a one-time project mutation, not a prerequisite to repeat on every Unity task.

1. Resolve the intended Unity project root. It must contain `Assets/`, `Packages/`, and `ProjectSettings/ProjectVersion.txt`.
2. Call `inspect_unity_project` before any write.
3. Branch on the returned state:
   - `installed`: report that setup is already complete. Do not call setup again.
   - `not_installed`: call `setup_unity_project` only when the user asked to set up or install the package.
   - `conflict`: stop and report the existing package path. Do not replace it without an explicit replacement request.
4. After a changed setup, inspect once more and require the `installed` state.

Inspection and setup only touch the filesystem; they do not launch Unity. Do not resolve or start a Unity editor for this workflow. For later Unity-backed compile, test, or shader work, follow the target repository's `AGENTS.md` and require its exact `m_EditorVersion` before launching Unity.

If the MCP tools are unavailable, resolve the plugin root from this skill and run:

```text
node <plugin-root>/scripts/setup-unity-project.mjs <unity-project-path>
```

The script is idempotent for a matching package. A differing embedded package is a hard failure. Only after the user explicitly requests replacement may you use:

```text
node <plugin-root>/scripts/setup-unity-project.mjs <unity-project-path> --replace
```
