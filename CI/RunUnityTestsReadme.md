# Unity CI / manual Bash API

The complete installation, tool selection, commands, and log contract are in
[the repository manual](../Readme.md). `CI/bash` is the authoritative implementation;
legacy `bash/` entry points only forward here.

The [end-user skill catalog](../skills/README.md) covers the VS Code task actions
plus explicit one-time setup, with manual usage and verification evidence. The
[shared workflow](../skills/manual-workflow.md) explains absolute paths, VS Code
tasks, and custom tool selection without an agent or MCP server.

From the plugin checkout:

```bash
bash scripts/unity.sh doctor /path/to/project
bash scripts/unity.sh import /path/to/project
bash scripts/unity.sh build /path/to/project
bash scripts/unity.sh tests /path/to/project
bash scripts/unity.sh shaders /path/to/project
bash scripts/unity.sh parse-tests /path/to/project
```

Direct CI entry points remain available with `UNITY_PROJECT_PATH` set. Full logs
and results default to `<project>/Logs/SimpleUnityMcp`; `CI_OUTPUT_DIR` overrides
that location. `UNITY_TEST_PLATFORM` defaults to EditMode. Keep generated logs,
XML, snapshots and diagnostics out of source control.

**kiss-unity-mcp: Parse test results** and the
[run-parsetests skill](../skills/kiss-unity-mcp-run-parsetests/SKILL.md) both use
the dispatcher's `parse-tests` action. This inspects existing CITestOutput.xml and
UnityTests.log and overwrites extracted diagnostics; it never launches Unity or
MSBuild. Pass `--test-results` and `--unity-log` after the project argument for an
archived pair. Keep `UNITY_DIAGNOSTICS_PATH` distinct from both inputs. Exit `0`
validates the supplied artifacts only, `1` means invalid/missing evidence or
infrastructure failure, and `2` means failed/inconclusive tests or rejected skips.
The original run's process status and freshness must be verified separately.

Tool paths are selected in `<project>/.unity-simple-mcp/tools.env`, with environment
overrides taking precedence. No path is hard-coded to a particular editor version,
Rider version, or solution name. The exact Unity version gate also applies to
MSBuild, but not parse-only. Headless Unity refuses an interactive editor lock;
execution wrappers use a per-project run lock. Parse-only does not lock, so wait
until writers finish before inspecting artifacts. Check processes before removing
a stale lock.

A successful MSBuild process is a C# check only. Use Unity import to validate
asset import, script initialization, compilation symbols and generated project
membership. Both full file logs and process statuses are required for success.
