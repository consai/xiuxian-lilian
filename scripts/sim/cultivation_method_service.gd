class_name CultivationMethodService
extends RefCounted

const PATH := "res://data/cultivation_methods.json"
const SLOT_MAIN := "main"
const SLOT_SUPPORT := "support"
const SLOT_MOVEMENT := "movement"


static func all_methods() -> Array:
	var root := JsonLoader._read_json_root_object(PATH)
	var raw_v: Variant = root.get("methods", {})
	var out: Array = []
	if not raw_v is Dictionary:
		return out
	for key in (raw_v as Dictionary).keys():
		var row_v: Variant = (raw_v as Dictionary)[key]
		if row_v is Dictionary:
			var row := (row_v as Dictionary).duplicate(true)
			row["id"] = str(key)
			out.append(row)
	return out


static func by_id(method_id: String) -> Dictionary:
	var mid := method_id.strip_edges()
	for row_v in all_methods():
		var row := row_v as Dictionary
		if str(row.get("id", "")) == mid:
			return row
	return {}


static func equipped_rows(slots: Dictionary) -> Array:
	var out: Array = []
	for key in ["main", "support_1", "support_2", "movement"]:
		var row := by_id(str(slots.get(key, "")))
		if not row.is_empty():
			out.append(row)
	return out


static func build_modifiers(slots: Dictionary) -> Dictionary:
	var flat: Dictionary = {}
	var percent: Dictionary = {}
	var damage_bonus := 0.0
	for row_v in equipped_rows(slots):
		var row := row_v as Dictionary
		for key in (row.get("flat_attrs", {}) as Dictionary).keys():
			flat[key] = float(flat.get(key, 0.0)) + float((row["flat_attrs"] as Dictionary)[key])
		for key in (row.get("percent_attrs", {}) as Dictionary).keys():
			percent[key] = float(percent.get(key, 0.0)) + float((row["percent_attrs"] as Dictionary)[key])
		damage_bonus += float(row.get("damage_bonus_percent", 0.0))
	var main := by_id(str(slots.get("main", "")))
	if not main.is_empty():
		flat[FightAttr.COMBAT_MP_RESTORE_2S] = float(main.get("combat_mp_restore_2s", 0.0))
	if damage_bonus > 0.0:
		flat[FightAttr.DAMAGE_BONUS] = damage_bonus
	return {"flat": flat, "percent": percent}


static func cultivation_speed(slots: Dictionary) -> float:
	var main := by_id(str(slots.get("main", "")))
	return maxf(0.0, float(main.get("cultivation_speed", 0.0)))


static func can_equip(row: Dictionary, slot_key: String) -> bool:
	var kind := str(row.get("slot_type", ""))
	if slot_key == "main":
		return kind == SLOT_MAIN
	if slot_key.begins_with("support_"):
		return kind == SLOT_SUPPORT
	return slot_key == "movement" and kind == SLOT_MOVEMENT
