import { createHash } from "node:crypto";
import { promises as fs } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

export const PACKAGE_NAME = "com.studentutu.unitysimplemcp";
export const SETUP_MARKER_NAME = "SimpleUnityMcpSetup.json";

const scriptsDirectory = path.dirname(fileURLToPath(import.meta.url));
export const pluginRoot = path.resolve(scriptsDirectory, "..");
export const sourcePackagePath = path.join(pluginRoot, PACKAGE_NAME);

export class WorkflowError extends Error {
  constructor(code, message, details = {}) {
    super(message);
    this.name = "WorkflowError";
    this.code = code;
    this.details = details;
  }
}

async function pathType(candidate) {
  try {
    const stats = await fs.lstat(candidate);
    if (stats.isSymbolicLink()) return "symlink";
    if (stats.isDirectory()) return "directory";
    if (stats.isFile()) return "file";
    return "other";
  } catch (error) {
    if (error?.code === "ENOENT") return "missing";
    throw error;
  }
}

function assertDirectChild(parent, candidate, label) {
  const relative = path.relative(parent, candidate);
  if (!relative || relative.startsWith(`..${path.sep}`) || path.isAbsolute(relative)) {
    throw new WorkflowError("UNSAFE_PATH", `${label} is outside the expected directory.`, {
      parent,
      candidate,
    });
  }
}

async function readJson(jsonPath, label) {
  let contents;
  try {
    contents = await fs.readFile(jsonPath, "utf8");
  } catch (error) {
    throw new WorkflowError("MISSING_FILE", `${label} was not found: ${jsonPath}`, {
      path: jsonPath,
      cause: error?.code,
    });
  }

  try {
    return JSON.parse(contents);
  } catch {
    throw new WorkflowError("INVALID_JSON", `${label} is not valid JSON: ${jsonPath}`, {
      path: jsonPath,
    });
  }
}

async function loadSourcePackage() {
  if ((await pathType(sourcePackagePath)) !== "directory") {
    throw new WorkflowError(
      "SOURCE_PACKAGE_MISSING",
      `The plugin does not contain ${PACKAGE_NAME}: ${sourcePackagePath}`,
      { sourcePackagePath },
    );
  }

  const descriptor = await readJson(path.join(sourcePackagePath, "package.json"), "Source package manifest");
  if (descriptor.name !== PACKAGE_NAME) {
    throw new WorkflowError(
      "SOURCE_PACKAGE_INVALID",
      `Expected package name ${PACKAGE_NAME}, found ${String(descriptor.name)}.`,
      { sourcePackagePath },
    );
  }
  if (typeof descriptor.version !== "string" || !descriptor.version.trim()) {
    throw new WorkflowError("SOURCE_PACKAGE_INVALID", "Source package version is missing.", {
      sourcePackagePath,
    });
  }
  if (typeof descriptor.unity !== "string" || !descriptor.unity.trim()) {
    throw new WorkflowError("SOURCE_PACKAGE_INVALID", "Source package Unity version is missing.", {
      sourcePackagePath,
    });
  }

  return descriptor;
}

function parseUnityRelease(value, label) {
  const match = /^(\d+)\.(\d+)(?:\.(\d+))?/.exec(value);
  if (!match) {
    throw new WorkflowError("INVALID_UNITY_VERSION", `${label} is not a recognizable Unity version: ${value}`, {
      value,
    });
  }
  return match.slice(1, 4).map((part) => Number(part ?? 0));
}

function requireSupportedUnity(projectVersion, requiredVersion) {
  const project = parseUnityRelease(projectVersion, "Project Unity version");
  const required = parseUnityRelease(requiredVersion, "Package Unity version");
  for (let index = 0; index < required.length; index += 1) {
    if (project[index] > required[index]) return;
    if (project[index] < required[index]) {
      throw new WorkflowError(
        "UNITY_VERSION_UNSUPPORTED",
        `Unity ${projectVersion} is older than the package minimum ${requiredVersion}.`,
        { projectVersion, requiredVersion },
      );
    }
  }
}

