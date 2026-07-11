import { loadDaoTree, loadEffectCatalog, loadXiulianMethods } from "./json-config-loader.mjs";
import { validateQualityTier } from "./validate-shared.mjs";

const dao = await loadDaoTree();
const config = await loadXiulianMethods();
const sharedCatalog = await loadEffectCatalog();
const errors = [];


const skills = new Map(dao.skills.map((skill) => [skill.id, skill]));
const realmOrder = new Map(dao.realms.map((realm) => [realm.id, realm.order]));
const families = new Map(config.families.map((family) => [family.id, family]));
const methods = new Map(config.methods.map((method) => [method.id, method]));
const sharedEffectIds = new Set(sharedCatalog.effects.map((effect) => effect.id));
const effectsByMethod = new Map(config.methods.map((method) => {
  return [method.id, Array.isArray(method.effects) ? method.effects : []];
}));


if (families.size !== config.families.length) errors.push("存在重复功法谱系 ID");
if (methods.size !== config.methods.length) errors.push("存在重复功法层 ID");
if (config.metadata.familyCount !== config.families.length) errors.push("metadata.familyCount 不一致");
if (config.metadata.methodCount !== config.methods.length) errors.push("metadata.methodCount 不一致");
if (config.metadata.effectTypeCount !== Object.keys(config.effectCatalog ?? {}).length) errors.push("metadata.effectTypeCount 不一致");

for (const family of config.families) {
  if (!family.methodIds.length) errors.push(`${family.id}: 谱系没有功法层`);
  for (const id of family.methodIds) {
    if (!methods.has(id)) errors.push(`${family.id}: 缺少功法层 ${id}`);
  }
}

for (const method of config.methods) {
  const effects = effectsByMethod.get(method.id) ?? [];
  const family = families.get(method.familyId);
  if (!family) errors.push(`${method.id}: 未知谱系 ${method.familyId}`);
  else if (!family.methodIds.includes(method.id)) errors.push(`${method.id}: 未列入谱系 methodIds`);

  if (!realmOrder.has(method.realm)) errors.push(`${method.id}: 未知境界 ${method.realm}`);
  validateQualityTier(method, "功法", errors);

  for (const effect of effects) {
    if (!sharedEffectIds.has(effect.effectId)) errors.push(`${method.id}: 效果 ${effect.effectId} 未登记统一效果目录`);
    const catalogEntry = config.effectCatalog?.[effect.effectId];
    if (!catalogEntry) errors.push(`${method.id}: 效果 ${effect.effectId} 未登记 effectCatalog`);
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
      const previousEffects = effectsByMethod.get(prev.id) ?? [];
      for (const effect of effects) {
        const oldEffect = previousEffects.find((old) => old.stackGroup === effect.stackGroup);
        if (oldEffect && effect.base < oldEffect.base * 0.9) {
          errors.push(`${method.id}: 同类效果 ${effect.stackGroup} 相比前层下降超过 10%`);
        }
      }
    }
  } else if (method.id !== family?.methodIds?.[0] && family?.progressionType !== "side_path") {
    errors.push(`${method.id}: 非首层缺少 predecessorId`);
  }

  if (method.nextMethodId && !methods.has(method.nextMethodId)) errors.push(`${method.id}: 缺少后层 ${method.nextMethodId}`);

  const learningKnowledge = method.learningRequirements?.knowledge ?? [];
  if (learningKnowledge.length > 0) errors.push(method.id + ': 不得配置知识学习门槛');
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
