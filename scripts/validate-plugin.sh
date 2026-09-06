#!/usr/bin/env bash
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/common.sh"
root="$(cd "$TOOLS_SCRIPT_DIR/.." && pwd -P)"
cd "$root"
for command in bash git awk sed find sort cmp mktemp cp mv; do command -v "$command" >/dev/null || fail "Required utility missing: $command"; done
for file in .codex-plugin/plugin.json .agents/plugins/marketplace.json .mcp.codex.json .claude-plugin/plugin.json .claude-plugin/marketplace.json .mcp.claude.json scripts/tools.json templates/tasks.json templates/kissunitymcp.code-workspace com.studentutu.kissunitymcp/package.json; do
  json_get "$file" '' validate || fail "Invalid JSON: $file"
done
manifest=.codex-plugin/plugin.json
[[ "$(json_get "$manifest" /name)" == kiss-unity-mcp ]] || fail 'Incorrect plugin name'
version="$(json_get "$manifest" /version)"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([+-][A-Za-z0-9.-]+)?$ ]] || fail 'Invalid plugin semantic version'
for field in description author/name interface/displayName interface/shortDescription interface/longDescription interface/developerName interface/category; do
  [[ -n "$(json_get "$manifest" "/$field")" ]] || fail "Missing plugin metadata: $field"
done
[[ "$(json_get "$manifest" /version)" == "$(json_get com.studentutu.kissunitymcp/package.json /version)" ]] || fail 'Plugin/package versions differ'
[[ "$(json_get com.studentutu.kissunitymcp/package.json /name)" == com.studentutu.kissunitymcp ]] || fail 'Incorrect Unity package identity'
[[ "$(json_get com.studentutu.kissunitymcp/Editor/Studentutu.kissunitymcp.Editor.asmdef /name)" == Studentutu.kissunitymcp.Editor ]] || fail 'Incorrect editor assembly identity'
[[ "$(json_get "$manifest" /skills)" == ./skills/ && "$(json_get "$manifest" /mcpServers)" == ./.mcp.codex.json ]] || fail 'Plugin entry points invalid'
# Harness metadata is separate; all executable behavior stays in the root tree.
for field in name version description author/name author/email author/url homepage repository skills keywords; do
  [[ "$(json_get .claude-plugin/plugin.json "/$field" raw)" == "$(json_get "$manifest" "/$field" raw)" ]] || fail "Codex/Claude plugin metadata differs: $field"
done
[[ "$(json_get .claude-plugin/plugin.json /mcpServers)" == ./.mcp.claude.json ]] || fail 'Claude MCP entry point invalid'
[[ ! -e .mcp.json ]] || fail 'Use explicit harness MCP configs; root .mcp.json would also be auto-discovered'
for harness in codex claude; do
  config=".mcp.$harness.json"
  [[ "$(json_get "$config" /mcpServers/kiss-unity-mcp/command)" == git ]] || fail 'MCP must launch through Git Bash'
  for directory in skills scripts CI com.studentutu.kissunitymcp; do
    [[ ! -e ".$harness-plugin/$directory" ]] || fail "Do not duplicate shared implementation: .$harness-plugin/$directory"
  done
done
[[ "$(json_get .mcp.codex.json /mcpServers/kiss-unity-mcp/cwd)" == . ]] || fail 'Codex MCP must run from the plugin root'
[[ "$(json_get .mcp.claude.json /mcpServers/kiss-unity-mcp/args/0)" == -C &&
   "$(json_get .mcp.claude.json /mcpServers/kiss-unity-mcp/args/1)" == '${CLAUDE_PLUGIN_ROOT}' ]] || fail 'Claude MCP must resolve its installed plugin root'
[[ "$(json_get .agents/plugins/marketplace.json /name)" == studentutu ]] || fail 'Marketplace name must remain studentutu'
[[ "$(json_get .agents/plugins/marketplace.json /plugins/0/name)" == kiss-unity-mcp ]] || fail 'Marketplace plugin name mismatch'
[[ "$(json_get .agents/plugins/marketplace.json /plugins/0/source/source)" == url ]] || fail 'Marketplace must use remote URL source'
[[ "$(json_get .agents/plugins/marketplace.json /plugins/0/source/ref)" == master ]] || fail 'Published source ref must remain master'
[[ "$(json_get .agents/plugins/marketplace.json /plugins/0/source/url)" == "$(json_get "$manifest" /repository)" ]] || fail 'Marketplace repository mismatch'
[[ "$(json_get .agents/plugins/marketplace.json /plugins/0/category)" == "$(json_get "$manifest" /interface/category)" ]] || fail 'Marketplace category mismatch'
case "$(json_get .agents/plugins/marketplace.json /plugins/0/policy/installation)" in AVAILABLE|NOT_AVAILABLE|INSTALLED_BY_DEFAULT) ;; *) fail 'Invalid marketplace installation policy';; esac
case "$(json_get .agents/plugins/marketplace.json /plugins/0/policy/authentication)" in ON_INSTALL|ON_USE) ;; *) fail 'Invalid marketplace authentication policy';; esac
for field in name plugins/0/name plugins/0/source/source plugins/0/source/url plugins/0/source/ref; do
  [[ "$(json_get .claude-plugin/marketplace.json "/$field")" == "$(json_get .agents/plugins/marketplace.json "/$field")" ]] || fail "Codex/Claude marketplace differs: $field"
