import { readFile, writeFile } from "node:fs/promises";

function significantLines(text) {
  return text
    .split(/\r?\n/)
    .filter((line) => line.trim() !== "" && !line.trimStart().startsWith("#"))
    .map((line) => ({ indent: line.match(/^ */)[0].length, text: line.trimStart() }));
}

function splitKeyValue(text) {
  let quote = "";
  let escaped = false;
  for (let i = 0; i < text.length; i += 1) {
    const ch = text[i];
    if (escaped) {
      escaped = false;
      continue;
    }
    if (ch === "\\") {
      escaped = true;
      continue;
    }
    if (quote) {
      if (ch === quote) quote = "";
      continue;
    }
    if (ch === "\"" || ch === "'") {
      quote = ch;
      continue;
    }
    if (ch === ":") return [text.slice(0, i), text.slice(i + 1)];
  }
  return null;
}

function scalar(raw) {
  const text = raw.trim();
  if (text === "") return "";
  try {
    return JSON.parse(text);
  } catch {
    if (text === "null" || text === "~") return null;
    if (text === "true") return true;
    if (text === "false") return false;
    if (/^-?\d+$/.test(text)) return Number.parseInt(text, 10);
    if (/^-?\d+\.\d+(e[+-]?\d+)?$/i.test(text)) return Number.parseFloat(text);
    return text.replace(/^['"]|['"]$/g, "");
  }
}

function parseBlock(lines, cursor, indent) {
  if (cursor.i >= lines.length) return {};
  return lines[cursor.i].text.startsWith("-") ? parseArray(lines, cursor, indent) : parseObject(lines, cursor, indent);
}

function nextIndent(lines, cursor, fallback) {
  return cursor.i < lines.length ? lines[cursor.i].indent : fallback + 2;
}

function assignPair(out, keyRaw, valueRaw, lines, cursor, indent) {
  const key = String(scalar(keyRaw));
  const value = valueRaw.trim();
  out[key] = value === "" ? parseBlock(lines, cursor, nextIndent(lines, cursor, indent)) : scalar(value);
}

function parseObject(lines, cursor, indent) {
  const out = {};
  while (cursor.i < lines.length) {
    const line = lines[cursor.i];
    if (line.indent < indent || line.indent !== indent || line.text.startsWith("-")) break;
    const pair = splitKeyValue(line.text);
    cursor.i += 1;
    if (pair) assignPair(out, pair[0], pair[1], lines, cursor, indent);
  }
  return out;
}

function parseArray(lines, cursor, indent) {
  const out = [];
  while (cursor.i < lines.length) {
    const line = lines[cursor.i];
    if (line.indent < indent || line.indent !== indent || !line.text.startsWith("-")) break;
    const rest = line.text.slice(1).trim();
    cursor.i += 1;
    if (rest === "") {
      out.push(parseBlock(lines, cursor, nextIndent(lines, cursor, indent)));
      continue;
    }
    const pair = splitKeyValue(rest);
    if (!pair) {
      out.push(scalar(rest));
      continue;
    }
    const row = {};
    assignPair(row, pair[0], pair[1], lines, cursor, indent);
    if (cursor.i < lines.length && lines[cursor.i].indent > indent && !lines[cursor.i].text.startsWith("-")) {
      Object.assign(row, parseObject(lines, cursor, lines[cursor.i].indent));
    }
    out.push(row);
  }
  return out;
}

export async function readYaml(url) {
  const text = await readFile(url, "utf8");
  try {
    return JSON.parse(text);
  } catch {
    const lines = significantLines(text);
    return lines.length === 0 ? {} : parseBlock(lines, { i: 0 }, lines[0].indent);
  }
}

function keyText(key) {
  const s = String(key);
  return /^[A-Za-z_][A-Za-z0-9_]*$/.test(s) || /^[0-9]+$/.test(s) || /^[\u4e00-\u9fff_A-Za-z0-9]+$/.test(s)
    ? s
    : JSON.stringify(s);
}

function scalarText(value) {
  if (value === null) return "null";
  if (typeof value === "string") return JSON.stringify(value);
  if (typeof value === "number" || typeof value === "boolean") return String(value);
  return JSON.stringify(value);
}

export function toYaml(value, indent = 0) {
  const pad = " ".repeat(indent);
  if (Array.isArray(value)) {
    if (value.length === 0) return "[]";
    return value.map((item) => {
      if (item && typeof item === "object" && !Array.isArray(item)) {
        const entries = Object.entries(item);
        if (entries.length === 0) return `${pad}- {}`;
        const lines = [];
        const [firstKey, firstValue] = entries[0];
        if (firstValue && typeof firstValue === "object") {
          lines.push(`${pad}- ${keyText(firstKey)}:`);
          lines.push(toYaml(firstValue, indent + 4));
        } else {
          lines.push(`${pad}- ${keyText(firstKey)}: ${scalarText(firstValue)}`);
        }
        for (const [k, v] of entries.slice(1)) {
          if (v && typeof v === "object") {
            const nested = toYaml(v, indent + 4);
            lines.push(nested === "[]" || nested === "{}" ? `${" ".repeat(indent + 2)}${keyText(k)}: ${nested}` : `${" ".repeat(indent + 2)}${keyText(k)}:\n${nested}`);
          } else {
            lines.push(`${" ".repeat(indent + 2)}${keyText(k)}: ${scalarText(v)}`);
          }
        }
        return lines.join("\n");
      }
      return Array.isArray(item) ? `${pad}-\n${toYaml(item, indent + 2)}` : `${pad}- ${scalarText(item)}`;
    }).join("\n");
  }
  if (value && typeof value === "object") {
    const entries = Object.entries(value);
    if (entries.length === 0) return "{}";
    return entries.map(([k, v]) => {
      if (v && typeof v === "object") {
        const nested = toYaml(v, indent + 2);
        return nested === "[]" || nested === "{}" ? `${pad}${keyText(k)}: ${nested}` : `${pad}${keyText(k)}:\n${nested}`;
      }
      return `${pad}${keyText(k)}: ${scalarText(v)}`;
    }).join("\n");
  }
  return `${pad}${scalarText(value)}`;
}

export async function writeYaml(url, data) {
  await writeFile(url, `${toYaml(data)}\n`, "utf8");
}
