import { spawnSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const daoDir = path.join(root, "tools", "dao");
const validators = [
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

console.log(`\nPASS: ${validators.length} config validators`);
process.exit(0);
