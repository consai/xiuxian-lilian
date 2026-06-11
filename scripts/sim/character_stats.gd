class_name CharacterStats
extends RefCounted

## 永久根基数据与战斗面板之间的唯一计算入口。

const BODY := "body"
const SPIRIT := "spirit"
const SENSE := "sense"
const AGILITY := "agility"

const COMPREHENSION := "comprehension"
const FORTUNE := "fortune"
const ROOTS := "roots"

const DEFAULT_FOUNDATIONS := {
	BODY: 10.0,
	SPIRIT: 10.0,
	SENSE: 10.0,
	AGILITY: 10.0,
}

const DEFAULT_APTITUDES := {
	COMPREHENSION: 10.0,
	FORTUNE: 10.0,
	ROOTS: {"fire": 80.0},
}


static func default_foundations() -> Dictionary:
	return DEFAULT_FOUNDATIONS.duplicate(true)


static func default_aptitudes() -> Dictionary:
	return DEFAULT_APTITUDES.duplicate(true)


static func normalize_foundations(raw: Variant) -> Dictionary:
	var out := default_foundations()
	if raw is Dictionary:
		for key in out.keys():
			out[key] = maxf(0.0, _number((raw as Dictionary).get(key, out[key]), out[key]))
	return out


static func normalize_aptitudes(raw: Variant) -> Dictionary:
	var out := default_aptitudes()
	if not raw is Dictionary:
		return out
	var src := raw as Dictionary
	out[COMPREHENSION] = maxf(0.0, _number(src.get(COMPREHENSION, out[COMPREHENSION]), 10.0))
	out[FORTUNE] = maxf(0.0, _number(src.get(FORTUNE, out[FORTUNE]), 10.0))
	var roots: Dictionary = {}
	var roots_v: Variant = src.get(ROOTS, {})
	if roots_v is Dictionary:
		for key in (roots_v as Dictionary).keys():
			var root_id := str(key).strip_edges().to_lower()
			if root_id != "":
				roots[root_id] = clampf(_number((roots_v as Dictionary)[key], 0.0), 0.0, 100.0)
	out[ROOTS] = roots
	return out


static func build_combat_attrs(
		foundations: Variant,
		flat_modifiers: Dictionary = {},
		percent_modifiers: Dictionary = {}
) -> Dictionary:
	var base := normalize_foundations(foundations)
	var body := float(base[BODY])
	var spirit := float(base[SPIRIT])
	var sense := float(base[SENSE])
	var agility := float(base[AGILITY])
	var attrs := {
		FightAttr.HP_MAX: 50.0 + body * 5.0,
		FightAttr.MP_MAX: 50.0 + spirit * 5.0,
		FightAttr.PHYSICAL_ATK: body * 3.0,
		FightAttr.MAGIC_ATK: spirit * 2.4 + sense * 0.8,
		FightAttr.PHYSICAL_DEF: body * 2.0,
		FightAttr.MAGIC_DEF: spirit * 1.2 + sense * 1.2,
		FightAttr.SPD: 50.0 + sense * 3.0 + body * 2.0,
		FightAttr.ACCURACY: 50.0 + sense * 3.0 + agility,
		FightAttr.EVASION: 50.0 + agility * 3.0 + sense,
		FightAttr.CONTROL_POWER: sense * 3.0 + spirit,
		FightAttr.CONTROL_RESIST: sense * 2.0 + body,
		FightAttr.HP_REGEN: 0.5 + body * 0.05,
		FightAttr.MP_REGEN: 0.5 + spirit * 0.04 + sense * 0.01,
		FightAttr.CARRY: 20.0 + body * 2.0,
		FightAttr.SHIELD: 0.0,
		FightAttr.CRIT: 10.0,
		FightAttr.CRIT_DAMAGE: 150.0,
	}
	for key in flat_modifiers.keys():
		var stat := str(key)
		attrs[stat] = FightAttr.get_attr(attrs, stat) + _number(flat_modifiers[key], 0.0)
	for key in percent_modifiers.keys():
		var stat := str(key)
		attrs[stat] = FightAttr.get_attr(attrs, stat) * (1.0 + _number(percent_modifiers[key], 0.0))
	return finalize_combat_attrs(attrs)


## 旧配置只有 atk/def 时自动补齐拆分面板；新配置也会生成兼容别名。
static func finalize_combat_attrs(raw: Dictionary) -> Dictionary:
	var out := raw.duplicate(true)
	var legacy_atk := FightAttr.get_attr(out, FightAttr.ATK, 0.0)
	var legacy_def := FightAttr.get_attr(out, FightAttr.DEF, 0.0)
	if not out.has(FightAttr.PHYSICAL_ATK):
		out[FightAttr.PHYSICAL_ATK] = legacy_atk
	if not out.has(FightAttr.MAGIC_ATK):
		out[FightAttr.MAGIC_ATK] = legacy_atk
	if not out.has(FightAttr.PHYSICAL_DEF):
		out[FightAttr.PHYSICAL_DEF] = legacy_def
	if not out.has(FightAttr.MAGIC_DEF):
		out[FightAttr.MAGIC_DEF] = legacy_def
	out[FightAttr.ATK] = maxf(
		FightAttr.get_attr(out, FightAttr.PHYSICAL_ATK),
		FightAttr.get_attr(out, FightAttr.MAGIC_ATK)
	)
	out[FightAttr.DEF] = minf(
		FightAttr.get_attr(out, FightAttr.PHYSICAL_DEF),
		FightAttr.get_attr(out, FightAttr.MAGIC_DEF)
	)
	for key in FightAttr.ALL_KEYS:
		if not out.has(key):
			out[key] = FightAttr.get_attr(FightAttr.TEST_DEFAULTS, key, 0.0)
	return out


## 历练敌人仍使用旧 atk/def 标尺；仅在没有新物法字段时迁移到根基标尺。
static func migrate_legacy_enemy_attrs(raw: Dictionary) -> Dictionary:
	if raw.has(FightAttr.PHYSICAL_ATK) or raw.has(FightAttr.MAGIC_ATK):
		return finalize_combat_attrs(raw)
	var out := raw.duplicate(true)
	var old_atk := FightAttr.get_attr(raw, FightAttr.ATK, 0.0)
	var old_def := FightAttr.get_attr(raw, FightAttr.DEF, 0.0)
	out.erase(FightAttr.ATK)
	out.erase(FightAttr.DEF)
	out[FightAttr.PHYSICAL_ATK] = old_atk * 0.30
	out[FightAttr.MAGIC_ATK] = old_atk * 0.32
	out[FightAttr.PHYSICAL_DEF] = old_def * 0.20
	out[FightAttr.MAGIC_DEF] = old_def * 0.24
	return finalize_combat_attrs(out)


static func root_label(aptitudes: Dictionary) -> String:
	var roots_v: Variant = aptitudes.get(ROOTS, {})
	if not roots_v is Dictionary or (roots_v as Dictionary).is_empty():
		return "无灵根"
	var names := {
		"metal": "金", "wood": "木", "water": "水", "fire": "火", "earth": "土",
		"lightning": "雷", "wind": "风", "ice": "冰",
	}
	var rows: Array = []
	for key in (roots_v as Dictionary).keys():
		rows.append({"id": str(key), "value": float((roots_v as Dictionary)[key])})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["value"]) > float(b["value"]))
	var labels: PackedStringArray = []
	for row in rows:
		labels.append("%s %.0f" % [str(names.get(row["id"], row["id"])), float(row["value"])])
	return "、".join(labels)


static func _number(value: Variant, fallback: float) -> float:
	if value is int or value is float:
		return float(value)
	return fallback
