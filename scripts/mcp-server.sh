#!/usr/bin/env bash
# Sequential stdio MCP adapter. Every operation delegates to the manual Bash API.
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/common.sh"
work="$(mktemp -d "${TMPDIR:-/tmp}/unity-mcp-rpc.XXXXXXXX")"
[[ "$work" == "${TMPDIR:-/tmp}"/unity-mcp-rpc.* ]] || fail "Unsafe temporary path"
trap 'rm -rf -- "$work"' EXIT
version="$(json_get "$TOOLS_SCRIPT_DIR/../com.studentutu.kissunitymcp/package.json" /version)"
reply_error() { printf '{"jsonrpc":"2.0","id":%s,"error":{"code":%s,"message":%s}}\n' "$id" "$1" "$(quote "$2")"; }
tool_call() {
  local name project dry action
  name="$(json_get "$work/request" /params/name)" || fail 'Missing tool name'
  [[ "$(json_get "$work/request" /params/arguments/project_path type)" == string ]] || fail 'project_path must be a string'
  project="$(json_get "$work/request" /params/arguments/project_path)"
  [[ -n "$project" ]] || fail 'project_path must not be empty'
  case "$name" in
    inspect_unity_project) bash "$TOOLS_SCRIPT_DIR/setup-unity-project.sh" "$project" --dry-run;;
    setup_unity_project)
      dry="$(json_get "$work/request" /params/arguments/dry_run raw 2>/dev/null || true)"
      case "$dry" in
        ''|false) bash "$TOOLS_SCRIPT_DIR/setup-unity-project.sh" "$project";;
        true) bash "$TOOLS_SCRIPT_DIR/setup-unity-project.sh" "$project" --dry-run;;
        *) fail 'dry_run must be boolean';;
      esac;;
    unity_doctor) action=doctor;;
    unity_import) action=unity-import-long-compile;;
    unity_build) action=build;;
    unity_tests) action=tests;;
    unity_shaders) action=shaders;;
    *) fail "Unknown tool: $name";;
  esac
  if [[ -n "${action:-}" ]]; then bash "$TOOLS_SCRIPT_DIR/unity.sh" "$action" "$project"; fi
}
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ -n "$line" ]] || continue
  printf '%s\n' "$line" > "$work/request"
  id=null
  if ! json_get "$work/request" '' validate >/dev/null; then reply_error -32700 'Invalid JSON (or unsupported NUL / resource limit)'; continue; fi
  if [[ "$(json_get "$work/request" '' type)" != object || "$(json_get "$work/request" /jsonrpc 2>/dev/null || true)" != 2.0 ]]; then reply_error -32600 'Expected a JSON-RPC 2.0 object'; continue; fi
  if ! id="$(json_get "$work/request" /id raw)"; then continue; fi
  case "$(json_get "$work/request" /id type)" in string|number) ;; *) id=null; reply_error -32600 'Request id must be a string or number'; continue;; esac
  method="$(json_get "$work/request" /method 2>/dev/null || true)"
  case "$method" in
    initialize)
      protocol="$(json_get "$work/request" /params/protocolVersion 2>/dev/null || true)"
      case "$protocol" in 2024-11-05|2025-03-26|2025-06-18|2025-11-25) ;; *) protocol=2025-06-18;; esac
      printf '{"jsonrpc":"2.0","id":%s,"result":{"protocolVersion":"%s","capabilities":{"tools":{"listChanged":false}},"serverInfo":{"name":"kiss-unity-mcp","version":"%s"},"instructions":"Inspect before explicit one-time setup. Never replace conflicts automatically. Manual API: scripts/unity.sh. Full logs are authoritative."}}\n' "$id" "$protocol" "$version";;
    ping) printf '{"jsonrpc":"2.0","id":%s,"result":{}}\n' "$id";;
    tools/list) printf '{"jsonrpc":"2.0","id":%s,"result":%s}\n' "$id" "$(json_get "$TOOLS_SCRIPT_DIR/tools.json" '' raw)";;
    tools/call)
      # Subshell isolates fail/errexit and keeps child processes off MCP stdin.
      set +e
      (set -e; tool_call) > "$work/output" 2>&1 < /dev/null
      status=$?
      set -e
      is_error=false; (( status==0 )) || is_error=true
      summary="$(tail -c 24000 "$work/output")"
      printf '{"jsonrpc":"2.0","id":%s,"result":{"isError":%s,"content":[{"type":"text","text":%s}]}}\n' "$id" "$is_error" "$(quote "$summary")";;
    *) reply_error -32601 "Unknown method: $method";;
  esac
done
