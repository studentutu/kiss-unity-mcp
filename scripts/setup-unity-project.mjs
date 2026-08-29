#!/usr/bin/env node

import { setupUnityProject, WorkflowError } from "./unity-project.mjs";

function usage() {
  return [
    "Usage: node scripts/setup-unity-project.mjs <unity-project-path> [--dry-run] [--replace]",
    "",
    "Copies the plugin's embedded com.studentutu.unitysimplemcp package into Packages/.",
    "A matching package is a no-op. A different existing package requires explicit --replace.",
  ].join("\n");
}

function parseArguments(argv) {
  let projectPath = null;
  let dryRun = false;
  let replace = false;

  for (const argument of argv) {
    if (argument === "--help" || argument === "-h") return { help: true };
    if (argument === "--dry-run") {
      dryRun = true;
      continue;
    }
    if (argument === "--replace") {
      replace = true;
      continue;
    }
    if (argument.startsWith("-")) throw new Error(`Unknown option: ${argument}`);
    if (projectPath !== null) throw new Error("Only one Unity project path may be supplied.");
    projectPath = argument;
  }

  if (projectPath === null) throw new Error("Unity project path is required.");
  return { help: false, projectPath, dryRun, replace };
}

try {
  const options = parseArguments(process.argv.slice(2));
  if (options.help) {
    process.stdout.write(`${usage()}\n`);
  } else {
    const result = await setupUnityProject(options.projectPath, options);
    process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
  }
} catch (error) {
  const payload = {
    error: error instanceof WorkflowError ? error.code : "SETUP_FAILED",
    message: error instanceof Error ? error.message : String(error),
    details: error instanceof WorkflowError ? error.details : {},
  };
  process.stderr.write(`${JSON.stringify(payload, null, 2)}\n`);
  process.stderr.write(`${usage()}\n`);
  process.exitCode = 1;
}
