import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const daoDir = path.join(root, "tools", "dao");
const validators = [
  "test-validate-effect-rows.mjs",
  "validate-dao-tree.mjs",
  "validate-xiulian-methods.mjs",
  "validate-abilities.mjs",
  "validate-items.mjs",
];

let failed = false;
for (const name of validators) {
  console.log(`\n==> ${name}`);
  const result = spawnSync(process.execPath, [path.join(daoDir, name)], {
    cwd: root,
    stdio: "inherit",
  });
  if (result.status !== 0) {
    failed = true;
  }
}

if (failed) {
  console.error("\n配置校验失败。");
  process.exit(1);
}

console.log(`\nPASS: ${validators.length - 1} config validators`);

failed = run(process.execPath, [path.join(root, "tools", "validate-project-files.mjs")]) || failed;
failed = run(process.execPath, [path.join(root, "tools", "test-validate-architecture-boundaries.mjs")]) || failed;
failed = run(process.execPath, [path.join(root, "tools", "validate-architecture-boundaries.mjs")]) || failed;

const godot = process.env.GODOT_BIN ?? (process.platform === "win32"
  ? "C:\\Godot_v4.6.2-stable_win64_console.exe"
  : "godot4");
const godotEnv = {
  ...process.env,
  APPDATA: path.join(root, ".godot_test_appdata_cultivation"),
  LOCALAPPDATA: path.join(root, ".godot_test_local_cultivation"),
};
for (const name of fs.readdirSync(path.join(root, "tests")).filter((name) => /^test_.*\.gd$/.test(name)).sort()) {
  failed = runGodot(name, ["--script", `res://tests/${name}`]) || failed;
}
failed = runGodot("route smoke", ["--script", "res://tests/run_route_smoke.gd"]) || failed;
failed = runGodot("headless startup", ["--quit-after", "5"]) || failed;
failed = run("git", ["diff", "--check"]) || failed;

if (failed) process.exit(1);
console.log("\nPASS: production validation gate");

function run(command, args) {
  const result = spawnSync(command, args, { cwd: root, stdio: "inherit" });
  return result.status !== 0;
}

function runGodot(label, args) {
  console.log(`\n==> ${label}`);
  const result = spawnSync(godot, ["--headless", "--path", root, ...args], {
    cwd: root,
    encoding: "utf8",
    env: godotEnv,
    timeout: 60_000,
  });
  const output = `${result.stdout ?? ""}${result.stderr ?? ""}`;
  process.stdout.write(output);
  if (result.error) console.error(result.error.message);
  return result.status !== 0 || result.error != null || /(?:^|\r?\n)(?:SCRIPT ERROR|ERROR):/m.test(output);
}
