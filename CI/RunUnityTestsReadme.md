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
bash scripts/unity.sh unity-import-long-compile /path/to/project
bash scripts/unity.sh build /path/to/project
bash scripts/unity.sh tests /path/to/project
bash scripts/unity.sh shaders /path/to/project
bash scripts/unity.sh parse-tests /path/to/project
```

Run one fixture or one test instead of the suite (Unity `-testFilter`: a regex
over the NUnit full name, semicolon-separated list allowed):

```bash
bash scripts/unity.sh tests /path/to/project --filter My.Namespace.MyFixture
bash scripts/unity.sh tests /path/to/project --filter My.Namespace.MyFixture.MyTest
bash scripts/unity.sh tests /path/to/project --category Smoke --assembly Tests --platform PlayMode
```

`--category` maps to `-testCategory`, `--assembly` to `-assemblyNames`, and
`--platform` to `-testPlatform` (EditMode default, or PlayMode). The environment
equivalents are `UNITY_TEST_FILTER`, `UNITY_TEST_CATEGORY`, `UNITY_TEST_ASSEMBLIES`,
and `UNITY_TEST_PLATFORM`; flags take precedence. A selection that matches no test
exits `1` with `No test matched the selection`, never a green result.

Direct CI entry points remain available with `UNITY_PROJECT_PATH` set. Full logs
and results default to `<project>/Logs/kissunitymcp`; `CI_OUTPUT_DIR` overrides
that location, and `UNITY_TEST_LOG_PATH`, `UNITY_TEST_RESULTS_PATH`,
`UNITY_DIAGNOSTICS_PATH`, `UNITY_COMPILE_LOG_PATH`, `UNITY_SHADER_LOG_PATH`, and
`UNITY_SHADER_DIAGNOSTICS_PATH` override single artifacts. `FAIL_ON_SKIPPED=1`
rejects skipped tests. None of these belong in `tools.env`. Keep generated logs,
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

Tool paths are selected in `<project>/.kissunitymcp/tools.env`, with environment
overrides taking precedence. No path is hard-coded to a particular editor version,
Rider version, or solution name. The exact Unity version gate also applies to
MSBuild, but not parse-only. Headless Unity refuses an interactive editor lock;
execution wrappers use a per-project run lock. Parse-only does not lock, so wait
until writers finish before inspecting artifacts. Check processes before removing
a stale lock.

A successful MSBuild process is a C# check only. Use Unity import to validate
asset import, script initialization, compilation symbols and generated project
membership. Both full file logs and process statuses are required for success.