async function resolveUnityProject(projectPath) {
  if (typeof projectPath !== "string" || !projectPath.trim()) {
    throw new WorkflowError("PROJECT_PATH_REQUIRED", "project_path must be a non-empty path.");
  }

  const requestedPath = path.resolve(projectPath);
  let resolvedPath;
  try {
    resolvedPath = await fs.realpath(requestedPath);
  } catch (error) {
    throw new WorkflowError("UNITY_PROJECT_NOT_FOUND", `Unity project was not found: ${requestedPath}`, {
      projectPath: requestedPath,
      cause: error?.code,
    });
  }

  const requiredDirectories = ["Assets", "Packages", "ProjectSettings"];
  for (const directoryName of requiredDirectories) {
    const directoryPath = path.join(resolvedPath, directoryName);
    if ((await pathType(directoryPath)) !== "directory") {
      throw new WorkflowError(
        "INVALID_UNITY_PROJECT",
        `Unity project directory is missing: ${directoryPath}`,
        { projectPath: resolvedPath },
      );
    }
  }

  const versionFile = path.join(resolvedPath, "ProjectSettings", "ProjectVersion.txt");
  let versionContents;
  try {
    versionContents = await fs.readFile(versionFile, "utf8");
  } catch (error) {
    throw new WorkflowError("INVALID_UNITY_PROJECT", `Unity ProjectVersion.txt is missing: ${versionFile}`, {
      projectPath: resolvedPath,
      cause: error?.code,
    });
  }
  const versionMatch = /^m_EditorVersion:\s*(\S+)/m.exec(versionContents);
  if (!versionMatch) {
    throw new WorkflowError("INVALID_UNITY_PROJECT", `m_EditorVersion is missing from ${versionFile}`, {
      projectPath: resolvedPath,
    });
  }

  return {
    projectPath: resolvedPath,
    unityVersion: versionMatch[1].trim(),
    packagesPath: path.join(resolvedPath, "Packages"),
    packagePath: path.join(resolvedPath, "Packages", PACKAGE_NAME),
    markerPath: path.join(resolvedPath, "ProjectSettings", SETUP_MARKER_NAME),
  };
}

async function hashDirectory(directory) {
  const digest = createHash("sha256");

  async function visit(current, relativeDirectory) {
    const entries = await fs.readdir(current, { withFileTypes: true });
    entries.sort((left, right) => left.name.localeCompare(right.name, "en"));

    for (const entry of entries) {
      const absolutePath = path.join(current, entry.name);
      const relativePath = path.posix.join(relativeDirectory, entry.name);
      if (entry.isSymbolicLink()) {
        throw new WorkflowError("PACKAGE_SYMLINK_UNSUPPORTED", `Package contains a symbolic link: ${absolutePath}`, {
          path: absolutePath,
        });
      }
      if (entry.isDirectory()) {
        digest.update(`directory\0${relativePath}\0`);
        await visit(absolutePath, relativePath);
        continue;
      }
      if (!entry.isFile()) {
        throw new WorkflowError("PACKAGE_ENTRY_UNSUPPORTED", `Package contains an unsupported entry: ${absolutePath}`, {
          path: absolutePath,
        });
      }
      digest.update(`file\0${relativePath}\0`);
      digest.update(await fs.readFile(absolutePath));
      digest.update("\0");
    }
  }

  await visit(directory, "");
  return digest.digest("hex");
}

async function readMarker(markerPath) {
  const type = await pathType(markerPath);
  if (type === "missing") return { exists: false, valid: false, value: null };
  if (type !== "file") return { exists: true, valid: false, value: null };

  try {
    const value = JSON.parse(await fs.readFile(markerPath, "utf8"));
    const valid =
      value?.schemaVersion === 1 &&
      value?.pluginName === "unity-simple-mcp" &&
      value?.packageName === PACKAGE_NAME &&
      typeof value?.sourceDigest === "string";
    return { exists: true, valid, value };
  } catch {
    return { exists: true, valid: false, value: null };
  }
}

export async function inspectUnityProject(projectPath) {
  const [project, descriptor] = await Promise.all([
    resolveUnityProject(projectPath),
    loadSourcePackage(),
  ]);
  requireSupportedUnity(project.unityVersion, descriptor.unity);

  assertDirectChild(project.packagesPath, project.packagePath, "Package destination");
  const sourceDigest = await hashDirectory(sourcePackagePath);
  const destinationType = await pathType(project.packagePath);
  let installedDigest = null;
  let state = "not_installed";

  if (destinationType !== "missing") {
    if (destinationType !== "directory") {
      state = "conflict";
    } else {
      try {
        installedDigest = await hashDirectory(project.packagePath);
        state = installedDigest === sourceDigest ? "installed" : "conflict";
      } catch {
        state = "conflict";
      }
    }
  }

  const marker = await readMarker(project.markerPath);
  return {
    state,
    projectPath: project.projectPath,
    unityVersion: project.unityVersion,
    requiredUnityVersion: descriptor.unity,
    packageName: PACKAGE_NAME,
    packageVersion: descriptor.version,
    packagePath: project.packagePath,
    markerPath: project.markerPath,
    sourceDigest,
    installedDigest,
    setupRecorded: marker.valid && marker.value.sourceDigest === sourceDigest,
  };
}

