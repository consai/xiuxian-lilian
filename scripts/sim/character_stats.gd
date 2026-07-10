class_name CharacterStats
extends RefCounted

## 永久根基数据与战斗面板之间的唯一计算入口。
## 属性键常量委托给 [EnumPlayerAttr] 统一管理。

const RealmBalanceServiceScript := preload("res://scripts/sim/realm_balance_service.gd")

const BODY := EnumPlayerAttr.BODY
const SPIRIT := EnumPlayerAttr.SPIRIT
const SENSE := EnumPlayerAttr.SENSE
const AGILITY := EnumPlayerAttr.AGILITY

## 新键 → 旧键映射（normalize 时兼容旧存档格式）
const LEGACY_FOUNDATION_KEYS := {
	BODY: "body",
	SPIRIT: "spirit",
	SENSE: "sense",
	AGILITY: "agility",
}

const COMPREHENSION := EnumPlayerAttr.COMPREHENSION
const WILL := EnumPlayerAttr.WILL
const FORTUNE := EnumPlayerAttr.FORTUNE
const ROOTS := EnumPlayerAttr.ROOTS

const DEFAULT_FOUNDATIONS := EnumPlayerAttr.DEFAULT_FOUNDATIONS

const DEFAULT_APTITUDES := EnumPlayerAttr.DEFAULT_APTITUDES


static func default_foundations() -> Dictionary:
	return DEFAULT_FOUNDATIONS.duplicate(true)


static func default_aptitudes() -> Dictionary:
	return DEFAULT_APTITUDES.duplicate(true)


static func normalize_foundations(raw: Variant) -> Dictionary:
	var out := default_foundations()
	if raw is Dictionary:
		for key in out.keys():
			var value: Variant = (raw as Dictionary).get(key, null)
			if value == null:
				value = (raw as Dictionary).get(LEGACY_FOUNDATION_KEYS.get(key, ""), out[key])
			out[key] = maxf(0.0, _number(value, out[key]))
	return out


static func normalize_aptitudes(raw: Variant) -> Dictionary:
	var out := default_aptitudes()
	if not raw is Dictionary:
		return out
	var src := raw as Dictionary
	out[COMPREHENSION] = maxf(0.0, _number(src.get(COMPREHENSION, out[COMPREHENSION]), 10.0))
	out[WILL] = maxf(0.0, _number(src.get(WILL, out[WILL]), 10.0))
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
	var roushen := float(base[BODY])
	var lingli := float(base[SPIRIT])
	var shenshi := float(base[SENSE])
	var shenfa := float(base[AGILITY])
	var attrs := RealmBalanceServiceScript.build_base_combat_attrs({
		BODY: roushen,
		SPIRIT: lingli,
		SENSE: shenshi,
		AGILITY: shenfa,
	})
	for key in flat_modifiers.keys():
		var stat := str(key)
		attrs[stat] = ZhandouAttr.get_attr(attrs, stat) + _number(flat_modifiers[key], 0.0)
	for key in percent_modifiers.keys():
		var stat := str(key)
		attrs[stat] = ZhandouAttr.get_attr(attrs, stat) * (1.0 + _number(percent_modifiers[key], 0.0))
	return finalize_combat_attrs(attrs)


static func finalize_combat_attrs(raw: Dictionary) -> Dictionary:
	var out := raw.duplicate(true)
	for key in EnumPlayerAttr.ALL_COMBAT_KEYS:
		if not out.has(key):
			out[key] = ZhandouAttr.get_attr(EnumPlayerAttr.COMBAT_DEFAULTS, key, 0.0)
	return out


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
