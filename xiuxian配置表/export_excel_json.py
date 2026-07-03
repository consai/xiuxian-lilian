#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import posixpath
import re
import sys
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET

MAIN_NS = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
REL_NS = "http://schemas.openxmlformats.org/package/2006/relationships"
DOC_REL_NS = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
NS = {"m": MAIN_NS}

LIST_SEP = re.compile(r"\s*:\s*")
ARRAY2D_ROW_SEP = re.compile(r"\s*\|\s*")
ARRAY2D_COL_SEP = re.compile(r"\s*[:：]\s*")
KEY_MARKER = re.compile(r"^k(\d*)$", re.I)


def shared_strings(zf: zipfile.ZipFile) -> list[str]:
    if "xl/sharedStrings.xml" not in zf.namelist():
        return []
    root = ET.fromstring(zf.read("xl/sharedStrings.xml"))
    return ["".join(t.text or "" for t in si.findall(".//m:t", NS)) for si in root.findall("m:si", NS)]


def workbook_sheets(zf: zipfile.ZipFile) -> list[tuple[str, str]]:
    rels = ET.fromstring(zf.read("xl/_rels/workbook.xml.rels"))
    targets = {rel.attrib["Id"]: rel.attrib["Target"] for rel in rels.findall(f"{{{REL_NS}}}Relationship")}
    root = ET.fromstring(zf.read("xl/workbook.xml"))
    out: list[tuple[str, str]] = []
    for sheet in root.findall("m:sheets/m:sheet", NS):
        rid = sheet.attrib.get(f"{{{DOC_REL_NS}}}id", "")
        target = targets.get(rid, "").replace("\\", "/")
        if not target:
            continue
        path = target.lstrip("/") if target.startswith("/") else posixpath.normpath(posixpath.join("xl", target))
        out.append((sheet.attrib["name"], path))
    return out


def cell_col(cell_ref: str) -> int:
    n = 0
    for ch in cell_ref:
        if not ch.isalpha():
            break
        n = n * 26 + ord(ch.upper()) - 64
    return n


def cell_value(cell: ET.Element, shared: list[str]):
    cell_type = cell.attrib.get("t")
    if cell_type == "inlineStr":
        return "".join(t.text or "" for t in cell.findall(".//m:t", NS))
    value = cell.findtext("m:v", namespaces=NS)
    if value is None:
        return None
    if cell_type == "s":
        idx = int(value)
        return shared[idx] if 0 <= idx < len(shared) else ""
    if cell_type == "b":
        return value == "1"
    return value


def sheet_rows(zf: zipfile.ZipFile, sheet_path: str, shared: list[str]) -> list[list[object]]:
    root = ET.fromstring(zf.read(sheet_path))
    rows: list[list[object]] = []
    for row in root.findall("m:sheetData/m:row", NS):
        row_index = int(row.attrib.get("r", len(rows) + 1))
        while len(rows) < row_index:
            rows.append([])
        values: list[object] = []
        for cell in row.findall("m:c", NS):
            idx = cell_col(cell.attrib.get("r", "")) or len(values) + 1
            while len(values) < idx:
                values.append(None)
            values[idx - 1] = cell_value(cell, shared)
        rows[row_index - 1] = values
    return rows


def clean(value) -> str | None:
    if value is None:
        return None
    if isinstance(value, bool):
        return "true" if value else "false"
    text = str(value).strip()
    return text or None


def split_list(value) -> list:
    if value is None:
        return []
    if not isinstance(value, str):
        return [value]
    return [part for part in LIST_SEP.split(value.strip()) if part]


def convert_scalar(value, type_name: str):
    text = clean(value)
    if text is None:
        return None
    match type_name.lower():
        case "int" | "integer":
            return int(float(text))
        case "float" | "double" | "number":
            return float(text)
        case "bool" | "boolean":
            return text.lower() in {"1", "true", "yes", "y", "是"}
        case "json":
            return json.loads(text)
        case _:
            return text


def convert(value, type_name: str):
    type_name = (type_name or "string").strip()
    if type_name.endswith("[][]"):
        inner = type_name[:-4] or "string"
        text = "" if value is None else str(value)
        return [
            [convert_scalar(bit, inner) for bit in ARRAY2D_COL_SEP.split(part) if clean(bit)]
            for part in ARRAY2D_ROW_SEP.split(text)
            if clean(part)
        ]
    if type_name.endswith("[]"):
        inner = type_name[:-2] or "string"
        return [convert_scalar(part, inner) for part in split_list(value)]
    return convert_scalar(value, type_name)


def key_columns(sheet_name: str, markers: list[str | None]) -> list[int]:
    levels: dict[int, int] = {}
    for i, marker in enumerate(markers):
        match = KEY_MARKER.match(marker or "")
        if not match:
            continue
        level = int(match.group(1) or "1")
        if level in levels:
            raise ValueError(f"{sheet_name}: duplicate k{level} key column")
        levels[level] = i
    return [levels[level] for level in sorted(levels)]


