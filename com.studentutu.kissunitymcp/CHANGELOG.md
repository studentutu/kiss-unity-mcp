# Changelog
All notable changes to this package will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [0.7.5] - 2026-10-11

- Test result parsing is linear. The NUnit validator and failure report re-sliced
  the whole XML after every tag, so a 2 MB result of 2000 tests took a minute to
  parse (as long as the Unity run). Both now stream one tag at a time with POSIX
  awk (`nunit-summary.awk`, `nunit-failures.awk`): 60 s became 0.5 s. Failure
  names decode XML entities, and CRLF results print the same on every platform.
- Diagnostics extraction stops after 2000 lines and reads the Unity log once. A
  log flooded by a per-frame exception produced a diagnostics file larger than
  the log; a 561 MB log now takes under 2 s.

## [0.7.4] - 2026-10-11

- Test parsing never stalls on flooded results. A test that logs an exception
  every frame grew `CITestOutput.xml` to hundreds of MB, and the in-memory NUnit
  parsers ran past the 30-min tool timeout after Unity had finished. Results of
  40 MB or more now fail fast with exit `1`, the size, the root `<test-run>`
  counts and the first failed test names, streamed with `grep`.

## [0.7.3] - 2026-10-04

- Concurrent runs on one project queue instead of failing. Codex starts one MCP
  server per subagent, so parallel `unity_build`/`unity_tests` calls used to fail
  with "Another verification is running"; they now wait for the run lock, keeping
  one Unity/MSBuild per project. A lock left by a hard-killed run is reclaimed
  from its recorded owner pid.
- The run lock moved from `ProjectSettings/.kissunitymcp-run.lock` (version
  controlled) to `Logs/kissunitymcp/run.lock`. A lock at the old path, held by an
  older version, still blocks runs and setup.

## [0.7.2] - 2026-10-04

- No process outlives its tool call. The MCP server watches stdin while a call
  runs: when the client closes the pipe (session end, parallel agent exit) or sends
  `notifications/cancelled`, it kills the Unity/MSBuild process tree and lets the
  wrapper release its locks. Previously an orphaned headless Unity (~2 GB) kept
  running to completion. `ping` is answered during a call; other requests queue.
- Fast MSBuild runs with `/nodeReuse:false` and `UseSharedCompilation=false`.
  Each build used to leave two `MSBuild.exe` nodes and `VBCSCompiler` (~390 MB on
  Windows) alive for 10-15 minutes.
- Lighter launcher: Git runs `bash` directly and the server is sourced into it,
  dropping the resident `sh` process (Windows idle footprint 47.8 -> 41.6 MB private).

## [0.7.1] - 2026-10-01

- A `Temp/UnityLockfile` left behind by an aborted batchmode Unity (compiler
  errors, crash) no longer blocks the next import, test, or shader run. The
  wrappers remove a lock that no running editor holds (Windows: the file is
  deletable only when no editor has it open; macOS/Linux: no Unity process for
  this project) and report it; a lock held by a live editor is still refused.
  Each wrapper also removes the lock its own exited headless process left.

## [0.7.0] - 2026-09-30

- Run a single test, a single fixture (class), a category, or an assembly instead
  of the whole suite: `unity.sh tests <project> --filter|--category|--assembly|--platform`,
  MCP `unity_tests` arguments `test_filter`, `test_category`, `assembly_names`,
  `test_platform`, and the VS Code task **kiss-unity-mcp: Run tests by filter**.
  A selection that matches no test is exit `1` with a `No test matched the selection`
  diagnostic instead of a silent pass.
- Every `unity_*` MCP result now starts with a verdict line, `<tool>: exit N (...)`,
  and the server instructions and tool descriptions tell agents to use the result
  as the evidence rather than reading Unity logs or launching Unity themselves.
- Skills rewritten as short agent-facing instructions (tool, arguments, how to read
  the result, what never to do). The validator rejects skills over 80 lines or ones
  that send the agent to a full log; one skill may own several VS Code tasks.

## [Unreleased]

- Add Codex and Claude Code marketplace support over the same skills, Bash tools,
  MCP server, and embedded Unity package (aligned at version 0.6.0).
- Standardize package, assembly, setup, workspace, and log paths on `kissunitymcp`.
- Keep the plugin/repository name `kiss-unity-mcp` and existing C# entry points
  and verification markers.

## [0.1.0] - 2026-08-29

### This is the first release of *\<kissunitymcp\>*.

Simple and minimal unity MCP for buildings, testing, and verifying code and shaders.
Verified minimal package for full-unity-forced recompilation, all shader-recompilation.
All error logs are properly logged and never skipped.
Actual log.file is authority for the bash process.
