#!/usr/bin/env node

import { inspectUnityProject, setupUnityProject, WorkflowError } from "./unity-project.mjs";

const serverInfo = {
  name: "unity-simple-mcp",
  version: "0.5.0",
};

const tools = [
  {
    name: "inspect_unity_project",
    description:
      "Validate a local Unity project and report whether the bundled com.studentutu.unitysimplemcp package is absent, installed identically, or in conflict. This tool is read-only.",
    inputSchema: {
      type: "object",
      properties: {
        project_path: {
          type: "string",
          description: "Absolute or working-directory-relative path to the Unity project root.",
        },
      },
      required: ["project_path"],
      additionalProperties: false,
    },
  },
  {
    name: "setup_unity_project",
    description:
      "Perform the one-time, idempotent copy of the bundled com.studentutu.unitysimplemcp package into a validated local Unity project. Refuses to overwrite a different existing package.",
    inputSchema: {
      type: "object",
      properties: {
        project_path: {
          type: "string",
          description: "Absolute or working-directory-relative path to the Unity project root.",
        },
        dry_run: {
          type: "boolean",
          description: "Validate and report the planned action without writing files.",
          default: false,
        },
      },
      required: ["project_path"],
      additionalProperties: false,
    },
  },
];

function writeMessage(message) {
  process.stdout.write(`${JSON.stringify(message)}\n`);
}

function resultContent(value) {
  return {
    content: [{ type: "text", text: JSON.stringify(value, null, 2) }],
    structuredContent: value,
  };
}

function errorContent(error) {
  const value = {
    error: error instanceof WorkflowError ? error.code : "TOOL_FAILED",
    message: error instanceof Error ? error.message : String(error),
    details: error instanceof WorkflowError ? error.details : {},
  };
  return {
    isError: true,
    content: [{ type: "text", text: JSON.stringify(value, null, 2) }],
    structuredContent: value,
  };
}

async function callTool(name, args) {
  if (name === "inspect_unity_project") {
    return resultContent(await inspectUnityProject(args?.project_path));
  }
  if (name === "setup_unity_project") {
    return resultContent(
      await setupUnityProject(args?.project_path, {
        dryRun: args?.dry_run === true,
        replace: false,
      }),
    );
  }
  throw new WorkflowError("UNKNOWN_TOOL", `Unknown tool: ${String(name)}`);
}

async function handleRequest(message) {
  const { id, method, params } = message;
  if (method === "initialize") {
    return {
      jsonrpc: "2.0",
      id,
      result: {
        protocolVersion: params?.protocolVersion ?? "2024-11-05",
        capabilities: { tools: { listChanged: false } },
        serverInfo,
        instructions:
          "Inspect before setup. Setup is a one-time project mutation and must not replace a conflicting package.",
      },
    };
  }
  if (method === "ping") return { jsonrpc: "2.0", id, result: {} };
  if (method === "tools/list") return { jsonrpc: "2.0", id, result: { tools } };
  if (method === "tools/call") {
    try {
      return {
        jsonrpc: "2.0",
        id,
        result: await callTool(params?.name, params?.arguments ?? {}),
      };
    } catch (error) {
      return { jsonrpc: "2.0", id, result: errorContent(error) };
    }
  }
  return {
    jsonrpc: "2.0",
    id,
    error: { code: -32601, message: `Method not found: ${String(method)}` },
  };
}

let inputBuffer = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => {
  inputBuffer += chunk;
  const lines = inputBuffer.split(/\r?\n/);
  inputBuffer = lines.pop() ?? "";

  for (const line of lines) {
    if (!line.trim()) continue;
    void (async () => {
      try {
        const message = JSON.parse(line);
        if (message.id === undefined) return;
        writeMessage(await handleRequest(message));
      } catch (error) {
        writeMessage({
          jsonrpc: "2.0",
          id: null,
          error: { code: -32700, message: error instanceof Error ? error.message : "Parse error" },
        });
      }
    })();
  }
});

process.stdin.on("end", () => {
  process.exitCode = 0;
});
