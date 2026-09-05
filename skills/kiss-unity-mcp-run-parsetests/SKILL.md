---
name: kiss-unity-mcp-run-parsetests
description: Use kiss-unity-mcp to parse saved Unity test logs and NUnit XML through unity.sh parse-tests without launching Unity. Use to inspect test failures, validate existing artifacts, or enforce skipped-test policy instead of rerunning tests.
---

# Parse existing test results

Read `<plugin-root>/skills/manual-workflow.md` first; use its absolute
`PROJECT_PATH` and `TOOL_ROOT`. This reads existing artifacts and overwrites
extracted diagnostics. It does not execute tests or require Unity/Rider to be
installed, and the exact editor gate is not needed.

Task: kiss-unity-mcp: Parse test results

## Manual usage

Choose **Terminal > Run Task > kiss-unity-mcp: Parse test results**, or run:

```bash
bash "$TOOL_ROOT/scripts/unity.sh" parse-tests "$PROJECT_PATH"
```

The installed task uses the workspace's Unity project. The checkout task prompts
for the absolute target project path. Both call the same dispatcher action, not
the `tests` action or a compatibility wrapper. There is no parse-only MCP tool;
use the Bash command rather than `unity_tests`, which launches Unity.

For a specific archived log/XML pair, set `ARTIFACT_DIR` to its absolute directory:

```bash
ARTIFACT_DIR="/absolute/path/to/test artifacts"
UNITY_DIAGNOSTICS_PATH="$ARTIFACT_DIR/ParsedDiagnostics.txt" \
  bash "$TOOL_ROOT/scripts/unity.sh" parse-tests "$PROJECT_PATH" \
  --test-results "$ARTIFACT_DIR/CITestOutput.xml" \
  --unity-log "$ARTIFACT_DIR/UnityTests.log"
```

## Procedure

1. Select the log and XML from the same completed run. Do not parse files while a
   test/import operation is writing them; parse-only does not acquire a run lock.
2. Defaults are `<project>/Logs/kissunitymcp/CITestOutput.xml` and
   `<project>/Logs/kissunitymcp/UnityTests.log`. Diagnostics are overwritten at
   `<project>/Logs/kissunitymcp/CompileErrorsAfterUnityRun.txt`. Never set the
   diagnostic output to either input file.
3. Use environment overrides `CI_OUTPUT_DIR`, `UNITY_TEST_RESULTS_PATH`,
   `UNITY_TEST_LOG_PATH`, and `UNITY_DIAGNOSTICS_PATH` when needed. Explicit
   `--test-results` and `--unity-log` flags take precedence over their environment
   defaults. `FAIL_ON_SKIPPED=1` rejects skipped tests. None are tools.env keys.
4. Read the summary, failure names/messages/stacks, complete XML/log, and extracted
   diagnostics. Missing artifacts are a failure, not permission to run setup or
   start a new test run automatically.

## Verification

Require exit `0`, nonempty matching artifacts, structurally valid and consistent
NUnit counts, at least one discovered test, passing root `test-run`, log marker
`Test run completed. Exiting with code`, and clean extracted diagnostics. The
success summary is `Test result and Unity log are valid.`

Exit `1` means missing/malformed/inconsistent evidence, missing completion marker,
compiler/infrastructure diagnostics, or zero tests. Exit `2` means failed,
inconclusive, or nonpassing tests, or skips rejected by policy. Preserve the real
exit status and report all conflicting signals rather than only a console tail.

A passing parse validates only the supplied artifacts. It cannot prove freshness
or reconstruct the original Unity process status. To claim a new test run passed,
use the tests skill and require its separate process/fresh-artifact evidence.