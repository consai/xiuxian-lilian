class_name RealmService
extends RefCounted

## 境界阶梯：从 exportjson/realms.json 加载，供模拟层按索引遍历。

const PATH := "res://data/exportjson/realms.json"

static var _realms: Array = []


static func reload() -> void:
	_realms = _build_realms()


static func realms() -> Array:
	if _realms.is_empty():
		reload()
	return _realms.duplicate(true)


static func realm_by_id(realm_id: String) -> Dictionary:
	var id := realm_id.strip_edges()
	for row_v in realms():
		if not row_v is Dictionary:
			continue
		var row := row_v as Dictionary
		if str(row.get("id", "")) == id or str(row.get("level", "")) == id:
			return row.duplicate(true)
	return {}


static func _build_realms() -> Array:
	var root: Dictionary = JsonReader.read_object(PATH)
	var rows: Array = []
	for key in root.keys():
		var row_v: Variant = root[key]
		if row_v is Dictionary:
			rows.append(_normalize_row(row_v as Dictionary))
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("level", 0)) < int(b.get("level", 0))
	)
	return rows


## 将 exportjson 行转为模拟层使用的境界字典（level 为索引，realm 为英文枚举）。
static func _normalize_row(export_row: Dictionary) -> Dictionary:
	var level: int = int(export_row.get("level", 0))
	var realm_enum: String = str(export_row.get("realm", "")).strip_edges().to_lower()
	var major_realm: String = EnumMajorRealm.normalize_id(realm_enum)
	var xiuwei: int = int(export_row.get("xiuwei", 0))
	return {
		"id": str(level),
		"level": level,
		"name": str(export_row.get("name", "")),
		"realm": realm_enum,
		"major_realm": major_realm,
		"breakthrough_at": xiuwei,
		"xiuwei": xiuwei,
		"foundations": _foundation_attrs(export_row),
		"combat_attrs": _combat_attrs(export_row),
	}

static func _foundation_attrs(row: Dictionary) -> Dictionary:
	return {
		EnumPlayerAttr.BODY: _number(row.get(EnumPlayerAttr.BODY, 0.0)),
		EnumPlayerAttr.SPIRIT: _number(row.get(EnumPlayerAttr.SPIRIT, 0.0)),
		EnumPlayerAttr.SENSE: _number(row.get(EnumPlayerAttr.SENSE, 0.0)),
		EnumPlayerAttr.AGILITY: _number(row.get(EnumPlayerAttr.AGILITY, 0.0)),
	}


static func _combat_attrs(row: Dictionary) -> Dictionary:
	var attrs := {}
	for key in [
		EnumPlayerAttr.HP_MAX, EnumPlayerAttr.MP_MAX,
		EnumPlayerAttr.PHYSICAL_ATK, EnumPlayerAttr.MAGIC_ATK,
		EnumPlayerAttr.PHYSICAL_DEF, EnumPlayerAttr.MAGIC_DEF,
		EnumPlayerAttr.SPD, EnumPlayerAttr.CONTROL_RESIST,
	]:
		if row.has(key):
			attrs[key] = _number(row[key])
	if row.has("control"):
		attrs[EnumPlayerAttr.CONTROL_POWER] = _number(row["control"])
	return attrs

static func _number(value: Variant, fallback: float = 0.0) -> float:
	if value is int or value is float:
		return value
	if value is String or value is StringName:
		var text := str(value).strip_edges()
		return text.to_float() if text.is_valid_float() else fallback
	return fallback
