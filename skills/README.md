# kiss-unity-mcp task skills

These skills describe the same supported workflows used by agents and manual
developers. Start with the [shared manual workflow](manual-workflow.md) for absolute
path variables, tools.env, the exact editor gate, VS Code tasks, and log/exit rules.
The [repository manual](../Readme.md), [CI manual](../CI/RunUnityTestsReadme.md),
and [Unity package README](../com.studentutu.kissunitymcp/README.md) remain the
installation and capability references.

Skills cover the actions in [the task template](../templates/tasks.json), plus
[explicit one-time setup](kiss-unity-mcp-setup/SKILL.md). Setup is the sole
non-task exception; all skills include manual usage, prerequisites, and verification.

| Skill | VS Code task | Purpose |
| --- | --- | --- |
| [Doctor](kiss-unity-mcp-doctor/SKILL.md) | kiss-unity-mcp: Check tool paths | Resolve exact Unity and Rider paths without launching |
| [Import](kiss-unity-mcp-import/SKILL.md) | kiss-unity-mcp: Import and generate solution (long-compile) | Authoritative import, compile, IDE generation |
| [Fast build](kiss-unity-mcp-build/SKILL.md) | kiss-unity-mcp: Fast MSBuild | Incremental existing-C# follow-up |
| [Tests](kiss-unity-mcp-tests/SKILL.md) | kiss-unity-mcp: EditMode tests | Execute tests and verify fresh log/XML |
| [Run parsetests](kiss-unity-mcp-run-parsetests/SKILL.md) | kiss-unity-mcp: Parse test results | Validate saved log/XML without launching Unity |
| [Shaders](kiss-unity-mcp-shaders/SKILL.md) | kiss-unity-mcp: Compile shaders | Check imported shaders and diagnostics |
| [Settings](kiss-unity-mcp-settings/SKILL.md) | kiss-unity-mcp: Open tool settings | Edit per-project Unity and Rider paths |

Setup remains explicit and separate from routine Unity work.
Compatibility wrappers, MCP internals, and repository
maintenance remain available through their existing APIs but are not skills.