done
for field in name email; do
  [[ "$(json_get .claude-plugin/marketplace.json "/owner/$field")" == "$(json_get "$manifest" "/author/$field")" ]] || fail "Claude marketplace owner mismatch: $field"
done
[[ "$(json_get com.studentutu.kissunitymcp/package.json /dependencies raw)" == '{}' ]] || fail 'Unity package must not force package dependencies'
[[ ! -d plugins ]] || fail 'Do not duplicate the plugin under plugins/'
while IFS= read -r file; do bash -n "$file" || fail "Bash syntax error: $file"; done < <(find scripts CI/bash bash -name '*.sh' -type f)
[[ -s skills/README.md && -s skills/manual-workflow.md ]] || fail 'Missing skill catalog or manual workflow'
[[ -s skills/kiss-unity-mcp-setup/SKILL.md ]] || fail 'Missing required setup skill'
task_labels=()
index=0
while label="$(json_get templates/tasks.json "/tasks/$index/label" 2>/dev/null)"; do
  task_labels+=("$label")
  index=$((index+1))
done
(( ${#task_labels[@]} > 0 )) || fail 'No end-user tasks found in templates/tasks.json'
for directory in skills/*; do
  [[ -d "$directory" ]] || continue
  file="$directory/SKILL.md"
  [[ -s "$file" ]] || fail "Missing skill instructions: $file"
  awk '
    NR==1 { if($0!="---") exit 1; next }
    $0=="---" { closed=1; exit }
    /^name: [a-z0-9-]+$/ { names++; next }
    /^description: [^[:space:]].*$/ { descriptions++; next }
    { invalid=1 }
    END { exit !(closed && names==1 && descriptions==1 && !invalid) }
  ' "$file" || fail "Invalid skill frontmatter: $file"
  name="$(sed -n 's/^name: //p' "$file")"
  [[ "$name" == "${directory##*/}" && ${#name} -le 64 && "$name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || fail "Skill name must match directory: $file"
  [[ -s "$directory/agents/openai.yaml" ]] || fail "Missing skill UI metadata: $directory"
  grep -q '^  display_name: "[^"]\{1,\}"$' "$directory/agents/openai.yaml" &&
    grep -q '^  short_description: "[^"]\{1,\}"$' "$directory/agents/openai.yaml" || fail "Invalid skill UI metadata: $directory"
  for heading in '## Manual usage' '## Verification'; do
    grep -qF "$heading" "$file" || fail "Missing $heading in $file"
  done
  grep -qF '<plugin-root>/skills/manual-workflow.md' "$file" || fail "Missing shared manual workflow reference: $file"
  awk '/^```bash$/ { code=1; next } /^```$/ { code=0 } code { print }' "$file" | bash -n || fail "Invalid Bash example: $file"
  task="$(sed -n 's/^Task: //p' "$file")"
  # Explicit one-time setup is the sole non-task skill; keep normal checks above.
  if [[ "$name" == kiss-unity-mcp-setup ]]; then
    [[ -z "$task" ]] || fail 'Setup skill must remain separate from VS Code tasks'
    continue
  fi
  [[ -n "$task" && "$task" != *$'\n'* ]] || fail "Skill must declare one end-user task: $file"
  matched=0
  for label in "${task_labels[@]}"; do [[ "$task" != "$label" ]] || matched=1; done
  (( matched )) || fail "Skill task is not in templates/tasks.json: $task ($file)"
done
for label in "${task_labels[@]}"; do
  owners="$(grep -Fxl -- "Task: $label" skills/*/SKILL.md || true)"
  [[ -n "$owners" && "$owners" != *$'\n'* ]] || fail "End-user task must have exactly one skill: $label"
done
[[ -z "$(find scripts CI/bash bash -type f \( -name '*.mjs' -o -name '*.py' -o -name '*.ps1' \) -print)" ]] || fail 'Non-Bash runtime implementation found'
if grep -REn '(^|[[:space:]])(node|nodejs|python[0-9]*|npx|npm|jq|gawk)([[:space:]]|$)|ignorecompilererrors' scripts CI/bash bash --include='*.sh' --exclude='validate-plugin.sh'; then
  fail 'Forbidden runtime dependency or compiler-error bypass'
fi
printf 'Plugin validation passed: %s\n' "$root"
