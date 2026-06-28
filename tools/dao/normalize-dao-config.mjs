import { fileURLToPath } from "node:url";
import path from "node:path";
import { readYaml, writeYaml } from "./yaml-loader.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const dataDir = path.join(root, "data");

const REALM_RENAMES = {
  spirit: "transform",
  integration: "merge",
  mahayana: "great",
};

const ATTR_RENAMES = {
  spirit: "sense",
  physique: "body",
};

function renameRealmId(id) {
  return REALM_RENAMES[id] ?? id;
}

function renameAttrId(id) {
  return ATTR_RENAMES[id] ?? id;
}

function walkRealmFields(node, parentKey = "") {
  if (Array.isArray(node)) {
    for (const item of node) walkRealmFields(item, parentKey);
    return;
  }
  if (!node || typeof node !== "object") return;
  for (const [key, value] of Object.entries(node)) {
    if (key === "realm" && typeof value === "string") {
      node[key] = renameRealmId(value);
    } else if (key === "realms" && Array.isArray(value)) {
      for (const row of value) {
        if (row && typeof row === "object" && typeof row.id === "string") {
          row.id = renameRealmId(row.id);
        }
      }
    } else if (typeof value === "object") {
      walkRealmFields(value, key);
    }
  }
}

async function normalizeDaoTree() {
  const file = path.join(dataDir, "dao_tree.yaml");
  const config = await readYaml(file);

  const nextAttrs = {};
  for (const [key, label] of Object.entries(config.attributes ?? {})) {
    nextAttrs[renameAttrId(key)] = label;
  }
  config.attributes = nextAttrs;

  for (const domain of config.domains ?? []) {
    if (domain.primary) domain.primary = renameAttrId(domain.primary);
    if (domain.secondary) domain.secondary = renameAttrId(domain.secondary);
  }

  for (const realm of config.realms ?? []) {
    realm.id = renameRealmId(realm.id);
  }

  for (const skill of config.skills ?? []) {
    if (skill.realm) skill.realm = renameRealmId(skill.realm);
  }

  await writeYaml(file, config);
}

async function normalizeBundle(fileName) {
  const file = path.join(dataDir, fileName);
  const config = await readYaml(file);
  walkRealmFields(config);
  await writeYaml(file, config);
}

async function normalizeAbilities() {
  const indexFile = path.join(dataDir, "jineng.yaml");
  const index = await readYaml(indexFile);
  walkRealmFields(index);
  await writeYaml(indexFile, index);
  const tables = index.abilityTables ?? {};
  for (const rel of Object.values(tables)) {
    const file = path.join(dataDir, String(rel).replace(/^\//, ""));
    const table = await readYaml(file);
    walkRealmFields(table);
    await writeYaml(file, table);
  }
}

await normalizeDaoTree();
await normalizeBundle("xiulian_methods.yaml");
await normalizeAbilities();
console.log("Normalized dao config files.");
