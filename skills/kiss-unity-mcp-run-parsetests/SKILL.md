---
name: kiss-unity-mcp-run-parsetests
description: Re-read the last kiss-unity-mcp test run (saved NUnit XML and Unity log) without launching Unity. Use to inspect failures of a finished run again; use kiss-unity-mcp-tests to actually run tests.
---

# Parse existing test results

Read `<plugin-root>/skills/manual-workflow.md` first. This needs no Unity
editor and takes no run lock. There is no MCP tool for it; `unity_tests` would
launch Unity.

Task: kiss-unity-mcp: Parse test results

## Manual usage

```bash
bash "$TOOL_ROOT/scripts/unity.sh" parse-tests "$PROJECT_PATH"
```

Defaults to the last run's `<project>/Logs/kissunitymcp/CITestOutput.xml` and
`UnityTests.log`. For an archived pair add
`--test-results <xml> --unity-log <log>`. VS Code: **kiss-unity-mcp: Parse
test results**.

## Procedure

1. Wait until no test or import operation is writing the artifacts.
2. Run the command and report the `Test summary:` line and each
   `-- Test.Name --` failure block. The command prints everything needed.
3. Missing artifacts mean no run exists yet; report that instead of starting
   a run or setup on your own.

## Verification

Exit `0` prints `Test result and Unity log are valid.` Exit `2` means failed
or inconclusive tests. Exit `1` means missing, truncated, or inconsistent
artifacts, no discovered tests, or compile diagnostics. A passing parse only
validates saved files; it does not prove the code still passes. Do not open the
XML or log yourself; the output is the extraction.
