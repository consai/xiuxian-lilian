import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { realmIdForTier, tierForRealmId } from "./validate-shared.mjs";

const dataDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../data");
const SCHEMA_PATH = path.join(dataDir, "exportjson", "战斗effects效果介绍.json");

/** 战斗属性键 → attrschange 技能配置 effectId；导出表 positional 参数须直接填左侧键名。 */
const FIGHT_ATTR_TO_EFFECT_ID = {
  spd: "cast_speed",
  physical_atk: "physical_attack",
  magic_atk: "magic_attack",
  physical_def: "physical_defense",
  magic_def: "magic_defense",
  hp_max: "max_hp",
  mp_max: "max_mana",
  hp_regen: "hp_regen",
  mp_regen: "mana_regen",
  damage_bonus: "damage_bonus",
  control_resist: "control_resist",
};

const FIGHT_ATTR_KEYS = new Set(Object.keys(FIGHT_ATTR_TO_EFFECT_ID));

function exportFightAttrKey(cells, index) {
  const fightAttr = cellString(cells, index, "").toLowerCase();
  if (!fightAttr) return "";
  if (FIGHT_ATTR_KEYS.has(fightAttr)) return fightAttr;
  return "";
}

let schemaCache = null;

export async function loadCombatEffectSchema() {
  if (schemaCache) return schemaCache;
  schemaCache = JSON.parse(await readFile(SCHEMA_PATH, "utf8"));
  return schemaCache;
}

export function isNullSentinel(value) {
  if (value == null) return true;
  const s = String(value).trim().toLowerCase();
  return s === "" || s === "null" || s === "~";
}

export function splitCsvTags(raw) {
  if (Array.isArray(raw)) {
    const out = [];
    for (const item of raw) {
      const token = String(item ?? "").trim();
      if (!token || token === "[]") continue;
      for (const part of token.split(",")) {
        const p = part.trim();
        if (p) out.push(p);
      }
    }
    return out;
  }
  const text = String(raw ?? "").trim();
  if (!text || text === "[]") return [];
  return text.split(",").map((p) => p.trim()).filter(Boolean);
}

function cellString(cells, index, fallback = "") {
  if (index >= cells.length) return fallback;
  if (isNullSentinel(cells[index])) return fallback;
  return String(cells[index]).trim();
}

function cellFloat(cells, index, fallback = 0) {
  const s = cellString(cells, index, "");
  if (!s) return fallback;
  const n = Number(s);
  return Number.isFinite(n) ? n : fallback;
}

function defaultConfigEffect(effectId, base, operation) {
  return {
    effectId,
    base,
    operation,
    stackGroup: effectId,
    stackPolicy: "ability_instance",
    scalingMode: "positive",
  };
}

export function parsePositionalConfig(cells) {
  if (!Array.isArray(cells) || cells.length === 0) return null;
  const effectId = String(cells[0]).trim().toLowerCase();
  switch (effectId) {
    case "damage":
    case "shield":
    case "heal_hp":
    case "restore_mana":
      return defaultConfigEffect(effectId, cellFloat(cells, 1, 0), "add_flat");
    case "attrschange": {
      const fightAttr = exportFightAttrKey(cells, 1);
      if (!fightAttr) return null;
      const mapped = FIGHT_ATTR_TO_EFFECT_ID[fightAttr] ?? fightAttr;
      const flatVal = cellFloat(cells, 2, 0);
      const pctVal = cellFloat(cells, 3, 0);
      const operation = pctVal !== 0 && flatVal === 0 ? "add_percent" : "add_flat";
      const base = operation === "add_percent" ? pctVal / 1000 : flatVal;
      const out = defaultConfigEffect(mapped, base, operation);
      if (operation === "add_percent") {
        out.clampMin = 0;
        out.clampMax = 2;
      }
      return out;
    }
    case "buff": {
      const buffId = cellString(cells, 1, "");
      if (!buffId) return null;
      return {
        effectId: "buff",
        base: 0,
        operation: "add_flat",
        stackGroup: `buff:${buffId}`,
        stackPolicy: "ability_instance",
        scalingMode: "positive",
        buffId,
      };
    }
    case "damage_def":
    case "damage_add": {
      const flat = cellFloat(cells, 1, 0);
      const mapped = effectId === "damage_def" ? "physical_def" : "damage_bonus";
      return defaultConfigEffect(mapped, flat, "add_flat");
    }
    default:
      return null;
  }
}

