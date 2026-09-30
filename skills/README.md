# kiss-unity-mcp task skills

Skills are written for agents: each names one MCP tool (or one Bash command
without MCP), how to choose its arguments, and how to read its result. The
[shared agent contract](manual-workflow.md) holds the rules every skill
assumes, above all: never run Unity or MSBuild yourself, never write new
scripts, and never read full Unity logs; the tool result already contains the
verdict, failures, and extracted diagnostics.

Human-facing installation, VS Code, CI, and custom tool-path details are in the
[repository manual](../Readme.md), the [CI manual](../CI/RunUnityTestsReadme.md),
and the [Unity package README](../com.studentutu.kissunitymcp/README.md).

Skills cover the actions in [the task template](../templates/tasks.json), plus
[explicit one-time setup](kiss-unity-mcp-setup/SKILL.md), the sole non-task
skill. Codex and Claude Code load this same directory. In Codex, invoke a skill
as `$kiss-unity-mcp-tests`; in Claude Code, as
`/kiss-unity-mcp:kiss-unity-mcp-tests`. The `agents/openai.yaml` files supply
Codex UI metadata only. Follow the [installation instructions](../Readme.md#install).

| Skill | MCP tool | VS Code task | Purpose |
| --- | --- | --- | --- |
| [Setup](kiss-unity-mcp-setup/SKILL.md) | `inspect_unity_project`, `setup_unity_project` | none | Inspect; install once on explicit request |
| [Doctor](kiss-unity-mcp-doctor/SKILL.md) | `unity_doctor` | Check tool paths | Resolve exact Unity and Rider paths without launching |
| [Import](kiss-unity-mcp-import/SKILL.md) | `unity_import` | unity-import-long-compile | Authoritative import, compile, solution generation |
| [Fast build](kiss-unity-mcp-build/SKILL.md) | `unity_build` | Fast MSBuild | Incremental C# check without Unity |
| [Tests](kiss-unity-mcp-tests/SKILL.md) | `unity_tests` (`test_filter`, `test_platform`, `test_category`, `assembly_names`) | EditMode tests; Run tests by filter | One test, one fixture, or the suite |
| [Run parsetests](kiss-unity-mcp-run-parsetests/SKILL.md) | none | Parse test results | Re-read a finished run without Unity |
| [Shaders](kiss-unity-mcp-shaders/SKILL.md) | `unity_shaders` | Compile shaders | Shader compiler diagnostics |
| [Settings](kiss-unity-mcp-settings/SKILL.md) | none | Open tool settings | Edit per-project tool paths |

Validation keeps skills small (`scripts/validate-plugin.sh` rejects skills over
80 lines or ones that tell the agent to read a full log).
