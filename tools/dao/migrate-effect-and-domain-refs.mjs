#!/usr/bin/env node
/**
 * 补齐大境界迁移遗漏：大道域 foundation→zhuji，void_/tribulation_ 效果 id→lianxu_/dujie_。
 * ponytail: 仅改 exportjson 引用字段，不碰 Excel；重导表后需再跑或把规则写回源表。
 */
import fs from "node:fs";
import path from "node:path";

const ROOT = path.resolve(import.meta.dirname, "../..");
const EXPORT = path.join(ROOT, "data/exportjson");

/** 旧效果 id → 统一效果目录 / effectCatalog 键名。 */
const EFFECT_ID_MAP = {
  void_survival: "lianxu_survival",
  void_herb_growth: "lianxu_herb_growth",
  void_resistance: "lianxu_resistance",
  void_spell_accuracy: "lianxu_spell_accuracy",
  void_target_accuracy: "lianxu_target_accuracy",
  void_mobility: "lianxu_mobility",
  void_route_safety: "lianxu_route_safety",
  void_ship_range: "lianxu_ship_range",
  void_travel_speed: "lianxu_travel_speed",
  tribulation_recovery: "dujie_recovery",
  tribulation_resistance: "dujie_resistance",
  tribulation_forecast: "dujie_forecast",
  tribulation_warning_time: "dujie_warning_time",
  tribulation_control: "dujie_control",
  tribulation_plan_slots: "dujie_plan_slots",
  tribulation_resource_efficiency: "dujie_resource_efficiency",
  tribulation_damage: "dujie_damage",
  tribulation_energy_absorption: "dujie_energy_absorption",
  tribulation_sever: "dujie_sever",
};

const EFFECT_VALUE_KEYS = new Set([
  "effectId",
  "stackGroup",
  "effect1_id",
  "effect2_id",
  "effect3_id",
  "effect1_stack_group",
  "effect2_stack_group",
  "effect3_stack_group",
]);

function mapEffectId(value) {
  if (typeof value !== "string") return value;
  return EFFECT_ID_MAP[value] ?? value;
}

function rewriteNode(node) {
  if (Array.isArray(node)) {
    return node.map(rewriteNode);
  }
  if (node && typeof node === "object") {
    const out = {};
    for (const [key, value] of Object.entries(node)) {
      if (key === "domain" && value === "foundation") {
        out[key] = "zhuji";
        continue;
      }
      if (EFFECT_VALUE_KEYS.has(key)) {
        out[key] = mapEffectId(value);
        continue;
      }
      out[key] = rewriteNode(value);
    }
    return out;
  }
  return node;
}

function migrateJson(relativePath) {
  const filePath = path.join(EXPORT, relativePath);
  const raw = fs.readFileSync(filePath, "utf8");
  const data = JSON.parse(raw);
  const migrated = rewriteNode(data);
  const text = `${JSON.stringify(migrated, null, 2)}\n`;
  if (text !== raw) {
    fs.writeFileSync(filePath, text, "utf8");
    console.log(`updated ${relativePath}`);
  }
}

for (const fileName of [
  "dao_tree_skills.json",
  "xiulian_methods_methods.json",
  "passive.json",
]) {
  migrateJson(fileName);
}
