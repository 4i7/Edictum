import { readFileSync, readdirSync, statSync } from "fs";
import path from "path";

const root = process.cwd();
const checks = [];
const failures = [];

function read(relPath) {
  return readFileSync(path.join(root, relPath), "utf8");
}

function addCheck(name, file, fn) {
  checks.push({ name, file, fn });
}

function pass(name, file) {
  console.log(`PASS ${name} (${file})`);
}

function fail(name, file, reason) {
  failures.push({ name, file, reason });
  console.log(`FAIL ${name} (${file}): ${reason}`);
}

function frontMatter(content) {
  const normalized = content.replace(/^\uFEFF/, "").replace(/\r\n/g, "\n");
  if (!normalized.startsWith("---\n")) return null;
  const end = normalized.indexOf("\n---", 4);
  if (end < 0) return null;
  return normalized.slice(4, end).trimEnd();
}

function parseFlatFrontMatter(content) {
  const fm = frontMatter(content);
  if (fm === null) return null;

  const data = {};
  let currentKey = null;
  let blockMode = null;
  for (const line of fm.split("\n")) {
    const match = line.match(/^([A-Za-z0-9_-]+):(?:\s*(.*))?$/);
    if (match) {
      currentKey = match[1];
      const rawValue = match[2] ?? "";
      blockMode = rawValue === ">-" || rawValue === "|" ? rawValue : null;
      data[currentKey] = blockMode ? "" : rawValue.trim();
      continue;
    }
    if (blockMode && currentKey && /^\s+/.test(line)) {
      const part = line.trim();
      data[currentKey] = data[currentKey] ? `${data[currentKey]} ${part}` : part;
    }
  }
  return data;
}

function requireKeys(data, keys) {
  const missing = keys.filter((key) => !data?.[key]?.trim());
  return missing.length ? `missing or empty front matter keys: ${missing.join(", ")}` : null;
}

function countOccurrences(content, needle) {
  let count = 0;
  let index = 0;
  while (true) {
    const found = content.indexOf(needle, index);
    if (found < 0) return count;
    count += 1;
    index = found + needle.length;
  }
}

function walkFiles(dir) {
  const out = [];
  for (const entry of readdirSync(path.join(root, dir))) {
    const child = path.join(dir, entry);
    const full = path.join(root, child);
    if (statSync(full).isDirectory()) out.push(...walkFiles(child));
    else out.push(child.replaceAll("\\", "/"));
  }
  return out;
}

addCheck("skill front matter", "home-claude/skills/edictum/SKILL.md", () => {
  const data = parseFlatFrontMatter(read("home-claude/skills/edictum/SKILL.md"));
  return data ? requireKeys(data, ["name", "description"]) : "front matter block not found";
});

for (const agent of ["spec-builder", "acceptance-checker", "pipeline-runner"]) {
  const file = `home-claude/agents/${agent}.md`;
  addCheck("agent front matter", file, () => {
    const data = parseFlatFrontMatter(read(file));
    if (!data) return "front matter block not found";
    const missing = requireKeys(data, ["name", "description", "tools", "model"]);
    if (missing) return missing;
    return data.model.trim() === "sonnet" ? null : `model must be sonnet, got ${data.model}`;
  });
}

addCheck("delegate command front matter", "home-claude/commands/delegate.md", () => {
  return frontMatter(read("home-claude/commands/delegate.md")) === null
    ? "front matter block not found"
    : null;
});

addCheck("no docs/tasks residue", "home-claude/", () => {
  const hits = [];
  for (const file of walkFiles("home-claude")) {
    if (read(file).includes("docs/tasks")) hits.push(file);
  }
  return hits.length ? `found docs/tasks in ${hits.join(", ")}` : null;
});

addCheck("marker integrity", "home-claude/CLAUDE-policy-snippet.md, install.ps1, install.sh", () => {
  const start = "<!-- EDICTUM:START";
  const end = "<!-- EDICTUM:END -->";
  const snippet = read("home-claude/CLAUDE-policy-snippet.md");
  if (countOccurrences(snippet, start) !== 1) return `${start} must appear exactly once in snippet`;
  if (countOccurrences(snippet, end) !== 1) return `${end} must appear exactly once in snippet`;
  for (const file of ["install.ps1", "install.sh"]) {
    const content = read(file);
    if (!content.includes(start)) return `${file} does not reference ${start}`;
    if (!content.includes(end)) return `${file} does not reference ${end}`;
  }
  return null;
});

addCheck("companion path sentinel", "home-claude/agents/pipeline-runner.md, home-claude/skills/edictum/SKILL.md", () => {
  for (const file of ["home-claude/agents/pipeline-runner.md", "home-claude/skills/edictum/SKILL.md"]) {
    const content = read(file);
    if (!content.includes("$CLAUDE_PLUGIN_ROOT")) return `${file} is missing $CLAUDE_PLUGIN_ROOT`;
    if (!content.includes("codex-companion.mjs")) return `${file} is missing codex-companion.mjs`;
  }
  return null;
});

addCheck(".gitignore delegation artifacts", ".gitignore", () => {
  const content = read(".gitignore");
  for (const needle of [".claude/tasks/", ".claude/tasks/results/"]) {
    if (!content.includes(needle)) return `.gitignore missing ${needle}`;
  }
  return null;
});

for (const check of checks) {
  try {
    const reason = check.fn();
    if (reason) fail(check.name, check.file, reason);
    else pass(check.name, check.file);
  } catch (error) {
    fail(check.name, check.file, error instanceof Error ? error.message : String(error));
  }
}

if (failures.length) {
  console.error(`\n${failures.length} validation check(s) failed.`);
  process.exit(1);
}

console.log(`\nAll ${checks.length} validation checks passed.`);
