class_name RealmService
extends RefCounted

## 境界阶梯：从 exportjson/exportjson_realms.json 加载，供模拟层按索引遍历。

const PATH := "res://data/exportjson/exportjson_realms.json"

## realms.json 境界 id 前缀 → jingjie_balance / dao_tree 大境界 id
const MAJOR_REALM_BY_PREFIX: Dictionary = {
	"lianqi": "qi",
	"zhuji": "foundation",
	"jindan": "core",
	"yuanying": "nascent",
	"huashen": "transform",
	"lianxu": "void",
	"heti": "merge",
	"dacheng": "great",
	"dujie": "tribulation",
}

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
		if row_v is Dictionary and str((row_v as Dictionary).get("id", "")) == id:
			return (row_v as Dictionary).duplicate(true)
	return {}


static func _build_realms() -> Array:
	var root: Dictionary = JsonLoader._read_json_root_object(PATH)
	var rows: Array = []
	for key in root.keys():
		var row_v: Variant = root[key]
		if row_v is Dictionary:
			rows.append(_normalize_row(row_v as Dictionary))
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("breakthrough_at", 0)) < int(b.get("breakthrough_at", 0))
	)
	return rows


## 将 exportjson 行转为模拟层使用的境界字典（含 major_realm / breakthrough_at）。
static func _normalize_row(export_row: Dictionary) -> Dictionary:
	var id: String = str(export_row.get("id", "")).strip_edges()
	var prefix: String = id.split("_", false)[0] if id.contains("_") else id
	var major_realm: String = str(MAJOR_REALM_BY_PREFIX.get(prefix, ""))
	var xiuwei: int = int(export_row.get("xiuwei", 0))
	return {
		"id": id,
		"name": str(export_row.get("name", "")),
		"major_realm": major_realm,
		"breakthrough_at": xiuwei,
		"xiuwei": xiuwei,
	}
