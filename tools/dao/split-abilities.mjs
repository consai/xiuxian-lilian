import { mkdir } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { readYaml, writeYaml } from "./yaml-loader.mjs";

const dataDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../data");
const indexPath = path.join(dataDir, "jineng.yaml");
const tablesDir = path.join(dataDir, "jineng");

const ABILITY_TABLE_FILES = {
  combat_active: "zhandou_active.yaml",
  combat_passive: "zhandou_passive.yaml",
  combat_upkeep: "zhandou_upkeep.yaml",
  general_passive: "tongyong_passive.yaml",
};

const source = await readYaml(indexPath);
const types = source.rules?.types ?? [
  "combat_active",
  "combat_passive",
  "combat_upkeep",
  "general_passive",
];
const allAbilities = source.abilities ?? [];

await mkdir(tablesDir, { recursive: true });

const abilityTables = {};
for (const typeName of types) {
  const rows = allAbilities.filter((ability) => ability.type === typeName);
  const tableFile = ABILITY_TABLE_FILES[typeName] ?? `${typeName}.yaml`;
  const tablePath = path.join(tablesDir, tableFile);
  abilityTables[typeName] = `jineng/${tableFile}`;
  await writeYaml(tablePath, {
    configId: `abilities.${typeName}`,
    type: typeName,
    metadata: {
      name: `技能·${typeName}`,
      abilityCount: rows.length,
    },
    abilities: rows,
  });
  console.log(`${typeName}: ${rows.length}`);
}

const index = { ...source };
delete index.abilities;
index.abilityTables = abilityTables;
index.metadata = {
  ...(index.metadata ?? {}),
  abilityCount: allAbilities.length,
};
await writeYaml(indexPath, index);
console.log(`Wrote index + ${types.length} tables (${allAbilities.length} abilities total).`);
