---
name: unity-simple-mcp-setup
description: Install Unity Simple MCP once, inspect its state, or use its Bash commands for Unity import, fast Rider/MSBuild compilation, tests and shader checks. Use setup only when explicitly requested.
---

# Unity Simple MCP

Resolve the plugin root two directories above this skill. Commands require Bash
3.2+, Git and standard Unix utilities; no Node, Python or package manager.

## Explicit one-time setup

1. Resolve the selected Unity project (Assets, Packages, ProjectSettings/ProjectVersion.txt).
2. Call `inspect_unity_project` or run `bash <plugin-root>/scripts/setup-unity-project.sh <project> --dry-run`.
3. `installed`: setup is already complete. `not_installed`: run setup only when requested.
   `conflict`: report exact paths; do not replace user changes automatically.
4. Call `setup_unity_project` or run `bash <plugin-root>/scripts/setup-unity-project.sh <project>`.
5. Inspect once more and require `installed`. Point the user to
   `<project>/.unity-simple-mcp/tools.env` and
   `<project>/.vscode/unity-simple-mcp.code-workspace` for manual control.

Setup copies the embedded Unity package and standalone Bash tooling. It creates
VS Code tasks only when absent and always provides a dedicated workspace.
It preserves existing tasks and tool settings; it never starts Unity or edits
Packages/manifest.json. Only use CLI `--replace` for an intentional authorized
replacement. Previous installations are retained for recovery.

## After setup

Never repeat setup as a routine preamble. Use MCP tools `unity_doctor`,
`unity_import`, `unity_build`, `unity_tests`, and `unity_shaders`, or the same
manual API:

```bash
bash <project>/.unity-simple-mcp/scripts/unity.sh doctor <project>
bash <project>/.unity-simple-mcp/scripts/unity.sh import <project>
bash <project>/.unity-simple-mcp/scripts/unity.sh build <project>
bash <project>/.unity-simple-mcp/scripts/unity.sh tests <project>
bash <project>/.unity-simple-mcp/scripts/unity.sh shaders <project>
```

Every Unity-backed command resolves the exact editor from ProjectVersion.txt,
lists installed editors, and fails with configuration paths if tools are missing.
Close interactive Unity for that project before a headless process; do not kill
an editor with potentially unsaved work. Tool settings are parsed data, not shell
code. Use Git Bash for Windows editors, not WSL.

Run import first. Fast MSBuild only validates existing C# projects and requires a
matching import snapshot. Added/removed files, assets, asmdefs, packages, settings,
compilation directives, or importer/editor behavior changes require another
Unity import. Tests require the consumer's existing Unity Test Framework; setup
never installs it. Shader import checks do not cover every player build variant.

Read `<project>/Logs/SimpleUnityMcp/` on failure. Complete Unity editor logs and
MSBuild diagnostic file logs are authoritative; summaries are only navigation.
Require zero process status, fresh nonempty logs, completion evidence and clean
diagnostics. Tests additionally require structurally valid, consistent NUnit XML,
at least one discovered test, and a passing root test-run. Exit `1` means tool /
compile / infrastructure failure; `2` means failed or inconclusive tests.
