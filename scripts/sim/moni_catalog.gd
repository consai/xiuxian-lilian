class_name MoniCatalog
extends RefCounted


static func load_bundle() -> Dictionary:
	var bundle := JsonLoader.load_moni_bundle()
	var initial_v: Variant = bundle.get("initial_player")
	if not initial_v is Dictionary:
		push_error("MoniCatalog: initial_player must be a Dictionary")
		return {}
	var initial := (initial_v as Dictionary).duplicate(true)
	var errors: PackedStringArray = []
	for field in ["attrs", "linggen", "items"]:
		if not initial.get(field) is Dictionary:
			errors.append("initial_player.%s must be a Dictionary" % field)
	initial["jineng"] = _string_array(initial.get("jineng"), "jineng", false, errors)
	initial["jineng_use"] = _string_array(initial.get("jineng_use"), "jineng_use", false, errors)
	initial["gongfa"] = _string_array(initial.get("gongfa"), "gongfa", false, errors)
	initial["equips"] = _empty_or_array(initial.get("equips"), "equips", errors)
	initial["item_slots"] = _string_array(initial.get("item_slots"), "item_slots", true, errors)
	initial["equip_slots"] = _int_array(initial.get("equip_slots"), "equip_slots", errors)
	if not errors.is_empty():
		for message in errors:
			push_error("MoniCatalog: %s" % message)
		return {}
	bundle["initial_player"] = initial
	return bundle.duplicate(true)


static func _string_array(
		value: Variant,
		field: String,
		allow_empty: bool,
		errors: PackedStringArray
) -> Array:
	if not value is String:
		errors.append("initial_player.%s must be a String" % field)
		return []
	var out: Array = []
	for entry in str(value).split(":", allow_empty):
		var text := str(entry).strip_edges()
		if allow_empty or text != "":
			out.append(text)
	return out


static func _empty_or_array(value: Variant, field: String, errors: PackedStringArray) -> Array:
	if value is Dictionary and (value as Dictionary).is_empty():
		return []
	errors.append("initial_player.%s must be an empty Dictionary" % field)
	return []


static func _int_array(value: Variant, field: String, errors: PackedStringArray) -> Array:
	if not value is String:
		errors.append("initial_player.%s must be a String" % field)
		return []
	var out: Array = []
	for entry in str(value).split(":", false):
		var text := str(entry).strip_edges()
		if not text.is_valid_int():
			errors.append("initial_player.%s entries must be integers" % field)
			return []
		out.append(int(text))
	return out
