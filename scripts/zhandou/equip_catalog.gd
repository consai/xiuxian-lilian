class_name EquipCatalog
extends RefCounted

const PATH := "res://data/exportjson/zhuangbei_equips.json"


static func load_bundle() -> Dictionary:
	var root := JsonReader.read_object(PATH)
	if root.is_empty():
		return {"equips": []}
	return {"equips": _parse_rows(root)}


static func _parse_rows(raw: Variant) -> Array:
	var out: Array = []
	if not raw is Dictionary:
		push_error("EquipCatalog: config must be an object keyed by equip id")
		return out
	var rows := raw as Dictionary
	var keys: Array = rows.keys()
	keys.sort_custom(_sort_keys)
	for key_v in keys:
		var key := str(key_v).strip_edges()
		if not key.is_valid_int():
			push_error("EquipCatalog: key must be numeric id, got '%s'" % key)
			continue
		var equip_id := int(key)
		if equip_id <= 0:
			push_error("EquipCatalog: id must be positive, got %d" % equip_id)
			continue
		var row_v: Variant = rows[key_v]
		if not row_v is Dictionary:
			push_error("EquipCatalog: equip %d entry must be an object" % equip_id)
			continue
		var row := (row_v as Dictionary).duplicate(true)
		row["id"] = equip_id
		var equip := EquipDef.from_dict(row)
		if equip != null:
			out.append(equip)
	return out


static func _sort_keys(a: Variant, b: Variant) -> bool:
	var left := str(a)
	var right := str(b)
	if left.is_valid_int() and right.is_valid_int():
		return int(left) < int(right)
	return left.naturalnocasecmp_to(right) < 0
