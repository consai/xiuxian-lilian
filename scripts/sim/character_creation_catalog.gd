class_name CharacterCreationCatalog
extends RefCounted

const PATHS := {
	"origin": "res://data/exportjson/character_origins.json",
	"root": "res://data/exportjson/character_roots.json",
	"talent": "res://data/exportjson/character_talents.json",
}


static func load_choices(choice_type: String) -> Array:
	var type_id := choice_type.strip_edges().to_lower()
	if not PATHS.has(type_id):
		push_error("CharacterCreationCatalog: unknown choice type '%s'" % choice_type)
		return []
	var rows := JsonReader.read_object(str(PATHS[type_id]))
	var out: Array = []
	for row_key in rows.keys():
		var row_v: Variant = rows[row_key]
		if not row_v is Dictionary:
			push_error("CharacterCreationCatalog: row '%s' must be a Dictionary" % str(row_key))
			continue
		var row := (row_v as Dictionary).duplicate(true)
		if bool(row.get("enabled", true)):
			out.append(row)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("sortOrder", 0)) < int(b.get("sortOrder", 0))
	)
	return out
