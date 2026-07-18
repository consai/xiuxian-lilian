class_name CharacterProgressionState
extends RefCounted

const FIELDS := [
	"day", "realm_index", "realm_name", "cultivation", "cultivation_instability",
	"breakthrough_at", "injury_days", "ling_stones",
]


static func default_state() -> Dictionary:
	return {
		"day": 1, "realm_index": 0, "realm_name": "", "cultivation": 0,
		"cultivation_instability": 0, "breakthrough_at": 300,
		"injury_days": 0, "ling_stones": 0,
	}


static func prepare(candidate: Variant) -> Dictionary:
	var errors := collect_errors(candidate)
	if not errors.is_empty():
		for message in errors:
			push_error(message)
		return _result(false, {}, errors[0])
	return _result(true, (candidate as Dictionary).duplicate(true), "")


static func collect_errors(candidate: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not candidate is Dictionary:
		errors.append(_error("invalid_root_type", "progression"))
		return errors
	var state := candidate as Dictionary
	for key_v in state.keys():
		if str(key_v) not in FIELDS:
			errors.append(_error("unknown_field", str(key_v)))
	for key in FIELDS:
		if not state.has(key):
			errors.append(_error("missing_field", key))
	if not errors.is_empty():
		return errors
	for key in ["day", "realm_index", "cultivation", "cultivation_instability", "breakthrough_at", "injury_days", "ling_stones"]:
		if not state[key] is int or int(state[key]) < (1 if key == "day" else 0):
			errors.append(_error("invalid_non_negative_integer", key))
	if not state["realm_name"] is String:
		errors.append(_error("invalid_string", "realm_name"))
	return errors


static func _error(code: String, field: String) -> String:
	return "[character_progression_state:%s] field=%s" % [code, field]


static func _result(ok: bool, value: Dictionary, error: String) -> Dictionary:
	return {"ok": ok, "value": value.duplicate(true), "error": error}
