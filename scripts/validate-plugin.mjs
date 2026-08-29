#!/usr/bin/env node

import { promises as fs } from "node:fs";
import path from "node:path";

const pluginRoot = path.resolve(process.argv[2] ?? process.cwd());
const errors = [];

const manifestKeys = new Set([
  "id",
  "name",
  "version",
  "description",
  "author",
  "homepage",
  "repository",
  "license",
  "keywords",
  "skills",
  "mcpServers",
  "apps",
  "interface",
]);
const interfaceKeys = new Set([
  "displayName",
  "shortDescription",
  "longDescription",
  "developerName",
  "category",
  "capabilities",
  "websiteURL",
  "privacyPolicyURL",
  "termsOfServiceURL",
  "defaultPrompt",
  "default_prompt",
  "brandColor",
  "composerIcon",
  "logo",
  "logoDark",
  "screenshots",
]);

function report(condition, message) {
  if (!condition) errors.push(message);
}

function isObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function isNonEmptyString(value) {
  return typeof value === "string" && value.trim().length > 0;
}

function rejectUnknownKeys(value, allowedKeys, label) {
  if (!isObject(value)) return;
  for (const key of Object.keys(value)) {
    report(allowedKeys.has(key), `${label} contains unsupported field: ${key}`);
  }
}

async function readText(relativePath) {
  const absolutePath = path.join(pluginRoot, relativePath);
  try {
    return await fs.readFile(absolutePath, "utf8");
  } catch (error) {
    errors.push(`Missing or unreadable file: ${relativePath} (${error?.code ?? "read failed"})`);
    return null;
  }
}

async function readJson(relativePath) {
  const contents = await readText(relativePath);
  if (contents === null) return null;
  try {
    return JSON.parse(contents);
  } catch {
    errors.push(`Invalid JSON: ${relativePath}`);
    return null;
  }
}

async function isDirectory(relativePath) {
  try {
    return (await fs.stat(path.join(pluginRoot, relativePath))).isDirectory();
  } catch {
    return false;
  }
}

async function isFile(relativePath) {
  try {
    return (await fs.stat(path.join(pluginRoot, relativePath))).isFile();
  } catch {
    return false;
  }
}

function parseSkillFrontmatter(contents, relativePath) {
  const normalized = contents.replaceAll("\r\n", "\n");
  const lines = normalized.split("\n");
  if (lines[0] !== "---") {
    errors.push(`${relativePath} must start with YAML frontmatter.`);
    return null;
  }
  const closingIndex = lines.indexOf("---", 1);
  if (closingIndex < 0) {
    errors.push(`${relativePath} has unclosed YAML frontmatter.`);
    return null;
  }

  const values = {};
  for (const line of lines.slice(1, closingIndex)) {
    if (!line.trim() || /^\s/.test(line)) continue;
    const match = /^([A-Za-z0-9_-]+):\s*(.*)$/.exec(line);
    if (!match) continue;
    let value = match[2].trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    values[match[1]] = value;
  }
  return values;
}

async function validateManifest() {
  const manifest = await readJson(".codex-plugin/plugin.json");
  if (!isObject(manifest)) return null;

  rejectUnknownKeys(manifest, manifestKeys, "plugin.json");
  report(
    isNonEmptyString(manifest.name) && /^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(manifest.name),
    "plugin.json name must be lowercase hyphen-case.",
  );
  report(
    isNonEmptyString(manifest.version) &&
      /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$/.test(
        manifest.version,
      ),
    "plugin.json version must be semantic versioning.",
  );
  report(isNonEmptyString(manifest.description), "plugin.json description is required.");
  report(isObject(manifest.author), "plugin.json author must be an object.");
  report(isNonEmptyString(manifest.author?.name), "plugin.json author.name is required.");
  report(manifest.skills === "./skills/", "plugin.json skills must point to ./skills/.");
  report(manifest.mcpServers === "./.mcp.json", "plugin.json mcpServers must point to ./.mcp.json.");

  report(isObject(manifest.interface), "plugin.json interface must be an object.");
  if (isObject(manifest.interface)) {
    rejectUnknownKeys(manifest.interface, interfaceKeys, "plugin.json interface");
    for (const field of [
      "displayName",
      "shortDescription",
      "longDescription",
      "developerName",
      "category",
    ]) {
      report(isNonEmptyString(manifest.interface[field]), `plugin.json interface.${field} is required.`);
    }
    report(
      Array.isArray(manifest.interface.capabilities) &&
        manifest.interface.capabilities.every(isNonEmptyString),
      "plugin.json interface.capabilities must be an array of strings.",
    );
    const prompts = manifest.interface.defaultPrompt ?? manifest.interface.default_prompt;
    report(
      isNonEmptyString(prompts) ||
        (Array.isArray(prompts) && prompts.length <= 3 && prompts.every(isNonEmptyString)),
      "plugin.json interface.defaultPrompt must be a string or up to three strings.",
    );
  }

  report(!JSON.stringify(manifest).includes("[TODO:"), "plugin.json contains an unfinished TODO placeholder.");
  return manifest;
}

