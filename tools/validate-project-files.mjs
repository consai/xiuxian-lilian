import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const skipped = new Set([".git", ".godot", "node_modules"]);
const textExtensions = new Set([".gd", ".tscn", ".tres", ".godot"]);
const resourceExtensions = new Set([
  ".cfg", ".csv", ".gd", ".gdshader", ".import", ".jpeg", ".jpg", ".json",
  ".mp3", ".ogg", ".otf", ".png", ".shader", ".svg", ".translation", ".tres",
  ".tscn", ".ttf", ".wav", ".webp",
]);
const files = walk(root);
const relativeFiles = new Set(files.map((file) => path.relative(root, file).replaceAll("\\", "/")));
const errors = [];

for (const relative of relativeFiles) {
  if (relative.endsWith(".gd.uid") && !relativeFiles.has(relative.slice(0, -4))) {
    errors.push(`orphan UID: ${relative}`);
  }
  if (!textExtensions.has(path.extname(relative))) continue;
  const text = fs.readFileSync(path.join(root, relative), "utf8");
  for (const match of text.matchAll(/res:\/\/[^"'\s)\],}]+/g)) {
    const resource = match[0].replace(/[;,]+$/, "");
    const resourcePath = resource.slice("res://".length);
    if (!resourceExtensions.has(path.extname(resourcePath).toLowerCase())) continue;
    if (!relativeFiles.has(resourcePath)) errors.push(`${relative}: missing ${resource}`);
  }
}

if (errors.length > 0) {
  for (const error of errors) console.error(error);
  process.exit(1);
}
console.log(`PASS: ${relativeFiles.size} project files, no orphan UID or missing resource path`);

function walk(directory) {
  const out = [];
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    if (entry.isDirectory() && (skipped.has(entry.name) || entry.name.startsWith(".godot_test_"))) continue;
    const fullPath = path.join(directory, entry.name);
    if (entry.isDirectory()) out.push(...walk(fullPath));
    else out.push(fullPath);
  }
  return out;
}
