class_name GameTimeCatalog
extends RefCounted

const PATH := "res://data/exportjson/yunxing_params/shijian_rules.json"

static var _settings: Dictionary = {}


static func settings() -> Dictionary:
	if _settings.is_empty():
		_settings = _load_settings()
	return _settings.duplicate(true)


static func _load_settings() -> Dictionary:
	var rows := JsonReader.read_object(PATH)
	var out := {}
	for outer_key in rows.keys():
		var row_v: Variant = rows[outer_key]
		if not row_v is Dictionary:
			push_error("GameTimeCatalog: row '%s' must be a Dictionary" % str(outer_key))
			continue
		var row := row_v as Dictionary
		var key := str(row.get("key", outer_key)).strip_edges()
		var value_v: Variant = row.get("value")
		if key == "":
			push_error("GameTimeCatalog: row '%s' has empty key" % str(outer_key))
			continue
		if not value_v is String:
			push_error("GameTimeCatalog: setting '%s' value must be a String" % key)
			continue
		out[key] = str(value_v).strip_edges()
	return out
