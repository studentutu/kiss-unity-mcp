---
name: kiss-unity-mcp-tests
description: Run Unity Test Framework tests headlessly with kiss-unity-mcp, without an open editor. Use to run one test, one fixture (class), one category, or the whole EditMode/PlayMode suite and get the verdict, failures, and stack traces in one result. Do not run Unity yourself or read its logs.
---

# Run Unity tests

Read `<plugin-root>/skills/manual-workflow.md` first.

Task: kiss-unity-mcp: EditMode tests
Task: kiss-unity-mcp: Run tests by filter

## Procedure

1. Prefer a narrow run. Set `test_filter` to the fixture (`MyFixture` or
   `My.Namespace.MyFixture`) or the single test (`My.Namespace.MyFixture.MyTest`;
   parameterized: `MyFixture.MyTest(1)`). It is a regex over the NUnit full name;
   separate several with `;`. Run the whole suite only when the user asks.
2. Call MCP server `kiss-unity-mcp` tool `unity_tests` with absolute
   `project_path` and optional `test_filter`, `test_platform` (`EditMode`
   default, or `PlayMode`), `test_category`, `assembly_names`.
3. Report the verdict line, the `Test summary:` line, and each `-- Test.Name --`
   failure block from the result. Nothing else needs to be read.

## Manual usage

```bash
bash "$TOOL_ROOT/scripts/unity.sh" tests "$PROJECT_PATH" --filter "My.Namespace.MyFixture.MyTest"
```

Omit `--filter` for the whole suite. Options: `--filter`, `--category`,
`--assembly`, `--platform EditMode|PlayMode`. VS Code: **kiss-unity-mcp: EditMode
tests** or **kiss-unity-mcp: Run tests by filter**.

## Verification

- Exit `0`: `Test summary: result=Passed ...` and `Unity tests passed.`
- Exit `2`: failing or inconclusive tests; each failure's name, message, and
  stack trace is already in the result.
- Exit `1`: compile or tool failure, no tests discovered, or a filter that
  matched nothing (`No test matched the selection`). Fix the filter or code;
  a compile error is reported in the extracted diagnostics in the result.

Do not open `UnityTests.log` or `CITestOutput.xml`; do not rerun with a
handwritten Unity command. To re-read a finished run without launching Unity,
use `kiss-unity-mcp-run-parsetests`.
