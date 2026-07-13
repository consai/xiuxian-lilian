class_name ItemAliasCatalog
extends RefCounted

const PATH := "res://data/exportjson/item_legacy_learning_book_ali.json"


static func load_all() -> Dictionary:
	var rows := JsonReader.read_object(PATH)
	var out := {}
	for outer_key in rows.keys():
		var row_v: Variant = rows[outer_key]
		if not row_v is Dictionary:
			push_error("ItemAliasCatalog: row '%s' must be a Dictionary" % str(outer_key))
			continue
		var row := row_v as Dictionary
		var from_id := str(row.get("key", outer_key)).strip_edges()
		var to_v: Variant = row.get("value")
		if from_id == "":
			push_error("ItemAliasCatalog: row '%s' has empty key" % str(outer_key))
			continue
		if not to_v is String:
			push_error("ItemAliasCatalog: alias '%s' value must be a String" % from_id)
			continue
		var to_id := str(to_v).strip_edges()
		if to_id == "":
			push_error("ItemAliasCatalog: alias '%s' has empty value" % from_id)
			continue
		out[from_id] = to_id
	return out.duplicate(true)