function createMarker(inspection) {
  return {
    schemaVersion: 1,
    pluginName: "unity-simple-mcp",
    packageName: PACKAGE_NAME,
    packageVersion: inspection.packageVersion,
    sourceDigest: inspection.sourceDigest,
    installedAtUtc: new Date().toISOString(),
  };
}

async function restoreMarker(markerPath, previousContents) {
  if (previousContents === null) {
    await fs.rm(markerPath, { force: true });
  } else {
    await fs.writeFile(markerPath, previousContents, "utf8");
  }
}

export async function setupUnityProject(projectPath, { replace = false, dryRun = false } = {}) {
  const inspection = await inspectUnityProject(projectPath);

  if (inspection.state === "installed") {
    if (inspection.setupRecorded || dryRun) {
      return {
        ...inspection,
        action: "already_installed",
        changed: false,
      };
    }

    await fs.writeFile(inspection.markerPath, `${JSON.stringify(createMarker(inspection), null, 2)}\n`, "utf8");
    return {
      ...(await inspectUnityProject(inspection.projectPath)),
      action: "recorded_existing_package",
      changed: true,
    };
  }

  if (inspection.state === "conflict" && !replace) {
    throw new WorkflowError(
      "PACKAGE_CONFLICT",
      `A different ${PACKAGE_NAME} entry already exists at ${inspection.packagePath}.`,
      {
        packagePath: inspection.packagePath,
        sourceDigest: inspection.sourceDigest,
        installedDigest: inspection.installedDigest,
      },
    );
  }

  if (dryRun) {
    return {
      ...inspection,
      action: inspection.state === "conflict" ? "would_replace" : "would_install",
      changed: false,
    };
  }

  const packagesPath = path.dirname(inspection.packagePath);
  const uniqueSuffix = `${process.pid}-${Date.now()}`;
  const stagingPath = path.join(packagesPath, `.${PACKAGE_NAME}.setup-${uniqueSuffix}`);
  const backupPath = path.join(packagesPath, `.${PACKAGE_NAME}.backup-${uniqueSuffix}`);
  assertDirectChild(packagesPath, stagingPath, "Staging path");
  assertDirectChild(packagesPath, backupPath, "Backup path");

  let previousMarkerContents = null;
  try {
    previousMarkerContents = await fs.readFile(inspection.markerPath, "utf8");
  } catch (error) {
    if (error?.code !== "ENOENT") throw error;
  }

  let backupCreated = false;
  let targetInstalled = false;
  try {
    await fs.cp(sourcePackagePath, stagingPath, {
      recursive: true,
      errorOnExist: true,
      force: false,
    });
    const stagedDigest = await hashDirectory(stagingPath);
    if (stagedDigest !== inspection.sourceDigest) {
      throw new WorkflowError("STAGED_COPY_MISMATCH", "The staged package copy failed verification.", {
        stagingPath,
        expectedDigest: inspection.sourceDigest,
        actualDigest: stagedDigest,
      });
    }

    if (inspection.state === "conflict") {
      await fs.rename(inspection.packagePath, backupPath);
      backupCreated = true;
    }

    await fs.rename(stagingPath, inspection.packagePath);
    targetInstalled = true;
    await fs.writeFile(inspection.markerPath, `${JSON.stringify(createMarker(inspection), null, 2)}\n`, "utf8");

    if (backupCreated) {
      await fs.rm(backupPath, { recursive: true, force: true });
      backupCreated = false;
    }
  } catch (error) {
    if (targetInstalled) {
      await fs.rm(inspection.packagePath, { recursive: true, force: true });
      targetInstalled = false;
    }
    if (backupCreated) {
      await fs.rename(backupPath, inspection.packagePath);
      backupCreated = false;
    }
    await restoreMarker(inspection.markerPath, previousMarkerContents);
    throw error;
  } finally {
    await fs.rm(stagingPath, { recursive: true, force: true });
    if (backupCreated) {
      await fs.rename(backupPath, inspection.packagePath);
    }
  }

  const verified = await inspectUnityProject(inspection.projectPath);
  if (verified.state !== "installed" || !verified.setupRecorded) {
    throw new WorkflowError("SETUP_VERIFICATION_FAILED", "Package setup did not pass post-copy verification.", verified);
  }

  return {
    ...verified,
    action: inspection.state === "conflict" ? "replaced" : "installed",
    changed: true,
  };
}
