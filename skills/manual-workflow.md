# Shared agent contract

kiss-unity-mcp verifies a Unity project headlessly: authoritative import and
compile, fast MSBuild, tests, and shaders. No open Unity editor is needed. Read
this once, then follow the skill. Human-facing details (VS Code tasks, CI, SSH,
custom tool paths) live in `<plugin-root>/Readme.md`, not here.

## Always

- Call the `kiss-unity-mcp` MCP tool the skill names, with an absolute
  `project_path`. Without MCP, run the single Bash command under the skill's
  **Manual usage**. Nothing else is needed to run the operation.
- Read the result top-down. Line 1 is the verdict, `<tool>: exit N (...)`. The
  end holds the summary, every failure's message and stack, and the extracted
  diagnostics. That is the complete evidence; report it to the user as is.
- Exit `0` verified success. Exit `1` tool, compile, import, or infrastructure
  failure. Exit `2` failed or inconclusive tests.
- Close the interactive Unity editor for that project before import, tests, or
  shaders. The tools remove a stale lock from an aborted run themselves; a
  `held by a running editor` error means ask the user to close Unity.

## Never

- Never launch Unity, MSBuild, or the `CI/bash` wrappers yourself, and never
  write a new script, VS Code task, or Unity command line. The tools already
  do this correctly, with the exact editor version and full evidence capture.
- Never open a full Unity log or NUnit XML under `<project>/Logs/kissunitymcp/`.
  They are tens of thousands of lines; the result already contains the
  extracted errors. Only give the user the path if they ask for it.
- Never run setup as a preamble. Missing tooling means: tell the user setup is
  required and stop.
- Never kill an editor, delete `Temp/UnityLockfile` or
  `Logs/kissunitymcp/run.lock`, edit `ProjectVersion.txt`, or use a
  different Unity version than the project declares.
- Never run two operations on the same project at the same time.

## Paths and configuration

`<plugin-root>` is two directories above a skill's `SKILL.md`. `<project>` is
the consumer Unity project, never the plugin repository. The installed
`<project>/.kissunitymcp/` holds the same Bash commands as the checkout:

```bash
PLUGIN_ROOT="/absolute/path/to/kiss-unity-mcp"
PROJECT_PATH="/absolute/path/to/Unity project"
TOOL_ROOT="$PROJECT_PATH/.kissunitymcp"
```

Tool selection is the data file `<project>/.kissunitymcp/tools.env` with the
keys `UNITY_HUB_EDITOR_ROOT`, `UNITY_EDITOR_PATH`, `RIDER_ROOT`, `RIDER_MSBUILD`,
`MSBUILD_RUNTIME`, `UNITY_SOLUTION_PATH` (`KEY=value`, absolute paths, never
sourced). Unity's version always comes from `ProjectSettings/ProjectVersion.txt`.

## Choosing the operation

| Change or need | Tool |
| --- | --- |
| Added or removed files, assets, asmdefs, packages, shaders, settings | `unity_import` (slow, authoritative) |
| Edited existing `.cs` contents only | `unity_build` (seconds); a stale-snapshot error means `unity_import` |
| Run tests | `unity_tests` with `test_filter` for one fixture or test; whole suite only when asked |
| Edited shaders | `unity_shaders` |
| Missing editor or MSBuild path error | `unity_doctor`, then have the user fix `tools.env` |
| Not installed | Report that explicit setup is required (`kiss-unity-mcp-setup`) |
