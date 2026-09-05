---
name: unity-simple-mcp-tests
description: Run Unity EditMode tests headlessly and verify fresh NUnit XML plus the complete editor log. Use to execute tests, diagnose failed or inconclusive results, or enforce skipped-test policy; not merely to parse an earlier run.
---

# Run Unity tests

Read `<plugin-root>/skills/manual-workflow.md` first; use its absolute
`PROJECT_PATH` and `TOOL_ROOT`.

Task: Unity MCP: EditMode tests

## Procedure

1. Require the consuming project's existing Unity Test Framework and actual tests.
   Setup does not install that dependency or artificial passing tests.
2. Read m_EditorVersion and require the wrapper's exact Hub editor gate. Save and
   close interactive Unity for the selected project. Never delete live locks.
3. Run the supported wrapper; it clears the selected log and XML before Unity
   starts, acquires a project run lock, and invokes the result parser afterward.
4. Review both the process status and parser evidence. Do not substitute old XML,
   skip compiler errors, or use a console summary as the sole success signal.

## Manual usage

```bash
bash "$TOOL_ROOT/scripts/unity.sh" tests "$PROJECT_PATH"
```

VS Code: **Unity MCP: EditMode tests**. MCP: `unity_tests` with absolute
`project_path`. The default `UNITY_TEST_PLATFORM` is `EditMode`; ensure an inherited
override is not selecting another platform. `FAIL_ON_SKIPPED=1` rejects skipped
tests. These are environment settings, not MCP arguments or tools.env keys.

## Verification

Require exit `0`, Unity process status `0`, fresh nonempty
`<project>/Logs/SimpleUnityMcp/UnityTests.log` and
`<project>/Logs/SimpleUnityMcp/CITestOutput.xml`, and log marker
`Test run completed. Exiting with code`. Require structurally valid, consistent
NUnit counts, at least one discovered test, passing root `test-run`, and clean
`<project>/Logs/SimpleUnityMcp/CompileErrorsAfterUnityRun.txt`.

Exit `1` includes infrastructure/compiler errors, missing or malformed artifacts,
missing completion evidence, or no discovered tests. Exit `2` means failed or
inconclusive tests, nonpassing results without infrastructure failure, or rejected
skips with `FAIL_ON_SKIPPED=1`. Read failure names/messages/stacks and complete XML
and log. If multiple signals fail, report all evidence, not just the exit category.

Environment overrides are `CI_OUTPUT_DIR`, `UNITY_TEST_LOG_PATH`,
`UNITY_TEST_RESULTS_PATH`, and `UNITY_DIAGNOSTICS_PATH`. Do not add them to
tools.env. Use **Unity MCP: Parse test results** and
`<plugin-root>/skills/unity-simple-mcp-run-parsetests/SKILL.md` to re-read existing
artifacts without launching Unity.