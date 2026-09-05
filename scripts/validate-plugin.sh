#!/usr/bin/env bash
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/common.sh"
root="$(cd "$TOOLS_SCRIPT_DIR/.." && pwd -P)"
cd "$root"
for command in bash git awk sed find sort cmp mktemp cp mv; do command -v "$command" >/dev/null || fail "Required utility missing: $command"; done
for file in .codex-plugin/plugin.json .agents/plugins/marketplace.json .mcp.json scripts/tools.json templates/tasks.json templates/unity-simple-mcp.code-workspace com.studentutu.unitysimplemcp/package.json; do
  json_get "$file" '' validate || fail "Invalid JSON: $file"
done
manifest=.codex-plugin/plugin.json
[[ "$(json_get "$manifest" /name)" == unity-simple-mcp ]] || fail 'Incorrect plugin name'
version="$(json_get "$manifest" /version)"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([+-][A-Za-z0-9.-]+)?$ ]] || fail 'Invalid plugin semantic version'
for field in description author/name interface/displayName interface/shortDescription interface/longDescription interface/developerName interface/category; do
  [[ -n "$(json_get "$manifest" "/$field")" ]] || fail "Missing plugin metadata: $field"
done
[[ "$(json_get "$manifest" /version)" == "$(json_get com.studentutu.unitysimplemcp/package.json /version)" ]] || fail 'Plugin/package versions differ'
[[ "$(json_get "$manifest" /skills)" == ./skills/ && "$(json_get "$manifest" /mcpServers)" == ./.mcp.json ]] || fail 'Plugin entry points invalid'
[[ "$(json_get .mcp.json /mcpServers/unity_simple_mcp/command)" == git ]] || fail 'MCP must launch through Git Bash'
[[ "$(json_get .agents/plugins/marketplace.json /name)" == studentutu ]] || fail 'Marketplace name must remain studentutu'
[[ "$(json_get .agents/plugins/marketplace.json /plugins/0/name)" == unity-simple-mcp ]] || fail 'Marketplace plugin name mismatch'
[[ "$(json_get .agents/plugins/marketplace.json /plugins/0/source/source)" == url ]] || fail 'Marketplace must use remote URL source'
[[ "$(json_get .agents/plugins/marketplace.json /plugins/0/source/ref)" == master ]] || fail 'Published source ref must remain master'
[[ "$(json_get .agents/plugins/marketplace.json /plugins/0/source/url)" == "$(json_get "$manifest" /repository)" ]] || fail 'Marketplace repository mismatch'
[[ "$(json_get .agents/plugins/marketplace.json /plugins/0/category)" == "$(json_get "$manifest" /interface/category)" ]] || fail 'Marketplace category mismatch'
case "$(json_get .agents/plugins/marketplace.json /plugins/0/policy/installation)" in AVAILABLE|NOT_AVAILABLE|INSTALLED_BY_DEFAULT) ;; *) fail 'Invalid marketplace installation policy';; esac
case "$(json_get .agents/plugins/marketplace.json /plugins/0/policy/authentication)" in ON_INSTALL|ON_USE) ;; *) fail 'Invalid marketplace authentication policy';; esac
[[ "$(json_get com.studentutu.unitysimplemcp/package.json /dependencies raw)" == '{}' ]] || fail 'Unity package must not force package dependencies'
[[ ! -d plugins ]] || fail 'Do not duplicate the plugin under plugins/'
while IFS= read -r file; do bash -n "$file" || fail "Bash syntax error: $file"; done < <(find scripts CI/bash bash -name '*.sh' -type f)
for file in skills/*/SKILL.md; do
  [[ "$(head -n 1 "$file")" == --- ]] || fail "Missing skill frontmatter: $file"
  grep -q '^name: ' "$file" && grep -q '^description: ' "$file" || fail "Invalid skill frontmatter: $file"
done
[[ -z "$(find scripts CI/bash bash -type f \( -name '*.mjs' -o -name '*.py' -o -name '*.ps1' \) -print)" ]] || fail 'Non-Bash runtime implementation found'
if grep -REn '(^|[[:space:]])(node|nodejs|python[0-9]*|npx|npm|jq|gawk)([[:space:]]|$)|ignorecompilererrors' scripts CI/bash bash --include='*.sh' --exclude='validate-plugin.sh'; then
  fail 'Forbidden runtime dependency or compiler-error bypass'
fi
printf 'Plugin validation passed: %s\n' "$root"
