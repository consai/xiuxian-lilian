import { readYaml } from "./yaml-loader.mjs";
import { loadAbilitiesBundle } from "./load-abilities-bundle.mjs";
import { ordinaryQualitiesFromPolicy, validateQualityTier } from "./validate-shared.mjs";

const dao = await readYaml(new URL("../../data/dao_tree.yaml", import.meta.url));
const config = await loadAbilitiesBundle();
const catalog = await readYaml(new URL("../../data/effect_catalog.yaml", import.meta.url));
const errors = [];
const knowledge = new Map(dao.skills.map((skill) => [skill.id, skill]));
const realmOrder = new Map(dao.realms.map((realm) => [realm.id, realm.order]));
const effectIds = new Set(catalog.effects.map((effect) => effect.id));
const abilityIds = new Set();
const v1Realms = new Set(["qi", "foundation"]);
const ordinaryQualities = ordinaryQualitiesFromPolicy(config.rules.learningKnowledgeGatePolicy);
const maxLearningRequirements = config.rules.learningKnowledgeGatePolicy?.maxKnowledgeRequirements ?? 2;
const maxRequirementLevel = config.rules.learningKnowledgeGatePolicy?.maxRequirementLevel ?? 2;
const runtimeCombatEffects = new Set([
  "damage_spiritual", "damage_sword", "damage_elemental", "damage_physical", "damage_true",
  "shield_flat", "shield_spiritual", "heal_hp", "restore_mana", "armor_pierce",
  "evasion_window", "elemental_vulnerability", "spirit_suppression", "stagger_power",
  "control_duration", "dash_distance",
]);

if ("skillBooks" in config) errors.push("技能配置不得包含外部学习物品数据");
if (config.metadata.abilityCount !== config.abilities.length) errors.push("metadata.abilityCount 不一致");
if (config.abilityTables) {
  for (const typeName of config.rules?.types ?? []) {
    const rel = config.abilityTables[typeName];
    if (!rel) errors.push(`缺少技能分表映射 ${typeName}`);
  }
}
if (effectIds.size !== catalog.effects.length) errors.push("统一效果目录存在重复 ID");
if (catalog.metadata.effectCount !== catalog.effects.length) errors.push("effect_catalog metadata.effectCount 不一致");
if (config.rules.generalPassiveStackPolicy !== "highest") errors.push("通用被动必须同类型只取最高");

for (const ability of config.abilities) {
  if (abilityIds.has(ability.id)) errors.push(`${ability.id}: 重复技能 ID`);
  abilityIds.add(ability.id);
  if ("learnedFromBookId" in ability) errors.push(`${ability.id}: 不得包含外部学习物品引用`);
  if (!config.rules.types.includes(ability.type)) errors.push(`${ability.id}: 未知技能类型 ${ability.type}`);
  validateQualityTier(ability, "技能", errors);
  if (ability.learningRequirements?.realm !== ability.realm) errors.push(`${ability.id}: 学习境界不一致`);
  const learningKnowledge = ability.learningRequirements?.knowledge ?? [];
  if (ordinaryQualities.has(ability.quality) && learningKnowledge.length > 0) {
    errors.push(`${ability.id}: 普通技能不得配置知识学习门槛`);
  }
  if (learningKnowledge.length > maxLearningRequirements) errors.push(`${ability.id}: 除境界外学习门槛最多 ${maxLearningRequirements} 个`);
  for (const gate of learningKnowledge) {
    const source = knowledge.get(gate.skillId);
    if (!source) errors.push(`${ability.id}: 学习门槛引用未知知识 ${gate.skillId}`);
    else if (realmOrder.get(source.realm) > realmOrder.get(ability.realm)) errors.push(`${ability.id}: 学习门槛引用了高于技能境界的知识 ${gate.skillId}`);
    if (gate.level < 1 || gate.level > maxRequirementLevel) errors.push(`${ability.id}: 学习门槛等级必须在 1..${maxRequirementLevel} ${gate.skillId}`);
  }
  for (const effect of ability.effects ?? []) {
    if ("masteryGrowth" in effect) errors.push(`${ability.id}: 禁止使用 masteryGrowth ${effect.effectId}`);
    if ("knowledgeGrowth" in effect) errors.push(`${ability.id}: 禁止使用 knowledgeGrowth ${effect.effectId}`);
    if (!effectIds.has(effect.effectId)) errors.push(`${ability.id}: 效果未登记 ${effect.effectId}`);
    if (!effect.stackGroup || !effect.stackPolicy || !effect.scalingMode) errors.push(`${ability.id}: 效果执行字段不完整 ${effect.effectId}`);
    if (ability.type === "general_passive" && effect.stackPolicy !== "highest") errors.push(`${ability.id}: 通用被动效果必须取最高 ${effect.effectId}`);
    if (effect.operation === "add_percent" && (typeof effect.clampMin !== "number" || typeof effect.clampMax !== "number")) {
      errors.push(`${ability.id}: 百分比效果缺少上下限 ${effect.effectId}`);
    }
    if (effect.base < 0 && effect.scalingMode !== "magnitude") errors.push(`${ability.id}: 负面效果必须按幅度缩放 ${effect.effectId}`);
    if (v1Realms.has(ability.realm) && ability.type === "combat_active") {
      if (!runtimeCombatEffects.has(effect.effectId)) errors.push(`${ability.id}: 首版效果未映射到战斗运行时 ${effect.effectId}`);
    }
  }
  if (ability.type === "general_passive") {
    if (ability.combat !== null) errors.push(`${ability.id}: 通用被动不得配置 combat`);
  } else if (!ability.combat) {
    errors.push(`${ability.id}: 战斗技能缺少 combat`);
  } else {
    if (ability.type === "combat_active" && ability.combat.cooldown <= 0) errors.push(`${ability.id}: 战斗主动缺少冷却`);
    if (v1Realms.has(ability.realm) && ability.type === "combat_active" && !(ability.combat.powerScale >= 0)) errors.push(`${ability.id}: 首版主动技能缺少有效 powerScale`);
    if (ability.type === "combat_upkeep" && !ability.combat.upkeepCostsPerSecond?.length) errors.push(`${ability.id}: 持续技能缺少每秒消耗`);
    if (ability.type === "combat_passive" && ability.combat.activation !== "learned") errors.push(`${ability.id}: 战斗被动必须学会后生效`);
    if (ability.type === "combat_upkeep" && ability.combat.activation !== "toggle") errors.push(`${ability.id}: 持续技能必须配置 toggle 激活`);
  }
}

for (const realm of ["qi", "foundation", "core", "nascent", "transform", "void", "merge", "great", "tribulation"]) {
  const activeCount = config.abilities.filter((ability) => ability.realm === realm && ability.type === "combat_active").length;
  if (activeCount < 1) errors.push(`${realm}: 缺少战斗主动技能`);
}
for (const skill of dao.skills) {
  if (!skill.usageDomains?.length) errors.push(`${skill.id}: 未标注 usageDomains`);
}

if (errors.length) {
  console.error(`技能配置校验失败，共 ${errors.length} 项：`);
  for (const error of errors) console.error(`- ${error}`);
  process.exitCode = 1;
} else {
  console.log(`技能配置校验通过：${config.abilities.length} 个技能，统一效果目录 ${catalog.effects.length} 项。`);
  for (const type of config.rules.types) console.log(`${type}: ${config.abilities.filter((ability) => ability.type === type).length} 个`);
}
