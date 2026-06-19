import { readYaml } from "./yaml-loader.mjs";

const dao = await readYaml(new URL("../../data/dao_tree.yaml", import.meta.url));
const config = await readYaml(new URL("../../data/cultivation_methods.yaml", import.meta.url));
const sharedCatalog = await readYaml(new URL("../../data/effect_catalog.yaml", import.meta.url));
const errors = [];

const skills = new Map(dao.skills.map((skill) => [skill.id, skill]));
const realmOrder = new Map(dao.realms.map((realm) => [realm.id, realm.order]));
const families = new Map(config.families.map((family) => [family.id, family]));
const methods = new Map(config.methods.map((method) => [method.id, method]));
const sharedEffectIds = new Set(sharedCatalog.effects.map((effect) => effect.id));

if (families.size !== config.families.length) errors.push("存在重复功法谱系 ID");
if (methods.size !== config.methods.length) errors.push("存在重复功法层 ID");
if (config.metadata.familyCount !== config.families.length) errors.push("metadata.familyCount 不一致");
if (config.metadata.methodCount !== config.methods.length) errors.push("metadata.methodCount 不一致");
if (config.metadata.effectTypeCount !== Object.keys(config.effectCatalog ?? {}).length) errors.push("metadata.effectTypeCount 不一致");
if (!config.rules.layerInheritance?.recursive) errors.push("功法层必须启用递归继承");
if (config.rules.layerInheritance?.knowledge?.maximumCapLevel !== dao.training.maxLevel) errors.push("继承知识最高等级与大道树不一致");
if (config.rules.blockedKnowledgeXpPolicy !== "discard") errors.push("知识经验不得暂存");
if (config.rules.layerInheritance?.effects?.inheritPreviousEffects !== false) errors.push("高层功法不得自动继承旧层效果");
if (config.rules.layerInheritance?.knowledge?.inheritedGrowthWeightMultiplierPerTierDistance <= 0
  || config.rules.layerInheritance?.knowledge?.inheritedGrowthWeightMultiplierPerTierDistance >= 1) {
  errors.push("继承知识权重倍率必须在 0 与 1 之间");
}
const nonCultivatable = new Set(config.rules.knowledgeExperience?.nonCultivatableSkillIds ?? []);

for (const family of config.families) {
  if (!family.methodIds.length) errors.push(`${family.id}: 谱系没有功法层`);
  for (const id of family.methodIds) {
    if (!methods.has(id)) errors.push(`${family.id}: 缺少功法层 ${id}`);
  }
}

