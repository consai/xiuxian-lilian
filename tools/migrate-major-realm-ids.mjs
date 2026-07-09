#!/usr/bin/env node
/**
 * 一次性迁移：大境界 id 英文 → 拼音。
 * ponytail: 仅处理列出的配置/脚本路径，不全局替换 zhuji 等领域 id。
 */
import fs from "node:fs";
import path from "node:path";

const ROOT = path.resolve(import.meta.dirname, "..");

const REALM_MAP = [
  ["tribulation", "dujie"],
  ["zhuji", "zhuji"],
  ["yuanying", "yuanying"],
  ["huashen", "huashen"],
  ["heti", "heti"],
  ["dacheng", "dacheng"],
  ["jindan", "jindan"],
  ["lianxu", "lianxu"],
  ["lianqi", "lianqi"],
];

const TRANSITION_MAP = [
  ["qi_to_foundation", "lianqi_to_zhuji"],
  ["foundation_to_core", "zhuji_to_jindan"],
  ["core_to_nascent", "jindan_to_yuanying"],
];

const VALUE_KEYS = new Set([
  "realm",
  "major_realm",
  "req_realm",
  "from_major",
  "to_major",
  "anchor_realm",
  "id",
  "key",
]);

const PREFIX_KEY_FILES = new Set([
  "jingjie_balance_standard_play.json",
  "jingjie_balance_benchmark_ene.json",
  "jingjie_balance_acceptance.json",
  "shijian_rules.json",
]);

const WHOLE_KEY_FILES = new Set([
  "dao_tree_realms.json",
  "jingjie_balance_major_realms.json",
  "tupo_rules_major_breakthrough.json",
]);

function mapRealm(value) {
  const v = String(value);
  for (const [from, to] of REALM_MAP) {
    if (v === from) return to;
  }
  return v;
}

function mapCompoundKey(key) {
  let out = key;
  for (const [from, to] of TRANSITION_MAP) {
    if (out === from) return to;
  }
  for (const [from, to] of REALM_MAP) {
    if (out === from) return to;
    if (out.startsWith(`${from}_`)) {
      out = `${to}_${out.slice(from.length + 1)}`;
      break;
    }
  }
  return out;
}

function mapStringLiteral(text) {
  let out = text;
  for (const [from, to] of TRANSITION_MAP) {
    out = out.replaceAll(`"${from}"`, `"${to}"`);
  }
  for (const [from, to] of REALM_MAP) {
    out = out.replaceAll(`"${from}"`, `"${to}"`);
  }
  return out;
}

function rewriteJsonObject(obj, fileName, parentKey = "") {
  if (Array.isArray(obj)) {
    return obj.map((item) => rewriteJsonObject(item, fileName, parentKey));
  }
  if (obj && typeof obj === "object") {
    const out = {};
    for (const [key, value] of Object.entries(obj)) {
      let newKey = key;
      if (WHOLE_KEY_FILES.has(fileName) || PREFIX_KEY_FILES.has(fileName)) {
        newKey = mapCompoundKey(key);
      }
      if (key === "tier_major_realm" && value && typeof value === "object") {
        const mapped = {};
        for (const [tier, realmId] of Object.entries(value)) {
          mapped[tier] = mapRealm(realmId);
        }
        out[newKey] = mapped;
        continue;
      }
      if (VALUE_KEYS.has(key) && typeof value === "string") {
        if (key === "id" && parentKey === "major_realm_starts") {
          out[newKey] = mapRealm(value);
          continue;
        }
        if (["realm", "major_realm", "req_realm", "from_major", "to_major", "anchor_realm"].includes(key)) {
          out[newKey] = mapRealm(value);
          continue;
        }
        if (WHOLE_KEY_FILES.has(fileName) && key === "id") {
          out[newKey] = mapRealm(value);
          continue;
        }
        if (PREFIX_KEY_FILES.has(fileName) && key === "key") {
          out[newKey] = mapCompoundKey(value);
          continue;
        }
      }
      if (key === "major_realm_starts" && value && typeof value === "object") {
        const mapped = {};
        for (const [entryKey, entryValue] of Object.entries(value)) {
          mapped[mapCompoundKey(entryKey)] = rewriteJsonObject(entryValue, fileName, key);
        }
        out[newKey] = mapped;
        continue;
      }
      out[newKey] = rewriteJsonObject(value, fileName, key);
    }
    return out;
  }
  return obj;
}

function migrateJson(filePath) {
  const fileName = path.basename(filePath);
  const raw = fs.readFileSync(filePath, "utf8");
  const data = JSON.parse(raw);
  const migrated = rewriteJsonObject(data, fileName);
  const text = `${JSON.stringify(migrated, null, 2)}\n`;
  if (text !== raw) {
    fs.writeFileSync(filePath, text, "utf8");
    console.log(`updated ${path.relative(ROOT, filePath)}`);
  }
}

function migrateGd(filePath) {
  const raw = fs.readFileSync(filePath, "utf8");
  let out = mapStringLiteral(raw);
  out = out.replace(
    /const MAJOR_REALM_BY_PREFIX: Dictionary = \{[\s\S]*?\}/m,
    "const MAJOR_REALM_BY_PREFIX: Dictionary = {}",
  );
  out = out.replace(
    /var major_realm: String = str\(MAJOR_REALM_BY_PREFIX\.get\(prefix, ""\)\)/,
    "var major_realm: String = EnumMajorRealm.normalize_id(prefix)",
  );
  if (out !== raw) {
    fs.writeFileSync(filePath, out, "utf8");
    console.log(`updated ${path.relative(ROOT, filePath)}`);
  }
}

const jsonFiles = [
  "data/exportjson/dao_tree_realms.json",
  "data/exportjson/passive.json",
  "data/exportjson/zhandou_active.json",
  "data/exportjson/xiulian_methods_methods.json",
  "data/exportjson/dao_tree_skills.json",
  "data/exportjson/yunxing_params/jingjie_balance_major_realms.json",
  "data/exportjson/yunxing_params/jingjie_balance_cultivation_p.json",
  "data/exportjson/yunxing_params/jingjie_balance_standard_play.json",
  "data/exportjson/yunxing_params/jingjie_balance_benchmark_ene.json",
  "data/exportjson/yunxing_params/jingjie_balance_acceptance.json",
  "data/exportjson/yunxing_params/jingjie_balance_player_level_.json",
  "data/exportjson/yunxing_params/tupo_rules_major_breakthrough.json",
  "data/exportjson/yunxing_params/shijian_rules.json",
].map((p) => path.join(ROOT, p));

for (const filePath of jsonFiles) {
  migrateJson(filePath);
}
