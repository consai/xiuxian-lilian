import path from "node:path";
import { fileURLToPath } from "node:url";
import { readJson, isExportRoot, normalizeTableRows } from "./normalize-ability-export.mjs";

export const dataDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../data");
export const exportDir = path.join(dataDir, "exportjson");

export function exportPath(fileName) {
  return path.join(exportDir, fileName);
}

function coerce(value) {
  if (typeof value !== "string") return value;
  let text = value.trim();
  const commentAt = text.indexOf(" #");
  if (commentAt >= 0) {
    const before = text.slice(0, commentAt).trim();
    if (/^-?\d+(\.\d+)?$/.test(before) || /^(true|false)$/i.test(before)) text = before;
  }
  if (/^(true|false)$/i.test(text)) return text.toLowerCase() === "true";
  if (/^-?\d+$/.test(text)) return Number.parseInt(text, 10);
  if (/^-?\d+\.\d+$/.test(text)) return Number.parseFloat(text);
  return text;
}

function payload(row) {
  if (row && Object.hasOwn(row, "value") && row.value !== null) return coerce(row.value);
  return Object.fromEntries(
    Object.entries(row ?? {})
      .filter(([key, value]) => key !== "key" && key !== "value" && value !== null)
      .map(([key, value]) => [key, coerce(value)]),
  );
}

export async function keyedRows(fileName) {
  return readJson(exportPath(fileName));
}

export async function rowArray(fileName) {
  const rows = await keyedRows(fileName);
  return Object.keys(rows)
    .sort((a, b) => (Number.isFinite(+a) && Number.isFinite(+b) ? +a - +b : a.localeCompare(b)))
    .map((key) => rows[key]);
}

export async function settings(fileName) {
  const rows = await keyedRows(fileName);
  return Object.fromEntries(Object.entries(rows).map(([key, row]) => [row.key ?? key, payload(row)]));
}

export async function loadDaoTree() {
  return {
    ...(await settings("dao_tree.json")),
    metadata: await settings("dao_tree_metadata.json"),
    training: await settings("dao_tree_training.json"),
    attributes: await settings("dao_tree_attributes.json"),
    realms: await rowArray("dao_tree_realms.json"),
    domainGroups: await rowArray("dao_tree_domainGroups.json"),
    domains: await rowArray("dao_tree_domains.json"),
    skills: await rowArray("dao_tree_skills.json"),
  };
}

export async function loadEffectCatalog() {
  return {
    ...(await settings("xiaoguo_catalog.json")),
    metadata: await settings("xiaoguo_catalog_metadata.json"),
    effects: await rowArray("xiaoguo_catalog_effects.json"),
    stackPolicies: await settings("xiaoguo_catalog_stackPolicies.json"),
  };
}

export async function loadXiulianMethods() {
  return {
    ...(await settings("xiulian_methods.json")),
    metadata: await settings("xiulian_methods_metadata.json"),
    families: await rowArray("xiulian_methods_families.json"),
    methods: await rowArray("xiulian_methods_methods.json"),
    effectCatalog: await keyedRows("xiulian_methods_effectCatalog.json"),
  };
}

const ABILITY_TABLE_FILES = {
  zhandou_active: "zhandou_active.json",
  passive: "passive.json",
};

export async function loadAbilitiesBundle() {
  const bundle = {
    ...(await settings("jineng.json")),
    metadata: await settings("jineng_metadata.json"),
    rules: await settings("jineng_rules.json"),
    abilityTables: Object.fromEntries(
      Object.entries(ABILITY_TABLE_FILES).map(([key, fileName]) => [key, `exportjson/${fileName}`]),
    ),
  };
  const tables = {};
  const merged = [];
  for (const [tableKey, fileName] of Object.entries(ABILITY_TABLE_FILES)) {
    const table = await keyedRows(fileName);
    const rows = isExportRoot(table) ? normalizeTableRows(tableKey, table) : table.abilities ?? [];
    tables[tableKey] = rows;
    merged.push(...rows);
  }
  bundle.tables = tables;
  bundle.abilities = merged;
  if (bundle.metadata) bundle.metadata.abilityCount = merged.length;
  return bundle;
}