for (const method of config.methods) {
  const family = families.get(method.familyId);
  if (!family) errors.push(`${method.id}: 未知谱系 ${method.familyId}`);
  else if (!family.methodIds.includes(method.id)) errors.push(`${method.id}: 未列入谱系 methodIds`);

  if (!realmOrder.has(method.realm)) errors.push(`${method.id}: 未知境界 ${method.realm}`);
  if (!method.knowledge.length) errors.push(`${method.id}: 未配置知识`);
  if (method.effects.length < 2) errors.push(`${method.id}: 功法效果不足 2 项`);

  const localSkills = new Set();
  let weightTotal = 0;
  for (const knowledge of method.knowledge) {
    const skill = skills.get(knowledge.skillId);
    if (!skill) errors.push(`${method.id}: 未知知识 ${knowledge.skillId}`);
    else if (realmOrder.get(skill.realm) > realmOrder.get(method.realm)) {
      errors.push(`${method.id}: 不能在${method.realm}教授高阶知识 ${knowledge.skillId}(${skill.realm})`);
    }
    if (localSkills.has(knowledge.skillId)) errors.push(`${method.id}: 重复知识 ${knowledge.skillId}`);
    localSkills.add(knowledge.skillId);
    if (knowledge.capLevel < 1 || knowledge.capLevel > (skill?.maxLevel ?? 5)) errors.push(`${method.id}: ${knowledge.skillId} capLevel 非法`);
    if (knowledge.growthWeight <= 0) errors.push(`${method.id}: ${knowledge.skillId} growthWeight 必须大于 0`);
    if (knowledge.masteryWeight <= 0) errors.push(`${method.id}: ${knowledge.skillId} masteryWeight 必须大于 0`);
    if (nonCultivatable.has(knowledge.skillId) && knowledge.gainFromCultivation !== false) {
      errors.push(`${method.id}: 实践型知识 ${knowledge.skillId} 不得通过修炼增长`);
    }
    weightTotal += knowledge.growthWeight;
  }
  if (weightTotal <= 0) errors.push(`${method.id}: 知识权重总和非法`);

  for (const effect of method.effects) {
    if (!sharedEffectIds.has(effect.effectId)) errors.push(`${method.id}: 效果 ${effect.effectId} 未登记统一效果目录`);
    const catalogEntry = config.effectCatalog?.[effect.effectId];
    if (!catalogEntry) errors.push(`${method.id}: 效果 ${effect.effectId} 未登记 effectCatalog`);
    for (const skillId of effect.knowledgeScales ?? []) {
      if (!localSkills.has(skillId)) errors.push(`${method.id}: 效果 ${effect.effectId} 引用了未包含知识 ${skillId}`);
    }
    if (!effect.operation || !effect.stackGroup || !effect.stackPolicy || !effect.activation) {
      errors.push(`${method.id}: 效果 ${effect.effectId} 缺少运算或叠加规则`);
    }
    if (effect.operation === "add_percent" && typeof effect.cap !== "number") {
      errors.push(`${method.id}: 百分比效果 ${effect.effectId} 缺少 cap`);
    }
    const attributes = effect.attributes;
    if (!attributes?.category || !attributes?.target || !attributes?.polarity
      || !attributes?.valueType || !Number.isInteger(attributes?.displayPriority)) {
      errors.push(`${method.id}: 效果 ${effect.effectId} 缺少展示属性`);
    }
    if (catalogEntry && attributes?.target !== catalogEntry.defaultTarget) {
      errors.push(`${method.id}: 效果 ${effect.effectId} 的目标类型与 effectCatalog 不一致`);
    }
  }

  if (method.predecessorId) {
    const prev = methods.get(method.predecessorId);
    if (!prev) errors.push(`${method.id}: 缺少前层 ${method.predecessorId}`);
    else {
      if (prev.familyId !== method.familyId) errors.push(`${method.id}: 前层不属于同一谱系`);
      if (prev.tier !== method.tier - 1) errors.push(`${method.id}: 前层 tier 不连续`);
      if (prev.nextMethodId !== method.id) errors.push(`${method.id}: 前层 nextMethodId 不匹配`);
      if (realmOrder.get(prev.realm) >= realmOrder.get(method.realm)) errors.push(`${method.id}: 前层境界未低于当前层`);
      const newKnowledge = method.knowledge.filter((knowledge) => !prev.knowledge.some((old) => old.skillId === knowledge.skillId));
      if (!newKnowledge.length) errors.push(`${method.id}: 升级层没有加入新知识`);
      for (const effect of method.effects) {
        const oldEffect = prev.effects.find((old) => old.stackGroup === effect.stackGroup);
        if (oldEffect && effect.base < oldEffect.base * 0.9) {
          errors.push(`${method.id}: 同类效果 ${effect.stackGroup} 相比前层下降超过 10%`);
        }
      }
    }
  } else if (method.tier !== 1) {
    errors.push(`${method.id}: 非首层缺少 predecessorId`);
  }

  if (method.nextMethodId && !methods.has(method.nextMethodId)) errors.push(`${method.id}: 缺少后层 ${method.nextMethodId}`);

  if (method.learningRequirements?.realm !== method.realm) errors.push(`${method.id}: 学习境界门槛与功法境界不一致`);
  for (const req of method.learningRequirements?.knowledge ?? []) {
    const skill = skills.get(req.skillId);
    if (!skill) errors.push(`${method.id}: 学习要求引用未知知识 ${req.skillId}`);
    else if (req.level < 1 || req.level > 2) errors.push(`${method.id}: 基础学习门槛过高 ${req.skillId}:${req.level}`);
  }
}

if (errors.length) {
  console.error(`功法配置校验失败，共 ${errors.length} 项：`);
  for (const error of errors) console.error(`- ${error}`);
  process.exitCode = 1;
} else {
  console.log(`功法配置校验通过：${config.families.length} 个谱系，${config.methods.length} 个独立功法层。`);
  for (const realm of dao.realms) {
    console.log(`${realm.name}: ${config.methods.filter((method) => method.realm === realm.id).length} 部`);
  }
}
