# End-user task skills

These skills describe the same supported workflows used by agents and manual
developers. Start with the [shared manual workflow](manual-workflow.md) for absolute
path variables, tools.env, the exact editor gate, VS Code tasks, and log/exit rules.
The [repository manual](../Readme.md), [CI manual](../CI/RunUnityTestsReadme.md),
and [Unity package README](../com.studentutu.unitysimplemcp/README.md) remain the
installation and capability references.

Skills cover the actions in [the task template](../templates/tasks.json), plus
[explicit one-time setup](unity-simple-mcp-setup/SKILL.md). Setup is the sole
non-task exception; all skills include manual usage, prerequisites, and verification.

| Skill | VS Code task | Purpose |
| --- | --- | --- |
| [Doctor](unity-simple-mcp-doctor/SKILL.md) | Unity MCP: Check tool paths | Resolve exact Unity and Rider paths without launching |
| [Import](unity-simple-mcp-import/SKILL.md) | Unity MCP: Import and generate solution (long-compile) | Authoritative import, compile, IDE generation |
| [Fast build](unity-simple-mcp-build/SKILL.md) | Unity MCP: Fast MSBuild | Incremental existing-C# follow-up |
| [Tests](unity-simple-mcp-tests/SKILL.md) | Unity MCP: EditMode tests | Execute tests and verify fresh log/XML |
| [Run parsetests](unity-simple-mcp-run-parsetests/SKILL.md) | Unity MCP: Parse test results | Validate saved log/XML without launching Unity |
| [Shaders](unity-simple-mcp-shaders/SKILL.md) | Unity MCP: Compile shaders | Check imported shaders and diagnostics |
| [Settings](unity-simple-mcp-settings/SKILL.md) | Unity MCP: Open tool settings | Edit per-project Unity and Rider paths |

Setup remains explicit and separate from routine Unity work.
Compatibility wrappers, MCP internals, and repository
maintenance remain available through their existing APIs but are not skills.