def rows_to_records(sheet_name: str, rows: list[list[object]]) -> dict[str, dict]:
    if len(rows) < 4:
        raise ValueError(f"{sheet_name}: need at least 4 header rows")
    fields = [clean(v) for v in rows[1]]
    types = [clean(v) or "string" for v in rows[2]]
    markers = [clean(v) for v in rows[3]]
    cols = [i for i, field in enumerate(fields) if field]
    keys = key_columns(sheet_name, markers)
    if not keys:
        raise ValueError(f"{sheet_name}: row 4 has no k key column")

    records: dict[str, dict] = {}
    for row_number, row in enumerate(rows[4:], start=5):
        if all(clean(row[i]) is None if i < len(row) else True for i in cols):
            continue
        item = {}
        for i in cols:
            item[fields[i]] = convert(row[i] if i < len(row) else None, types[i] if i < len(types) else "string")
        key_parts = [clean(item[fields[i]]) for i in keys]
        if any(part is None for part in key_parts):
            raise ValueError(f"{sheet_name}: row {row_number} has empty key")
        target = records
        for part in key_parts[:-1]:
            target = target.setdefault(part, {})
            if not isinstance(target, dict):
                raise ValueError(f"{sheet_name}: key path conflict {'/'.join(key_parts)!r}")
        key = key_parts[-1]
        if key in target:
            raise ValueError(f"{sheet_name}: duplicate key path {'/'.join(key_parts)!r}")
        target[key] = item
    return records


def xlsx_files(root: Path) -> list[Path]:
    if root.is_file():
        return [root] if root.suffix.lower() == ".xlsx" and not root.name.startswith("~$") else []
    return sorted(p for p in root.rglob("*.xlsx") if not p.name.startswith("~$"))


def export(root: Path, out_dir: Path, prefix: str, dry_run: bool = False) -> list[Path]:
    written: list[Path] = []
    seen: set[Path] = set()
    if not dry_run:
        out_dir.mkdir(parents=True, exist_ok=True)
    for workbook in xlsx_files(root):
        with zipfile.ZipFile(workbook) as zf:
            shared = shared_strings(zf)
            for sheet_name, sheet_path in workbook_sheets(zf):
                if not sheet_name.startswith(prefix):
                    continue
                output = out_dir / f"{sheet_name[len(prefix):]}.json"
                if output in seen:
                    raise ValueError(f"duplicate output name: {output.name}")
                seen.add(output)
                records = rows_to_records(sheet_name, sheet_rows(zf, sheet_path, shared))
                if not dry_run:
                    output.write_text(json.dumps(records, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
                written.append(output)
    return written


def read_arg_ini(path: Path) -> dict[str, str]:
    if not path.exists():
        return {}
    out: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw.strip()
        if not line or line.startswith(("#", ";", "[")) or "=" not in line:
            continue
        key, value = line.split("=", 1)
        out[key.strip().lower()] = value.strip().strip("\"'")
    return out


def resolve_config_path(value: str | None, base: Path) -> Path | None:
    if not value:
        return None
    path = Path(value)
    return path.resolve() if path.is_absolute() else (base / path).resolve()


def self_test() -> None:
    rows = [
        ["label"],
        ["id", "name", "tags", "effects", "nums", "matrix", "power", "enabled"],
        ["string", "string", "string[]", "string[][]", "int[]", "int[][]", "float", "bool"],
        ["k1", None, None, None, None, None, None, None],
        ["a", "A", "x:y", "damage:1|heal:2", "1:2", "1:2|3", "1.5", "yes"],
    ]
    data = rows_to_records("z_test", rows)
    assert data["a"]["tags"] == ["x", "y"]
    assert data["a"]["effects"] == [["damage", "1"], ["heal", "2"]]
    assert data["a"]["nums"] == [1, 2]
    assert data["a"]["matrix"] == [[1, 2], [3]]
    assert data["a"]["power"] == 1.5
    assert data["a"]["enabled"] is True

    rows[3] = ["k1", "k2", None, None, None, None, None, None]
    rows.append(["a", "B", "z", "buff:3", "3:4", "4:5|6", "2", "no"])
    nested = rows_to_records("z_nested", rows)
    assert nested["a"]["A"]["id"] == "a"
    assert nested["a"]["B"]["enabled"] is False
    print("self-test ok")


def main() -> int:
    tool_dir = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser(description="Export z_ Excel sheets to JSON.")
    parser.add_argument("root", nargs="?", type=Path, default=None)
    parser.add_argument("-o", "--out", type=Path, default=None)
    parser.add_argument("--prefix", default=None)
    parser.add_argument("--arg", type=Path, default=None)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        self_test()
        return 0

    arg_path = (args.arg or tool_dir / "export_arg.ini").resolve()
    config = read_arg_ini(arg_path)
    root = (args.root.resolve() if args.root else resolve_config_path(config.get("indir"), arg_path.parent) or tool_dir / "indir")
    out_dir = (args.out.resolve() if args.out else resolve_config_path(config.get("outdir"), arg_path.parent) or tool_dir / "out")
    prefix = args.prefix or config.get("prefix") or "z_"
    if not root.exists():
        print(f"input path not found: {root}", file=sys.stderr)
        return 1

    written = export(root, out_dir, prefix, args.dry_run)
    for path in written:
        print(path)
    action = "would export" if args.dry_run else "exported"
    print(f"{action} {len(written)} json file(s) to {out_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
