import { loadDaoTree } from "./json-config-loader.mjs";

const config = await loadDaoTree();
const { domains, realms, skills } = config;

const errors = [];
const skillById = new Map(skills.map((skill) => [skill.id, skill]));
const realmOrder = new Map(realms.map((realm) => [realm.id, realm.order]));
const domainIds = new Set(domains.map((domain) => domain.id));
const realmIds = new Set(realms.map((realm) => realm.id));
const attributeIds = new Set(Object.keys(config.attributes));
const levelMultipliers = config.training.base?.levelMultipliers ?? [];

if (config.schemaVersion !== 1) errors.push(`不支持的 schemaVersion: ${config.schemaVersion}`);
if (config.metadata?.skillCount !== skills.length) errors.push("metadata.skillCount 与实际节点数量不一致");
if (domainIds.size !== domains.length) errors.push("存在重复大道 ID");
if (realmIds.size !== realms.length) errors.push("存在重复境界 ID");
if (skillById.size !== skills.length) errors.push("存在重复技能 ID");

for (const domain of domains) {
  if (!attributeIds.has(domain.primary)) errors.push(`${domain.id}: 未知主属性 ${domain.primary}`);
  if (!attributeIds.has(domain.secondary)) errors.push(`${domain.id}: 未知次属性 ${domain.secondary}`);
}

for (const skill of skills) {
  if (!domainIds.has(skill.domain)) errors.push(`${skill.id}: 未知大道 ${skill.domain}`);
  if (!realmIds.has(skill.realm)) errors.push(`${skill.id}: 未知境界 ${skill.realm}`);
  if (skill.rank < 1 || skill.maxLevel < 1 || skill.maxLevel > levelMultipliers.length) errors.push(`${skill.id}: 训练倍率或等级上限非法`);
  if (skill.prereqs.length > 2) errors.push(`${skill.id}: 除境界外前置最多 2 个`);
  for (const req of skill.prereqs) {
    const parent = skillById.get(req.id);
    if (!parent) errors.push(`${skill.id}: 缺少前置 ${req.id}`);
    else if (realmOrder.get(parent.realm) > realmOrder.get(skill.realm)) errors.push(`${skill.id}: 前置境界倒挂 ${req.id}`);
    if (req.level < 1 || req.level > 5) errors.push(`${skill.id}: 前置等级非法 ${req.id} ${req.level}`);
  }
}

const visiting = new Set();
const visited = new Set();
function visit(id) {
  if (visiting.has(id)) return errors.push(`${id}: 存在循环前置`);
  if (visited.has(id)) return;
  visiting.add(id);
  for (const req of skillById.get(id)?.prereqs ?? []) visit(req.id);
  visiting.delete(id);
  visited.add(id);
}
for (const skill of skills) visit(skill.id);


if (errors.length) {
  console.error(`大道树校验失败，共 ${errors.length} 项：`);
  for (const error of errors) console.error(`- ${error}`);
  process.exitCode = 1;
} else {
  console.log(`大道树校验通过：${domains.length} 条大道，${realms.length} 个境界，${skills.length} 门知识，无断链或循环前置。`);
  for (const realm of realms) {
    console.log(`${realm.name}: ${skills.filter((skill) => skill.realm === realm.id).length} 门`);
  }
}
