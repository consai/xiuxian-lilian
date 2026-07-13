import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { compareBaseline, scanRoot, scanSource } from "./validate-architecture-boundaries.mjs";

const source = `
# DataStore FileAccess JsonLoader /root/ change_scene get_node("Bad")
var text = "DataStore FileAccess JsonLoader"
var a = DataStore.savedata
var b = FileAccess.open("user://x")
var c = JsonLoader.load_items()
var d = get_node("/root/DataEvents")
get_tree().change_scene_to_file("res://x.tscn")
var e = get_node("Panel/Label")
var f = $Header/Status
var safe_a = get_node("%Unique")
var safe_b = get_node(node_path)
`;
const findings = scanSource(source, "scripts/ui/test.gd");
for (const rule of [
  "presentation_datastore", "presentation_file_io", "presentation_raw_json",
  "presentation_root_lookup", "presentation_direct_scene_change", "presentation_hardcoded_nodepath",
]) assert(findings.some((finding) => finding.rule === rule), `missing ${rule}`);
assert.equal(findings.filter((finding) => finding.rule === "presentation_datastore").length, 1);

const root = fs.mkdtempSync(path.join(os.tmpdir(), "xiuxian-arch-"));
fs.mkdirSync(path.join(root, "scripts", "core"), { recursive: true });
fs.mkdirSync(path.join(root, "scripts", "legacy"), { recursive: true });
fs.mkdirSync(path.join(root, "scenes", "legacy"), { recursive: true });
fs.writeFileSync(path.join(root, "scripts", "core", "scene_manager.gd"), `const SCENE_PATHS = {\n"x": "res://scenes/legacy/page.tscn",\n}\n`);
fs.writeFileSync(path.join(root, "scenes", "legacy", "page.tscn"), `[gd_scene format=3]\n[ext_resource type="Script" path="res://scripts/legacy/page.gd" id="1"]\n[node name="Page" type="Control"]\nscript = ExtResource("1")\n`);
const routeScript = path.join(root, "scripts", "legacy", "page.gd");
fs.writeFileSync(routeScript, "extends Control\nvar state = DataStore.savedata\n");
const baseline = scanRoot(root);
assert.equal(baseline.length, 1, "route root script must be scanned");
assert(compareBaseline(baseline, baseline).ok);
fs.appendFileSync(routeScript, "var state = DataStore.savedata\n");
assert(!compareBaseline(scanRoot(root), baseline).ok, "increased count must fail");
fs.writeFileSync(routeScript, "extends Control\n");
assert(!compareBaseline(scanRoot(root), baseline).ok, "stale baseline must fail");
fs.rmSync(root, { recursive: true, force: true });
console.log("PASS: presentation architecture validator self-test");
