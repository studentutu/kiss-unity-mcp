# Unity CI / manual Bash API

The complete installation, tool selection, commands, and log contract are in
[the repository manual](../Readme.md). `CI/bash` is the authoritative implementation;
legacy `bash/` entry points only forward here.

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

All paths are selected in `<project>/.unity-simple-mcp/tools.env`, with environment
overrides taking precedence. No path is hard-coded to a particular editor version,
Rider version, or solution name. The exact Unity version gate also applies to
MSBuild. Headless Unity refuses an interactive editor lock; all verification
commands use a per-project run lock. Check processes before removing a stale lock.

A successful MSBuild process is a C# check only. Use Unity import to validate
asset import, script initialization, compilation symbols and generated project
membership. Both full file logs and process statuses are required for success.
