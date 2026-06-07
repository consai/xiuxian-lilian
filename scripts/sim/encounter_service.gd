class_name EncounterService
extends RefCounted

const PATH := "res://data/encounters.json"


static func all_encounters() -> Array:
	var root := JsonLoader._read_json_root_object(PATH)
	var raw: Variant = root.get("encounters", {})
	if not raw is Dictionary:
		return []
	var out: Array = []
	for id in ["normal", "elite", "boss"]:
		if (raw as Dictionary).has(id) and (raw as Dictionary)[id] is Dictionary:
			var row := ((raw as Dictionary)[id] as Dictionary).duplicate(true)
			row["id"] = id
			out.append(row)
	return out


static func by_id(encounter_id: String) -> Dictionary:
	for row_v in all_encounters():
		var row := row_v as Dictionary
		if str(row.get("id", "")) == encounter_id:
			return row
	return {}
