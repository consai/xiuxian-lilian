class_name LocationService
extends RefCounted

const PATH := "res://data/locations.json"


static func all_locations() -> Array:
	var root := JsonLoader._read_json_root_object(PATH)
	var raw: Variant = root.get("locations", {})
	if not raw is Dictionary:
		return []
	var out: Array = []
	for key in (raw as Dictionary).keys():
		var row := ((raw as Dictionary)[key] as Dictionary).duplicate(true)
		row["id"] = str(key)
		out.append(row)
	return out


static func by_id(location_id: String) -> Dictionary:
	var root := JsonLoader._read_json_root_object(PATH)
	var raw: Variant = root.get("locations", {})
	if not raw is Dictionary:
		return {}
	var row_v: Variant = (raw as Dictionary).get(location_id)
	if not row_v is Dictionary:
		return {}
	var row := (row_v as Dictionary).duplicate(true)
	row["id"] = location_id
	return row


static func has_location(location_id: String) -> bool:
	return not by_id(location_id).is_empty()
