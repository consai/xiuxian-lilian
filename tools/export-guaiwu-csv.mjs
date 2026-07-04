import { readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const rootDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const jsonPath = path.join(rootDir, "data/exportjson/guaiwu.json");
const outPath = path.join(rootDir, "data/guaiwu.csv");

const CN_HEADERS = [
  "id",
  "名称",
  "角色",
  "头像",
  "最大生命",
  "最大法力",
  "护盾值",
  "物理攻击",
  "法术攻击",
  "物理防御",
  "法术防御",
  "出手速度",
];

const EN_FIELDS = [
  "id",
  "name",
  "obj",
  "headicon",
  "hp_max",
  "mp_max",
  "shield",
  "physical_atk",
  "magic_atk",
  "physical_def",
  "magic_def",
  "spd",
];

function csvCell(value) {
  const text = value == null ? "" : String(value);
  if (/[",\r\n]/.test(text)) {
    return `"${text.replace(/"/g, '""')}"`;
  }
  return text;
}

function rowToCsv(cells) {
  return cells.map(csvCell).join(",");
}

const data = JSON.parse(await readFile(jsonPath, "utf8"));
const rows = Object.entries(data).map(([id, monster]) => ({
  id,
  name: monster.name ?? "",
  obj: monster.obj ?? "",
  headicon: monster.headicon ?? "",
  hp_max: monster.hp_max ?? "",
  mp_max: monster.mp_max ?? "",
  shield: monster.shield ?? "",
  physical_atk: monster.physical_atk ?? "",
  magic_atk: monster.magic_atk ?? "",
  physical_def: monster.physical_def ?? "",
  magic_def: monster.magic_def ?? "",
  spd: monster.spd ?? "",
}));

const lines = [
  rowToCsv(CN_HEADERS),
  rowToCsv(EN_FIELDS),
  ...rows.map((row) => rowToCsv(EN_FIELDS.map((field) => row[field]))),
];

// UTF-8 BOM：Excel 打开时正确显示中文表头
await writeFile(outPath, `\uFEFF${lines.join("\r\n")}\r\n`, "utf8");
console.log(`Wrote ${rows.length} monsters to ${outPath}`);
