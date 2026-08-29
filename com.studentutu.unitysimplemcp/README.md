# Simple Unity MCP

Editor-side tools for a headless, agent-friendly Unity workflow. The package is
the Unity boundary; filesystem setup and process orchestration stay outside the
package and call only stable, fully qualified editor methods.

## CI execute methods

- `SimpleUnityMCP.Editor.CiTools.RegenerateProjectFilesAndExit`
  refreshes the Asset Database, synchronizes IDE project files, and emits
  `SIMPLE_UNITY_MCP_CI:PROJECT_FILES_SYNCED` on success. The shell command must
  pass Unity's `-quit` argument.
- `SimpleUnityMCP.Editor.CiTools.ForceCompileAndExit`
  requests a clean script compilation, reports compiler diagnostics, and exits
  Unity with `0` on success or `1` on compiler failure.
- `SimpleUnityMCP.Editor.ShaderCompileTool.CompileAllProjectShaders`
  reimports project shaders, emits stable `SHADER_COMPILATION_PASSED` or
  `SHADER_COMPILATION_FAILED` markers, and exits non-zero when errors are found.

Do not copy shell scripts into this package. Package code must not assume a
consumer repository path or a locally installed Unity/Rider version.

## Requirements

- Unity 2023.1 or newer (required by Addressables 2.9.1)
- Unity Test Framework for the included package tests
- Addressables and Scriptable Build Pipeline (declared package dependencies) for
  the cache-cleaning editor utilities

When installed through the Unity Simple MCP Codex plugin, setup copies only this
package into the consumer project's `Packages/` directory. It does not copy CI
wrappers or alter `Packages/manifest.json`. Use the plugin repository's
`CI/RunUnityTestsReadme.md` or the consumer repository's equivalent wrappers for
command-line use and environment overrides.