async function validateMcpManifest() {
  const mcp = await readJson(".mcp.json");
  if (!isObject(mcp)) return;
  rejectUnknownKeys(mcp, new Set(["mcpServers"]), ".mcp.json");
  report(isObject(mcp.mcpServers), ".mcp.json mcpServers must be an object.");
  if (!isObject(mcp.mcpServers)) return;

  const entries = Object.entries(mcp.mcpServers);
  report(entries.length > 0, ".mcp.json must declare at least one MCP server.");
  for (const [name, server] of entries) {
    report(isNonEmptyString(name), ".mcp.json MCP server names must be non-empty.");
    report(isObject(server), `.mcp.json server ${name} must be an object.`);
    if (!isObject(server)) continue;
    report(isNonEmptyString(server.command), `.mcp.json server ${name} command is required.`);
    report(
      Array.isArray(server.args) && server.args.every((argument) => typeof argument === "string"),
      `.mcp.json server ${name} args must be an array of strings.`,
    );
  }
}

async function validateSkills() {
  report(await isDirectory("skills"), "skills/ directory is required.");
  if (!(await isDirectory("skills"))) return;

  const entries = await fs.readdir(path.join(pluginRoot, "skills"), { withFileTypes: true });
  const skillDirectories = entries.filter((entry) => entry.isDirectory() && !entry.name.startsWith("."));
  report(skillDirectories.length > 0, "skills/ must contain at least one skill.");

  for (const skillDirectory of skillDirectories) {
    const relativePath = path.posix.join("skills", skillDirectory.name, "SKILL.md");
    const contents = await readText(relativePath);
    if (contents === null) continue;
    report(!contents.includes("[TODO:"), `${relativePath} contains an unfinished TODO placeholder.`);
    const frontmatter = parseSkillFrontmatter(contents, relativePath);
    if (frontmatter === null) continue;
    report(frontmatter.name === skillDirectory.name, `${relativePath} name must match its directory.`);
    report(isNonEmptyString(frontmatter.description), `${relativePath} description is required.`);
    report(
      frontmatter["disable-model-invocation"] === undefined ||
        frontmatter["disable-model-invocation"] === "false",
      `${relativePath} disable-model-invocation must be false when present.`,
    );

    const agentPath = path.posix.join("skills", skillDirectory.name, "agents", "openai.yaml");
    try {
      const agentContents = await fs.readFile(path.join(pluginRoot, agentPath), "utf8");
      report(!agentContents.includes("[TODO:"), `${agentPath} contains an unfinished TODO placeholder.`);
      report(/^\s*display_name:\s*\S+/m.test(agentContents), `${agentPath} display_name is required.`);
      report(
        /^\s*short_description:\s*\S+/m.test(agentContents),
        `${agentPath} short_description is required.`,
      );
    } catch (error) {
      if (error?.code !== "ENOENT") errors.push(`Unable to read ${agentPath}: ${error?.code ?? "read failed"}`);
    }
  }
}

async function validatePackage(manifest) {
  const packageManifest = await readJson("com.studentutu.unitysimplemcp/package.json");
  if (!isObject(packageManifest)) return;
  report(
    packageManifest.name === "com.studentutu.unitysimplemcp",
    "Embedded Unity package name is incorrect.",
  );
  report(
    manifest === null || packageManifest.version === manifest.version,
    "Plugin and embedded Unity package versions must match.",
  );
}

async function validateScripts() {
  for (const script of [
    "scripts/mcp-server.mjs",
    "scripts/setup-unity-project.mjs",
    "scripts/unity-project.mjs",
    "scripts/validate-plugin.mjs",
  ]) {
    report(await isFile(script), `${script} is required.`);
  }
}

const manifest = await validateManifest();
await validateMcpManifest();
await validateSkills();
await validatePackage(manifest);
await validateScripts();

if (errors.length > 0) {
  process.stderr.write("Plugin validation failed:\n");
  for (const error of errors) process.stderr.write(`- ${error}\n`);
  process.exitCode = 1;
} else {
  process.stdout.write(`Plugin validation passed: ${pluginRoot}\n`);
}
