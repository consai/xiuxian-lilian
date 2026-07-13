import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const BASELINE = path.join(ROOT, "tools", "architecture-boundary-baseline.json");
const ROLE_SUFFIX = /_(?:view|panel|page|dialog|hud|host|presenter)\.gd$/;

export function scanRoot(root) {
  const files = presentationFiles(root);
  const findings = [];
  for (const file of [...files].sort()) {
    const relative = path.relative(root, file).replaceAll("\\", "/");
    findings.push(...scanSource(fs.readFileSync(file, "utf8"), relative));
  }
  return aggregate(findings);
}

export function scanSource(source, relativePath) {
  const findings = [];
  for (const [index, original] of source.split(/\r?\n/).entries()) {
    const line = stripComment(original);
    const code = maskStrings(line);
    const sourceText = normalize(line);
    if (!sourceText) continue;
    add(/\bDataStore\b/.test(code), "presentation_datastore");
    add(/\bFileAccess\b/.test(code), "presentation_file_io");
    add(/\b(?:JsonLoader|JsonReader)\b/.test(code) || /\bJSON\s*\.\s*(?:parse\w*|stringify)\b/.test(code), "presentation_raw_json");
    add(/['"]\/root\//.test(line) || /(?:\b|\.)root\s*\.\s*get_node(?:_or_null)?\s*\(/.test(code), "presentation_root_lookup");
    add(/\bchange_scene(?:_to_file|_to_packed)?\s*\(/.test(code), "presentation_direct_scene_change");
    add(hasHardcodedNodePath(line), "presentation_hardcoded_nodepath");

    function add(condition, rule) {
      if (condition) findings.push({ rule, path: relativePath, source: sourceText, line: index + 1 });
    }
  }
  return findings;
}

export function compareBaseline(actual, expected) {
  const actualText = JSON.stringify(sortEntries(actual));
  const expectedText = JSON.stringify(sortEntries(expected));
  return { ok: actualText === expectedText, actual: sortEntries(actual), expected: sortEntries(expected) };
}

function presentationFiles(root) {
  const files = new Set();
  addTree(path.join(root, "scripts", "ui"));
  addTree(path.join(root, "scenes"));
  for (const file of walk(path.join(root, "scripts"))) {
    if (ROLE_SUFFIX.test(file.replaceAll("\\", "/"))) files.add(file);
  }
  const manager = path.join(root, "scripts", "core", "scene_manager.gd");
  if (fs.existsSync(manager)) {
    const text = fs.readFileSync(manager, "utf8");
    const start = text.indexOf("const SCENE_PATHS");
    const end = start >= 0 ? text.indexOf("}\n", start) : -1;
    const table = start >= 0 ? text.slice(start, end >= 0 ? end + 1 : text.length) : "";
    for (const match of table.matchAll(/"res:\/\/([^"\r\n]+\.tscn)"/g)) {
      const script = rootScript(path.join(root, match[1]), root);
      if (script) files.add(script);
    }
  }
  return files;

  function addTree(directory) {
    for (const file of walk(directory)) if (file.endsWith(".gd")) files.add(file);
  }
}

function rootScript(scenePath, root) {
  if (!fs.existsSync(scenePath)) return null;
  const text = fs.readFileSync(scenePath, "utf8");
  const scripts = new Map();
  for (const line of text.split(/\r?\n/)) {
    if (!line.startsWith("[ext_resource") || !line.includes('type="Script"')) continue;
    const resourcePath = line.match(/path="res:\/\/([^"]+)"/)?.[1];
    const id = line.match(/id="([^"]+)"/)?.[1];
    if (resourcePath && id) scripts.set(id, resourcePath);
  }
  const nodes = [...text.matchAll(/^\[node [^\]]+\]$/gm)];
  const rootNode = nodes.find((match) => !match[0].includes("parent="));
  if (!rootNode) return null;
  const next = nodes.find((match) => match.index > rootNode.index);
  const section = text.slice(rootNode.index, next?.index ?? text.length);
  const id = section.match(/script\s*=\s*ExtResource\("([^"]+)"\)/)?.[1];
  const relative = id ? scripts.get(id) : null;
  return relative ? path.join(root, relative) : null;
}

function hasHardcodedNodePath(line) {
  for (const match of line.matchAll(/\bget_node(?:_or_null)?\s*\(\s*(["'])(.*?)\1/g)) {
    if (!match[2].startsWith("%")) return true;
  }
  return /(^|[^\w])\$(?:[A-Za-z_][\w]*(?:\/[\w]+)*|"[^"]+"|'[^']+')/.test(line);
}

function stripComment(line) {
  let quote = "";
  let escaped = false;
  for (let i = 0; i < line.length; i += 1) {
    const char = line[i];
    if (escaped) { escaped = false; continue; }
    if (char === "\\" && quote) { escaped = true; continue; }
    if (quote) { if (char === quote) quote = ""; continue; }
    if (char === '"' || char === "'") { quote = char; continue; }
    if (char === "#") return line.slice(0, i);
  }
  return line;
}

function maskStrings(line) {
  let quote = "";
  let escaped = false;
  return [...line].map((char) => {
    if (escaped) { escaped = false; return " "; }
    if (quote) {
      if (char === "\\") escaped = true;
      else if (char === quote) quote = "";
      return " ";
    }
    if (char === '"' || char === "'") { quote = char; return " "; }
    return char;
  }).join("");
}

function normalize(line) {
  return line.trim().replace(/\s+/g, " ");
}

function aggregate(findings) {
  const entries = new Map();
  for (const finding of findings) {
    const key = `${finding.rule}\0${finding.path}\0${finding.source}`;
    const entry = entries.get(key) ?? { rule: finding.rule, path: finding.path, source: finding.source, count: 0, lines: [] };
    entry.count += 1;
    entry.lines.push(finding.line);
    entries.set(key, entry);
  }
  return sortEntries([...entries.values()]);
}

function sortEntries(entries) {
  return entries.map(({ rule, path: filePath, source, count }) => ({ rule, path: filePath, source, count }))
    .sort((a, b) => `${a.rule}\0${a.path}\0${a.source}`.localeCompare(`${b.rule}\0${b.path}\0${b.source}`));
}

function walk(directory) {
  if (!fs.existsSync(directory)) return [];
  const out = [];
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const full = path.join(directory, entry.name);
    if (entry.isDirectory()) out.push(...walk(full));
    else out.push(full);
  }
  return out;
}

function main() {
  const actual = scanRoot(ROOT);
  if (process.argv.includes("--print-baseline")) {
    process.stdout.write(`${JSON.stringify(actual, null, 2)}\n`);
    return;
  }
  const expected = JSON.parse(fs.readFileSync(BASELINE, "utf8"));
  const result = compareBaseline(actual, expected);
  if (!result.ok) {
    console.error("Presentation architecture baseline changed.");
    console.error("Expected:\n" + JSON.stringify(result.expected, null, 2));
    console.error("Actual:\n" + JSON.stringify(result.actual, null, 2));
    process.exit(1);
  }
  console.log(`PASS: presentation architecture baseline (${actual.length} exact findings)`);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main();
