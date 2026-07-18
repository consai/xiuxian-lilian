class_name CultivationMethodSavedataState
extends RefCounted

const MASTERY_KEY := "method_mastery"
const UNLOCKED_KEY := "unlocked_methods"
const CURRENT_KEY := "current_cultivation_method_id"
const SLOTS_KEY := "cultivation_method_slots"
const SLOT_KEYS := ["main", "support_1", "support_2", "support_3"]


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
		errors.append(_error("invalid_root_type", "cultivation_methods"))
		return errors
	var state := candidate as Dictionary
	for key_v in state.keys():
		if key_v not in [MASTERY_KEY, UNLOCKED_KEY, CURRENT_KEY, SLOTS_KEY]:
			errors.append(_error("unknown_field", "cultivation_methods.%s" % str(key_v)))
	for key in [MASTERY_KEY, UNLOCKED_KEY, CURRENT_KEY, SLOTS_KEY]:
		if not state.has(key): errors.append(_error("missing_field", "cultivation_methods.%s" % key))
	if not errors.is_empty(): return errors
	var unlocked_v: Variant = state[UNLOCKED_KEY]
	if not unlocked_v is Array:
		errors.append(_error("invalid_field_type", UNLOCKED_KEY))
		return errors
	var unlocked := unlocked_v as Array
	var seen := {}
	for index in unlocked.size():
		var method_id_v: Variant = unlocked[index]
		if not _is_trimmed_nonempty_string(method_id_v): errors.append(_error("invalid_method_id", "%s[%d]" % [UNLOCKED_KEY, index]))
		elif seen.has(method_id_v): errors.append(_error("duplicate_method_id", "%s[%d]" % [UNLOCKED_KEY, index]))
		else: seen[method_id_v] = true
	var mastery_v: Variant = state[MASTERY_KEY]
	if not mastery_v is Dictionary:
		errors.append(_error("invalid_field_type", MASTERY_KEY))
	else:
		for method_id_v in (mastery_v as Dictionary).keys():
			var value_v: Variant = (mastery_v as Dictionary)[method_id_v]
			if not _is_trimmed_nonempty_string(method_id_v) or not (value_v is float or value_v is int) or float(value_v) < 0.0 or float(value_v) > 1.0:
				errors.append(_error("invalid_mastery", "%s.%s" % [MASTERY_KEY, str(method_id_v)]))
	var current_v: Variant = state[CURRENT_KEY]
	if not _is_trimmed_nonempty_string(current_v) or not unlocked.has(current_v): errors.append(_error("invalid_current", CURRENT_KEY))
	var slots_v: Variant = state[SLOTS_KEY]
	if not slots_v is Dictionary:
		errors.append(_error("invalid_field_type", SLOTS_KEY))
		return errors
	var slots := slots_v as Dictionary
	for key_v in slots.keys():
		if key_v not in SLOT_KEYS: errors.append(_error("unknown_slot", "%s.%s" % [SLOTS_KEY, str(key_v)]))
	for key in SLOT_KEYS:
		if not slots.has(key):
			errors.append(_error("missing_slot", "%s.%s" % [SLOTS_KEY, key]))
			continue
		var value_v: Variant = slots[key]
		if not value_v is String or str(value_v).strip_edges() != str(value_v): errors.append(_error("invalid_slot", "%s.%s" % [SLOTS_KEY, key]))
		elif key == "main" and (str(value_v) == "" or not unlocked.has(value_v)): errors.append(_error("invalid_main", SLOTS_KEY))
		elif key != "main" and str(value_v) != "" and not unlocked.has(value_v): errors.append(_error("locked_support", "%s.%s" % [SLOTS_KEY, key]))
	var seen_slots := {}
	for key in SLOT_KEYS:
		if slots.has(key) and str(slots[key]) != "":
			if seen_slots.has(slots[key]): errors.append(_error("duplicate_slot_method", SLOTS_KEY))
			else: seen_slots[slots[key]] = true
	return errors


static func _is_trimmed_nonempty_string(value: Variant) -> bool:
	return value is String and str(value) != "" and str(value).strip_edges() == str(value)


static func _error(code: String, field: String) -> String:
	return "[cultivation_method_savedata_state:%s] field=%s" % [code, field]


static func _result(ok: bool, value: Dictionary, error: String) -> Dictionary:
	return {"ok": ok, "value": value.duplicate(true), "error": error}
