#!/usr/bin/env bash
# Opt-in integration verification against the caller-selected disposable project.
# Each deliberate failure is restored; full per-step evidence is retained.
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/common.sh"
[[ $# -ge 1 && $# -le 2 ]] || fail "Usage: bash $0 <disposable Unity project> [--tests-and-shaders|--shaders-only]"
mode="${2:-all}"
[[ "$mode" == all || "$mode" == --tests-and-shaders || "$mode" == --shaders-only ]] || fail "Unknown verification mode: $mode"
require_project "$(to_unix_path "$1")"
root="$(cd "$TOOLS_SCRIPT_DIR/.." && pwd -P)"
probe="$PROJECT/Assets/kissunitymcp"
[[ ! -e "$probe" && ! -e "$probe.meta" ]] || fail "Verification fixture already exists: $probe"
[[ -f "$PROJECT/.kissunitymcp/scripts/unity.sh" ]] || fail 'Set up this project first'
# Doctor passes the exact version gate before creating fixtures or launching tools.
bash "$PROJECT/.kissunitymcp/scripts/unity.sh" doctor "$PROJECT"
mkdir -p "$probe/Editor" "$probe/Tests"
cleanup() {
  [[ "$probe" == "$PROJECT/Assets/kissunitymcp" && -d "$probe" && ! -L "$probe" ]] || return
  rm -rf -- "$probe"
  rm -f -- "$probe.meta"
}
trap cleanup EXIT
evidence="$PROJECT/Logs/kissunitymcp/Verification-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$evidence"
step() {
  local expected="$1" name="$2" action="$3" status file; shift 3
  printf '\nVERIFY %s: expected %s\n' "$name" "$expected"
  mkdir "$evidence/$name"
  set +e
  bash "$PROJECT/.kissunitymcp/scripts/unity.sh" "$action" "$PROJECT" "$@" > "$evidence/$name/command.log" 2>&1
  status=$?
  set -e
  for file in "$PROJECT/Logs/kissunitymcp"/*; do [[ ! -f "$file" ]] || cp "$file" "$evidence/$name/"; done
  printf '%s\n' "$status" > "$evidence/$name/exit-code.txt"
  if (( status!=expected )); then cat "$evidence/$name/command.log" >&2; fail "$name expected exit $expected, got $status. Evidence: $evidence"; fi
  printf '%s passed (exit %s).\n' "$name" "$status"
}
cat > "$probe/CompilationProbe.cs" <<'CS'
public static class SimpleMcpCompilationProbe { public static int Value => 1; }
CS
cat > "$probe/Editor/ProbeImporter.cs" <<'CS'
using System.IO;
using UnityEditor.AssetImporters;
using UnityEngine;
[ScriptedImporter(1, "simplemcptest")]
public sealed class SimpleMcpProbeImporter : ScriptedImporter
{
    public override void OnImportAsset(AssetImportContext context)
    {
        var text = File.ReadAllText(context.assetPath);
        if (text.Trim() == "broken")
            context.LogImportError("SIMPLE_MCP_EXPECTED_IMPORT_FAILURE");
        var asset = new TextAsset(text);
        context.AddObjectToAsset("main", asset);
        context.SetMainObject(asset);
    }
}
CS
cat > "$probe/Tests/Verification.asmdef" <<'JSON'
{"name":"SimpleMcp.Verification.Tests","optionalUnityReferences":["TestAssemblies"],"includePlatforms":["Editor"]}
JSON
cat > "$probe/Tests/ProbeTests.cs" <<'CS'
using NUnit.Framework;
public class SimpleMcpProbeTests { [Test] public void Verification() { Assert.IsTrue(true); } }
CS
printf 'good\n' > "$probe/import.simplemcptest"
printf 'Shader "Hidden/SimpleMcpVerification" { SubShader { Pass {} } }\n' > "$probe/Probe.shader"
step 0 01-import-green import
if [[ "$mode" == all ]]; then
step 0 02-msbuild-green build
printf 'public static class SimpleMcpCompilationProbe { public static int Value => UndefinedSymbol; }\n' > "$probe/CompilationProbe.cs"
step 1 03-msbuild-red build
printf 'public static class SimpleMcpCompilationProbe { public static int Value => 2; }\n' > "$probe/CompilationProbe.cs"
step 0 04-msbuild-restored build
printf 'broken\n' > "$probe/import.simplemcptest"
step 1 05-import-red import
printf 'restored\n' > "$probe/import.simplemcptest"
step 0 06-import-restored import
fi
if [[ "$mode" != --shaders-only ]]; then
step 0 07-tests-green tests
sed 's/IsTrue(true)/IsTrue(false)/' "$probe/Tests/ProbeTests.cs" > "$evidence/ProbeTests.failed.cs"
cp "$evidence/ProbeTests.failed.cs" "$probe/Tests/ProbeTests.cs"
step 2 08-tests-red tests
sed 's/IsTrue(false)/IsTrue(true)/' "$probe/Tests/ProbeTests.cs" > "$evidence/ProbeTests.restored.cs"
cp "$evidence/ProbeTests.restored.cs" "$probe/Tests/ProbeTests.cs"
step 0 09-tests-restored tests
fi
printf 'this is not a valid shader\n' > "$probe/Probe.shader"
step 1 10-shaders-red shaders
printf 'Shader "Hidden/SimpleMcpVerification" { SubShader { Pass {} } }\n' > "$probe/Probe.shader"
step 0 11-shaders-restored shaders
cleanup
trap - EXIT
step 0 12-final-import import
step 0 13-final-msbuild build
printf '\nUNITY_WORKFLOW_VERIFIED mode=%s\nEvidence: %s\n' "$mode" "$evidence"