export function parsePositionalConfigEffects(effects) {
  if (!Array.isArray(effects)) return [];
  const out = [];
  for (const row of effects) {
    if (!Array.isArray(row)) continue;
    const cfg = parsePositionalConfig(row);
    if (cfg) out.push(cfg);
  }
  return out;
}

export function normalizeZhandouActiveRow(raw) {
  const abilityId = String(raw.id ?? "").trim();
  if (!abilityId) return null;
  let tier = Number(raw.tier ?? 1) || 1;
  if (!raw.tier && raw.req_realm) tier = tierForRealmId(raw.req_realm);
  const costs = [];
  const costResource = String(raw.cost_resource ?? "").trim().toLowerCase();
  const costValue = Number(raw.cost_value ?? 0) || 0;
  if (costResource && costValue > 0) costs.push({ resource: costResource, value: costValue });
  let targetArg = String(raw.targetarg ?? raw.target_arg ?? "").trim();
  if (isNullSentinel(targetArg)) targetArg = "";
  const combat = {
    target: String(raw.target ?? "enemy").trim().toLowerCase(),
    castTime: Number(raw.cast_time ?? raw.castTime ?? 0.8) || 0,
    cooldown: Number(raw.cooldown ?? 0) || 0,
    costs,
    upkeepCostsPerSecond: [],
    activation: String(raw.activation ?? "cast").trim(),
  };
  if (targetArg) combat.targetArg = targetArg;
  const out = {
    id: abilityId,
    name: String(raw.name ?? abilityId),
    type: String(raw.type ?? "combat_active").trim() || "combat_active",
    tier,
    quality: Number(raw.quality ?? 1) || 1,
    description: String(raw.description ?? raw.desc ?? ""),
    tags: splitCsvTags(raw.tags ?? []),
    combat,
    effects: parsePositionalConfigEffects(raw.effects ?? []),
    learningRequirements: { knowledge: [] },
    trigger: {},
    upgrade_options: [],
    evolution_conditions: [],
  };
  const vfxPreset = raw.vfx_preset ?? raw.vfxPreset;
  if (!isNullSentinel(vfxPreset)) out.vfx_preset = String(vfxPreset).trim();
  return out;
}

export function normalizeZhandouPassiveRow(raw) {
  const abilityId = String(raw.id ?? "").trim();
  if (!abilityId) return null;
  const effects = parsePositionalConfigEffects(raw.effects ?? []);
  for (const effect of effects) {
    if (effect.effectId === "heal_hp") effect.effectId = "hp_regen";
  }
  const runtype = String(raw.runtype ?? "").trim().toLowerCase();
  return {
    id: abilityId,
    name: String(raw.name ?? abilityId),
    type: "combat_passive",
    tier: Number(raw.tier ?? 1) || 1,
    quality: Number(raw.quality ?? 1) || 1,
    description: String(raw.desc ?? raw.description ?? ""),
    tags: splitCsvTags(raw.tag ?? raw.tags ?? []),
    combat: {
      target: "self",
      castTime: 0,
      cooldown: Number(raw.cd ?? 0) || 0,
      costs: [],
      upkeepCostsPerSecond: [],
      activation: "learned",
    },
    effects,
    learningRequirements: { knowledge: [] },
    trigger: runtype ? { runtype } : {},
    upgrade_options: [],
    evolution_conditions: [],
  };
}

export function isExportRoot(table) {
  if (!table || typeof table !== "object") return false;
  if (Array.isArray(table.abilities) && table.abilities.length > 0) return false;
  return true;
}

export function normalizeTableRows(tableKey, root) {
  const normalizers = {
    zhandou_active: normalizeZhandouActiveRow,
    passive: normalizeZhandouPassiveRow,
  };
  const normalize = normalizers[tableKey];
  if (!normalize) return [];
  const out = [];
  for (const key of Object.keys(root).sort()) {
    const row = root[key];
    if (!row || typeof row !== "object") continue;
    const normalized = normalize({ ...row, id: row.id ?? key });
    if (normalized) out.push(normalized);
  }
  return out;
}

export async function readJson(filePath) {
  return JSON.parse(await readFile(filePath, "utf8"));
}

export { realmIdForTier };
