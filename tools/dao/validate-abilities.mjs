import { loadDaoTree, loadEffectCatalog } from "./json-config-loader.mjs";
import { loadAbilitiesBundle } from "./load-abilities-bundle.mjs";
import { loadCombatEffectSchema } from "./normalize-ability-export.mjs";
import { validateQualityTier, realmIdForTier, rejectLegacyRealmField } from "./validate-shared.mjs";
import { validateEffectRows } from "./validate-effect-rows.mjs";

const dao = await loadDaoTree();
const config = await loadAbilitiesBundle();
const catalog = await loadEffectCatalog();
const combatEffectSchema = await loadCombatEffectSchema();
const errors = [];
const effectIds = new Set(catalog.effects.map((effect) => effect.id));
const abilityIds = new Set();
const ABILITY_TYPES = new Set(["combat_active", "combat_passive", "combat_upkeep"]);


const VALID_TARGETS = new Set(["self", "enemy"]);
const VALID_TARGET_ARGS = new Set([
  "lowest_hp", "all", "max_hp", "fastest", "front", "priority", "line", "controlled_entity",
]);
const LEGACY_TARGET_MAP = {
  enemy_lowest_hp: { target: "enemy", targetArg: "lowest_hp" },
  enemy_front: { target: "enemy", targetArg: "front" },
  enemies_all: { target: "enemy", targetArg: "all" },
  enemy_priority: { target: "enemy", targetArg: "priority" },
  area: { target: "enemy", targetArg: "all" },
  line: { target: "enemy", targetArg: "line" },
  position: { target: "self", targetArg: "" },
  controlled_entity: { target: "self", targetArg: "controlled_entity" },
};

function normalizeTargetPair(target, targetArg = "") {
  const rawTarget = String(target ?? "").trim().toLowerCase();
  const rawArg = String(targetArg ?? "").trim().toLowerCase();
  if (LEGACY_TARGET_MAP[rawTarget]) return LEGACY_TARGET_MAP[rawTarget];
  if (VALID_TARGETS.has(rawTarget)) {
    return { target: rawTarget, targetArg: VALID_TARGET_ARGS.has(rawArg) ? rawArg : "" };
  }
  return { target: "enemy", targetArg: "" };
}

function validateTargetPair(abilityId, label, target, targetArg) {
  const pair = normalizeTargetPair(target, targetArg);
  const out = [];
  if (!VALID_TARGETS.has(pair.target)) {
    out.push(`${abilityId}: ${label}.target '${target}' 无效，仅支持 self/enemy`);
  }
  if (pair.targetArg && !VALID_TARGET_ARGS.has(pair.targetArg)) {
    out.push(`${abilityId}: ${label}.targetArg '${targetArg}' 无效`);
  }
  return out;
}

if ("skillBooks" in config) errors.push("技能配置不得包含外部学习物品数据");
if (config.abilityTables) {
  const tableKeys = ["zhandou_active", "passive"];
  for (const tableKey of tableKeys) {
    const rel = config.abilityTables[tableKey];
    if (!rel) errors.push(`缺少技能分表映射 ${tableKey}`);
  }
}
if (effectIds.size !== catalog.effects.length) errors.push("统一效果目录存在重复 ID");
if (catalog.metadata.effectCount !== catalog.effects.length) errors.push("effect_catalog metadata.effectCount 不一致");

for (const ability of config.abilities) {
  if (abilityIds.has(ability.id)) errors.push(`${ability.id}: 重复技能 ID`);
  abilityIds.add(ability.id);
  if ("learnedFromBookId" in ability) errors.push(`${ability.id}: 不得包含外部学习物品引用`);
  if (!ABILITY_TYPES.has(ability.type)) errors.push(`${ability.id}: 未知技能类型 ${ability.type}`);
  validateQualityTier(ability, "技能", errors);
  rejectLegacyRealmField(ability, "技能", errors);
  const abilityRealm = realmIdForTier(ability.tier);
  const learningKnowledge = ability.learningRequirements?.knowledge ?? [];
  if (learningKnowledge.length > 0) errors.push(ability.id + ': 不得配置知识学习门槛');
  for (const effect of ability.effects ?? []) {
    errors.push(...validateEffectRows([effect.sourceCells], combatEffectSchema, ability.id));
    if ("masteryGrowth" in effect) errors.push(`${ability.id}: 禁止使用 masteryGrowth ${effect.effectId}`);
    if ("knowledgeGrowth" in effect) errors.push(`${ability.id}: 禁止使用 knowledgeGrowth ${effect.effectId}`);
    if (!effectIds.has(effect.effectId) && !effect.sourceCells) {
      errors.push(`${ability.id}: 效果未登记 ${effect.effectId}`);
    }
    if (!effect.stackGroup || !effect.stackPolicy || !effect.scalingMode) errors.push(`${ability.id}: 效果执行字段不完整 ${effect.effectId}`);
    if (effect.operation === "add_percent" && (typeof effect.clampMin !== "number" || typeof effect.clampMax !== "number")) {
      errors.push(`${ability.id}: 百分比效果缺少上下限 ${effect.effectId}`);
    }
    if (effect.base < 0 && effect.scalingMode !== "magnitude") errors.push(`${ability.id}: 负面效果必须按幅度缩放 ${effect.effectId}`);
    if (["combat_active", "combat_upkeep"].includes(ability.type) && ("target" in effect || "targetArg" in effect || "target_arg" in effect)) {
      errors.push(`${ability.id}: 效果 ${effect.effectId} 不得配置 target，请使用 combat.target`);
    }
  }
  if (!ability.combat) {
    errors.push(`${ability.id}: 战斗技能缺少 combat`);
  } else {
    if (ability.type === "combat_active" && ability.combat.cooldown <= 0) errors.push(`${ability.id}: 战斗主动缺少冷却`);
    if (["combat_active", "combat_upkeep"].includes(ability.type)) {
      errors.push(...validateTargetPair(ability.id, "combat", ability.combat.target, ability.combat.targetArg));
    }
    if (ability.type === "combat_upkeep" && !ability.combat.upkeepCostsPerSecond?.length) errors.push(`${ability.id}: 持续技能缺少每秒消耗`);
    if (ability.type === "combat_passive" && ability.combat.activation !== "learned") errors.push(`${ability.id}: 战斗被动必须学会后生效`);
    if (ability.type === "combat_upkeep" && ability.combat.activation !== "toggle") errors.push(`${ability.id}: 持续技能必须配置 toggle 激活`);
  }
}

if (errors.length) {
  console.error(`技能配置校验失败，共 ${errors.length} 项：`);
  for (const error of errors) console.error(`- ${error}`);
  process.exitCode = 1;
} else {
  console.log(`技能配置校验通过：${config.abilities.length} 个技能，统一效果目录 ${catalog.effects.length} 项。`);
  for (const type of ABILITY_TYPES) console.log(`${type}: ${config.abilities.filter((ability) => ability.type === type).length} 个`);
}
