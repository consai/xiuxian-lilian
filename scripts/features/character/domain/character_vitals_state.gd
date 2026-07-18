class_name CharacterVitalsState
extends RefCounted

const FIELDS := ["attrs", "hp", "mp"]


static func default_state() -> Dictionary:
	return {"attrs": {}, "hp": 1000.0, "mp": 1000.0}


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
		errors.append(_error("invalid_root_type", "vitals"))
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
	if not state["attrs"] is Dictionary:
		errors.append(_error("invalid_dictionary", "attrs"))
	for key in ["hp", "mp"]:
		if not state[key] is int and not state[key] is float:
			errors.append(_error("invalid_number", key))
		elif float(state[key]) < 0.0:
			errors.append(_error("invalid_non_negative_number", key))
	return errors


static func _error(code: String, field: String) -> String:
	return "[character_vitals_state:%s] field=%s" % [code, field]


static func _result(ok: bool, value: Dictionary, error: String) -> Dictionary:
	return {"ok": ok, "value": value.duplicate(true), "error": error}
