# Changelog
All notable changes to this package will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

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
