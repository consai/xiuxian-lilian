class_name LiandanState
extends RefCounted

const MAX_LEVEL := 10
const MAX_RECIPE_MASTERY := 1000
const REQUIRED_FIELDS := [
	"level",
	"xp",
	"known_recipes",
	"owned_furnaces",
	"equipped_furnace",
	"last_recipe",
	"last_strategy",
	"total_batches",
	"recipe_mastery",
]


static func default_state() -> Dictionary:
	return {
		"level": 1,
		"xp": 0,
		"known_recipes": [
			"recipe.huiqi",
			"recipe.huiling",
			"recipe.liaoshang",
			"recipe.juqi",
			"recipe.qingmai",
			"recipe.guben",
		],
		"owned_furnaces": {"furnace.old_copper": {"durability": 30}},
		"equipped_furnace": "furnace.old_copper",
		"last_recipe": "recipe.huiqi",
		"last_strategy": "steady",
		"total_batches": 0,
		"recipe_mastery": {},
	}


static func validate(raw: Variant) -> bool:
	if not raw is Dictionary:
		return _fail("invalid_type", "liandan", "expected=Dictionary actual=%s" % type_string(typeof(raw)))
	var state := raw as Dictionary
	for field in REQUIRED_FIELDS:
		if not state.has(field):
			return _fail("missing_field", field)
	if typeof(state["level"]) != TYPE_INT:
		return _fail("invalid_type", "level", "expected=int")
	if int(state["level"]) < 1 or int(state["level"]) > MAX_LEVEL:
		return _fail("out_of_range", "level", "range=1..%d" % MAX_LEVEL)
	if not _non_negative_int(state["xp"]):
		return _fail("invalid_value", "xp", "expected=non_negative_int")
	if not _validate_string_array(state["known_recipes"], "known_recipes"):
		return false
	if not state["owned_furnaces"] is Dictionary:
		return _fail("invalid_type", "owned_furnaces", "expected=Dictionary")
	var furnaces := state["owned_furnaces"] as Dictionary
	for furnace_id_v in furnaces.keys():
		if not furnace_id_v is String or str(furnace_id_v).strip_edges() == "":
			return _fail("invalid_key", "owned_furnaces", "expected=non_empty_string")
		var furnace_v: Variant = furnaces[furnace_id_v]
		if not furnace_v is Dictionary:
			return _fail("invalid_type", "owned_furnaces.%s" % str(furnace_id_v), "expected=Dictionary")
		var furnace := furnace_v as Dictionary
		if not furnace.has("durability"):
			return _fail("missing_field", "owned_furnaces.%s.durability" % str(furnace_id_v))
		if not _non_negative_int(furnace["durability"]):
			return _fail("invalid_value", "owned_furnaces.%s.durability" % str(furnace_id_v), "expected=non_negative_int")
	if not _non_empty_string(state["equipped_furnace"]):
		return _fail("invalid_value", "equipped_furnace", "expected=non_empty_string")
	if not furnaces.has(str(state["equipped_furnace"])):
		return _fail("unknown_reference", "equipped_furnace", "value=%s" % str(state["equipped_furnace"]))
	if not _non_empty_string(state["last_recipe"]):
		return _fail("invalid_value", "last_recipe", "expected=non_empty_string")
	if not (state["known_recipes"] as Array).has(str(state["last_recipe"])):
		return _fail("unknown_reference", "last_recipe", "value=%s" % str(state["last_recipe"]))
	if not _non_empty_string(state["last_strategy"]):
		return _fail("invalid_value", "last_strategy", "expected=non_empty_string")
	if str(state["last_strategy"]) == "standard":
		return _fail("removed_value", "last_strategy", "value=standard")
	if not _non_negative_int(state["total_batches"]):
		return _fail("invalid_value", "total_batches", "expected=non_negative_int")
	if not state["recipe_mastery"] is Dictionary:
		return _fail("invalid_type", "recipe_mastery", "expected=Dictionary")
	for recipe_id_v in (state["recipe_mastery"] as Dictionary).keys():
		if not recipe_id_v is String or str(recipe_id_v).strip_edges() == "":
			return _fail("invalid_key", "recipe_mastery", "expected=non_empty_string")
		var mastery_v: Variant = (state["recipe_mastery"] as Dictionary)[recipe_id_v]
		if typeof(mastery_v) != TYPE_INT or int(mastery_v) < 0 or int(mastery_v) > MAX_RECIPE_MASTERY:
			return _fail("out_of_range", "recipe_mastery.%s" % str(recipe_id_v), "range=0..%d" % MAX_RECIPE_MASTERY)
	return true


static func prepare(raw: Variant) -> Dictionary:
	if not validate(raw):
		return {}
	return (raw as Dictionary).duplicate(true)


static func _validate_string_array(value: Variant, field: String) -> bool:
	if not value is Array:
		return _fail("invalid_type", field, "expected=Array")
	var seen := {}
	for index in (value as Array).size():
		var entry: Variant = (value as Array)[index]
		if not _non_empty_string(entry):
			return _fail("invalid_value", "%s[%d]" % [field, index], "expected=non_empty_string")
		if seen.has(str(entry)):
			return _fail("duplicate_value", "%s[%d]" % [field, index], "value=%s" % str(entry))
		seen[str(entry)] = true
	return true


static func _non_empty_string(value: Variant) -> bool:
	return value is String and str(value).strip_edges() != ""


static func _non_negative_int(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and int(value) >= 0


static func _fail(code: String, field: String, detail: String = "") -> bool:
	var message := "[liandan_state:%s] field=%s" % [code, field]
	if detail != "":
		message += " " + detail
	push_error(message)
	return false
