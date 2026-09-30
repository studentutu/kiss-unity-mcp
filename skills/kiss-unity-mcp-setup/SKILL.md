---
name: kiss-unity-mcp-setup
description: Inspect whether kiss-unity-mcp is installed in a Unity project and, only when the user explicitly asks, install it once (embedded package, Bash tools, tools.env, VS Code tasks). Never a preamble to import, build, tests, or shaders.
---

# Inspect and set up a Unity project

Read `<plugin-root>/skills/manual-workflow.md` first. Setup is filesystem-only:
no Unity or Rider is launched and `Packages/manifest.json` is not edited. The
project must already contain `Assets`, `Packages`, and
`ProjectSettings/ProjectVersion.txt` with Unity 2023.1 or newer.

## Procedure

1. Inspect: call MCP server `kiss-unity-mcp` tool `inspect_unity_project` with
   absolute `project_path`, or run the dry-run command below.
2. Read the JSON `state`. `installed`: nothing to do. `not_installed`: install
   only if the user asked for setup. `conflict`: stop and show the user the
   reported paths; never replace automatically.
3. Install on explicit request: tool `setup_unity_project` with `project_path`,
   or the second command below. Inspect again and report `installed`.
4. Next steps for the user: close Unity, then use the tests, import, build, or
   shaders skill. Tool paths can be changed with the settings skill.

## Manual usage

```bash
bash "$PLUGIN_ROOT/scripts/setup-unity-project.sh" "$PROJECT_PATH" --dry-run
```

Only for an explicitly requested installation:

```bash
bash "$PLUGIN_ROOT/scripts/setup-unity-project.sh" "$PROJECT_PATH"
```

`--replace` exists only for a user-requested replacement of reviewed
conflicts and is not exposed through MCP. Legacy `unitysimplemcp` paths are a
conflict even with `--replace`; follow the migration in `<plugin-root>/Readme.md`.

## Verification

Exit `0` with JSON `action` `installed` or `already_installed`, then inspection
`state` `installed`. Inspection may exit `0` with `state` `conflict`, so read the
JSON, not only the exit code. Setup writes
`<project>/Packages/com.studentutu.kissunitymcp`, `<project>/.kissunitymcp/`,
`<project>/ProjectSettings/kissunitymcp.json`, and
`<project>/.vscode/kissunitymcp.code-workspace`; an existing `tasks.json` and
`tools.env` are preserved. Exit `1` means setup failed; report the error and
the recovery path it names without deleting anything.
