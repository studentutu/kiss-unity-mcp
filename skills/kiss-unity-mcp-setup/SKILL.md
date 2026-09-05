---
name: kiss-unity-mcp-setup
description: Inspect or explicitly set up kiss-unity-mcp once in a selected Unity project. Install the embedded package, standalone Bash tools, tool settings, and VS Code tasks while preserving existing developer configuration.
---

# Inspect and set up a Unity project

Read `<plugin-root>/skills/manual-workflow.md` first; resolve `PLUGIN_ROOT` and
`PROJECT_PATH` to absolute paths. Setup is the sole skill outside the VS Code task
template. It is filesystem-only: no installed Unity editor or Rider is required.

## Procedure

1. Confirm the selected project already has Assets, Packages, and
   `<project>/ProjectSettings/ProjectVersion.txt`, with Unity 2023.1 or newer.
2. Inspect first with the dry-run command below, or MCP server `kiss-unity-mcp` tool `inspect_unity_project`
   with absolute `project_path`. Inspection never authorizes installation.
3. Read the JSON state: `installed` needs no routine setup; `not_installed` permits
   installation only when requested; `conflict` requires review and a hard stop.
4. For an explicit installation request, run setup once or call MCP server `kiss-unity-mcp` tool
   `setup_unity_project` with `project_path`. Inspect again afterward.
5. Hand off to the settings and doctor skills for subsequent tool selection and
   checks. Never repeat setup as a preamble to import, build, tests, or shaders.

## Manual usage

Inspect from the plugin checkout/installation, not the installed consumer tools:

```bash
bash "$PLUGIN_ROOT/scripts/setup-unity-project.sh" "$PROJECT_PATH" --dry-run
```

Only for an explicitly requested installation:

```bash
bash "$PLUGIN_ROOT/scripts/setup-unity-project.sh" "$PROJECT_PATH"
```

Use CLI `--replace` only after the user explicitly requests replacement of reviewed
conflicts. MCP does not expose replacement. Existing tools.env values are preserved;
previous installations are retained under
`<project>/Packages/.kissunitymcp-setup-<pid>` for recovery. A customized
dedicated workspace remains a conflict even with `--replace`; do not overwrite it.

## Verification

Require exit `0`, JSON action `installed` or `already_installed`, then inspection
state `installed`. Inspection may exit `0` with state `conflict`, so read the JSON,
not just the exit status. Retain the reported version and source/tools digests.
Exit `1` means setup failed; report the error and recovery paths without deleting
user data or locks automatically.

Legacy installation paths are a conflict even with `--replace`. Follow the
existing-installation migration in `<plugin-root>/Readme.md`; never install the
renamed package alongside the old package.

Check the package at `<project>/Packages/com.studentutu.kissunitymcp`, standalone
tools at `<project>/.kissunitymcp`, setup marker at
`<project>/ProjectSettings/kissunitymcp.json`, and dedicated workspace at
`<project>/.vscode/kissunitymcp.code-workspace`. Existing tasks.json and tool
settings must remain intact; tasks.json is created only when absent. Setup never
opens Unity, edits the package manifest, or installs project dependencies.

Point the developer to `<project>/.kissunitymcp/tools.env` and the dedicated
workspace for manual use. Do not automatically launch Unity-backed verification
as part of setup; it requires the separate exact editor gate.
