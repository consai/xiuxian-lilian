import { readYaml } from "./yaml-loader.mjs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const dataDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../data");
const indexPath = path.join(dataDir, "jineng.yaml");

const DEFAULT_TABLE_TYPES = [
  "combat_active",
  "combat_passive",
  "combat_upkeep",
  "general_passive",
];

const ABILITY_TABLE_FILES = {
  combat_active: "jineng/zhandou_active.yaml",
  combat_passive: "jineng/zhandou_passive.yaml",
  combat_upkeep: "jineng/zhandou_upkeep.yaml",
  general_passive: "jineng/tongyong_passive.yaml",
};

function resolveTablePath(relativePath, typeName) {
  const rel = (relativePath || ABILITY_TABLE_FILES[typeName] || `jineng/${typeName}.yaml`).replace(/^\//, "");
  return path.join(dataDir, rel);
}

/** 读取技能索引与各分表，合并为与旧版单文件相同的 bundle 结构。 */
export async function loadAbilitiesBundle(indexFile = indexPath) {
  const bundle = await readYaml(indexFile);
  const tables = bundle.abilityTables ?? {};
  const order = bundle.rules?.types?.length ? bundle.rules.types : DEFAULT_TABLE_TYPES;
  const merged = [];

  if (Object.keys(tables).length > 0) {
    for (const typeName of order) {
      const tablePath = resolveTablePath(tables[typeName], typeName);
      const table = await readYaml(tablePath);
      for (const ability of table.abilities ?? []) {
        merged.push(ability);
      }
    }
  } else {
    merged.push(...(bundle.abilities ?? []));
  }

  bundle.abilities = merged;
  if (bundle.metadata) {
    bundle.metadata.abilityCount = merged.length;
  }
  return bundle;
}
