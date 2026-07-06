#!/usr/bin/env python3
"""一次性生成 境界.xlsx：level 为键，realm 为英文枚举，90 级修为阈值插值。"""
from __future__ import annotations

import json
import math
import zipfile
from pathlib import Path

import openpyxl

ROOT = Path(__file__).resolve().parents[1]
XLSX = ROOT / "xiuxian配置表" / "indir" / "境界.xlsx"
OUT_JSON = ROOT / "data" / "exportjson" / "realms.json"

# 大境界：等级起点、中文名、英文枚举（EnumItemTier / LEGACY_ID_MAP）
MAJOR_BLOCKS = [
    (1, "炼气", "lianqi", 9),
    (10, "筑基", "zhuji", 10),
    (20, "金丹", "jindan", 10),
    (30, "元婴", "yuanying", 10),
    (40, "化神", "huashen", 10),
    (50, "炼虚", "lianxu", 10),
    (60, "合体", "heti", 10),
    (70, "大乘", "dacheng", 10),
    (80, "渡劫", "tribulation", 11),
]

# 旧表三元小境锚点 → 修为门槛（与 level 对齐）
XIUWEI_ANCHORS: dict[int, int] = {
    1: 300,
    4: 800,
    7: 1600,
    10: 4000,
    13: 6900,
    16: 10400,
    20: 20900,
    23: 32200,
    26: 44400,
    30: 81000,
    33: 118700,
    36: 157600,
    40: 274300,
    43: 392400,
    46: 512000,
    50: 633200,
    53: 756100,
    56: 1124800,
    60: 1495400,
    63: 1868000,
    66: 2242700,
    70: 2619600,
    73: 3750300,
    76: 4883400,
    80: 6019000,
}

CN_NUM = "零一二三四五六七八九十"


def cn_layer(n: int) -> str:
    if n <= 10:
        return CN_NUM[n] + "层"
    if n == 11:
        return "十一层"
    return str(n) + "层"


def interpolate_xiuwei(level: int) -> int:
    keys = sorted(XIUWEI_ANCHORS)
    if level <= keys[0]:
        return XIUWEI_ANCHORS[keys[0]]
    if level >= keys[-1]:
        # 渡劫 81-90：沿用末段斜率外推
        prev_k, prev_v = keys[-2], XIUWEI_ANCHORS[keys[-2]]
        last_k, last_v = keys[-1], XIUWEI_ANCHORS[keys[-1]]
        slope = (last_v - prev_v) / (last_k - prev_k)
        return int(round(last_v + slope * (level - last_k)))
    for i in range(len(keys) - 1):
        left, right = keys[i], keys[i + 1]
        if left <= level <= right:
            lv, rv = XIUWEI_ANCHORS[left], XIUWEI_ANCHORS[right]
            t = (level - left) / (right - left)
            return int(round(lv + (rv - lv) * t))
    return XIUWEI_ANCHORS[keys[-1]]


def build_rows() -> list[dict]:
    rows: list[dict] = []
    layer_counter: dict[str, int] = {}
    for start, major_name, realm, count in MAJOR_BLOCKS:
        layer_counter[major_name] = 0
        for offset in range(count):
            level = start + offset
            layer_counter[major_name] += 1
            rows.append(
                {
                    "level": level,
                    "name": f"{major_name}{cn_layer(layer_counter[major_name])}",
                    "realm": realm,
                    "xiuwei": interpolate_xiuwei(level),
                }
            )
    return rows


def write_xlsx(rows: list[dict]) -> None:
    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = "z_realms"
    ws.append(["等级", "名称", "大境界", "修为"])
    ws.append(["level", "name", "realm", "xiuwei"])
    ws.append(["int", "string", "string", "int"])
    ws.append(["k1", None, None, None])
    for row in rows:
        ws.append([row["level"], row["name"], row["realm"], row["xiuwei"]])
    wb.save(XLSX)


def export_json(rows: list[dict]) -> None:
    payload = {str(row["level"]): row for row in rows}
    OUT_JSON.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    rows = build_rows()
    assert len(rows) == 90, len(rows)
    prev = 0
    for row in rows:
        assert row["xiuwei"] > prev, row
        prev = row["xiuwei"]
    write_xlsx(rows)
    # 与 export_excel_json 一致再导出一遍做校验
    import sys

    sys.path.insert(0, str(ROOT / "xiuxian配置表"))
    from export_excel_json import export

    export(XLSX.parent, OUT_JSON.parent, "z_", dry_run=False)
    print(f"wrote {len(rows)} realms -> {XLSX.name}, {OUT_JSON.name}")


if __name__ == "__main__":
    main()
