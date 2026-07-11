import path from "node:path";
import { dataDir } from "./json-config-loader.mjs";
import { loadCombatEffectSchema, readJson } from "./normalize-ability-export.mjs";
import { validateEffectRows } from "./validate-effect-rows.mjs";

const items = await readJson(path.join(dataDir, "exportjson", "item_items.json"));
const schema = await loadCombatEffectSchema();
const errors = [];

for (const [itemId, item] of Object.entries(items)) {
  errors.push(...validateEffectRows(item.use_effect ?? [], schema, `${itemId}.use_effect`));
  errors.push(...validateEffectRows(item.fight_effect ?? [], schema, `${itemId}.fight_effect`));
}

if (errors.length) {
  console.error(`道具效果校验失败，共 ${errors.length} 项：`);
  for (const error of errors) console.error(`- ${error}`);
  process.exitCode = 1;
} else {
  console.log(`道具效果校验通过：${Object.keys(items).length} 个道具。`);
}
