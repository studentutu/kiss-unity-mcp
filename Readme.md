# Unity Simple MCP

Unity Simple MCP is a local Codex plugin that installs the bundled
`com.studentutu.unitysimplemcp` package into a Unity project as an embedded
package. Setup is explicit, project-scoped, and idempotent. It does not launch
Unity or silently replace an existing package.

The plugin combines a narrow setup skill with a local MCP server. The Unity
package remains the editor-side boundary for compile, test, shader, and utility
entry points.

## Repository layout

```text
.agents/plugins/marketplace.json        Repository marketplace catalog
.codex-plugin/plugin.json              Codex plugin manifest
.mcp.json                              Bundled local MCP server configuration
skills/unity-simple-mcp-setup/         One-time setup workflow
scripts/mcp-server.mjs                 Dependency-free stdio MCP server
scripts/setup-unity-project.mjs        Manual setup entry point
scripts/unity-project.mjs              Setup and inspection implementation
scripts/validate-plugin.mjs            Dependency-free plugin validator
com.studentutu.unitysimplemcp/         Embedded Unity package source
CI/bash/                               Authoritative Unity verification scripts
```

## Requirements

- A local Codex host with this plugin installed and enabled
- Node.js 18 or newer available as `node` for the bundled MCP server
- Unity 2023.1 or newer; the exact project version is declared in
  `ProjectSettings/ProjectVersion.txt`
- Git and Bash for the repository's Unity CI scripts

## Install from the marketplace

This repository is both the `studentutu` marketplace and the Git-backed source
for the `unity-simple-mcp` plugin. Add the repository marketplace once, then
install the plugin from its catalog:

```text
codex plugin marketplace add studentutu/unity-simple-mcp --ref master --json
codex plugin add unity-simple-mcp@studentutu --json
```

Confirm the configured source and installed plugin with:

```text
codex plugin marketplace list
codex plugin list
```

Restart the Codex desktop app and start a new task after installation. Skills
and MCP servers are discovered when a task starts.

## One-time project setup

Ask Codex to set up Unity Simple MCP in a specific Unity project. The plugin
first inspects the project, then calls the approval-gated setup tool only if the
package is absent.

The manual equivalent is:

```text
node scripts/setup-unity-project.mjs <path-to-unity-project>
```

Setup requires `Assets/`, `Packages/`, and
`ProjectSettings/ProjectVersion.txt`. It copies the package to:

```text
<unity-project>/Packages/com.studentutu.unitysimplemcp
```

It also records the verified source digest in:

```text
<unity-project>/ProjectSettings/SimpleUnityMcpSetup.json
```

Running setup again against the same package is a no-op. If a different file or
package already occupies the destination, setup fails without modifying it.
Replacement is intentionally outside the MCP tool and requires an explicit
manual command:

```text
node scripts/setup-unity-project.mjs <path-to-unity-project> --replace
```

Use `--dry-run` to validate without writing.

## Unity verification

Setup itself never starts Unity. Before any later Unity-backed command, resolve
the exact editor version required by the target project's
`ProjectSettings/ProjectVersion.txt`; never substitute another installed
version. Close any interactive editor holding the same project lock.

The repository's authoritative entry points are:

| Intent | Command |
| --- | --- |
| Compile/import and regenerate project files | `bash ./CI/bash/rebuildSolutionFromUnityItself.sh` |
| Fast C# follow-up compile | `bash ./CI/bash/rebuildSolutionWithRiderMsBuild.sh` |
| EditMode tests | `bash ./CI/bash/runTestsBash.sh` |
| Test-result parse only | `bash ./CI/bash/parseTestErrors.sh` |
| Shader reimport and validation | `bash ./CI/bash/compileShaders.sh` |

Set `UNITY_PROJECT_PATH` when the target project is not this repository's
default `UnityProj` layout. Full logs and explicit completion markers are the
source of truth; a zero-looking terminal transcript alone is not success. See
`CI/RunUnityTestsReadme.md` for artifacts, overrides, and exit-code semantics.

## Plugin development

Validate the complete plugin before committing:

```text
node scripts/validate-plugin.mjs
```

The validator, setup workflow, and MCP server use only Node built-ins. There are
no external runtime package dependencies. Test the MCP server with JSON-RPC
messages over standard input; protocol output is written only to standard output
and diagnostics only to standard error.

## Publish an update

The marketplace tracks the repository's `master` branch. To publish an update:

1. Change the plugin and embedded package together.
2. Bump the matching versions in `.codex-plugin/plugin.json` and
   `com.studentutu.unitysimplemcp/package.json`.
3. Run `node scripts/validate-plugin.mjs` and the relevant Unity verification.
4. Merge and push the verified commit to `master`.
5. Refresh and reinstall the plugin:

```text
codex plugin marketplace upgrade studentutu
codex plugin add unity-simple-mcp@studentutu --json
```

Restart Codex and use a new task after reinstalling. A pushed feature branch is
not a release: the catalog intentionally resolves the plugin from `master`.
