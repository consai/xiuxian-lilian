class_name AbilitySavedataState
extends RefCounted

const UNLOCKED_KEY := "unlocked_abilities"
const EQUIPPED_KEY := "equipped_abilities"
const SLOT_COUNT := 5


static func default_state() -> Dictionary:
	return {
		UNLOCKED_KEY: [],
		EQUIPPED_KEY: ["", "", "", "", ""],
	}


static func prepare(candidate: Variant) -> Dictionary:
	var errors := collect_errors(candidate)
	if not errors.is_empty():
		for message in errors:
			push_error(message)
		return _result(false, {}, str(errors[0]))
	return _result(true, (candidate as Dictionary).duplicate(true), "")


static func collect_errors(candidate: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not candidate is Dictionary:
		errors.append(_error("invalid_root_type", "abilities", "expected=Dictionary actual=%s" % type_string(typeof(candidate))))
		return errors
	var state := candidate as Dictionary
	for key_v in state.keys():
		if key_v != UNLOCKED_KEY and key_v != EQUIPPED_KEY:
			errors.append(_error("unknown_field", "abilities.%s" % str(key_v)))
	if not state.has(UNLOCKED_KEY):
		errors.append(_error("missing_field", "abilities.%s" % UNLOCKED_KEY))
	if not state.has(EQUIPPED_KEY):
		errors.append(_error("missing_field", "abilities.%s" % EQUIPPED_KEY))
	if not errors.is_empty():
		return errors
	var unlocked_v: Variant = state[UNLOCKED_KEY]
	if not unlocked_v is Array:
		errors.append(_error("invalid_field_type", "abilities.%s" % UNLOCKED_KEY, "expected=Array actual=%s" % type_string(typeof(unlocked_v))))
	else:
		var seen_unlocked := {}
		for index in (unlocked_v as Array).size():
			var ability_id_v: Variant = (unlocked_v as Array)[index]
			if not ability_id_v is String or str(ability_id_v).strip_edges() != str(ability_id_v) or str(ability_id_v) == "":
				errors.append(_error("invalid_ability_id", "abilities.%s[%d]" % [UNLOCKED_KEY, index]))
			elif seen_unlocked.has(ability_id_v):
				errors.append(_error("duplicate_ability_id", "abilities.%s[%d]" % [UNLOCKED_KEY, index]))
			else:
				seen_unlocked[ability_id_v] = true
	var equipped_v: Variant = state[EQUIPPED_KEY]
	if not equipped_v is Array:
		errors.append(_error("invalid_field_type", "abilities.%s" % EQUIPPED_KEY, "expected=Array actual=%s" % type_string(typeof(equipped_v))))
		return errors
	var equipped := equipped_v as Array
	if equipped.size() != SLOT_COUNT:
		errors.append(_error("invalid_slot_count", "abilities.%s" % EQUIPPED_KEY, "expected=%d actual=%d" % [SLOT_COUNT, equipped.size()]))
		return errors
	var unlocked: Array = unlocked_v as Array if unlocked_v is Array else []
	var seen_equipped := {}
	for index in equipped.size():
		var ability_id_v: Variant = equipped[index]
		if not ability_id_v is String:
			errors.append(_error("invalid_slot_value", "abilities.%s[%d]" % [EQUIPPED_KEY, index], "expected=String actual=%s" % type_string(typeof(ability_id_v))))
			continue
		var ability_id := str(ability_id_v)
		if ability_id == "":
			continue
		if ability_id.strip_edges() != ability_id:
			errors.append(_error("invalid_slot_value", "abilities.%s[%d]" % [EQUIPPED_KEY, index], "expected=trimmed_string"))
		elif seen_equipped.has(ability_id):
			errors.append(_error("duplicate_equipped_ability", "abilities.%s[%d]" % [EQUIPPED_KEY, index]))
		elif not unlocked.has(ability_id):
			errors.append(_error("equipped_not_unlocked", "abilities.%s[%d]" % [EQUIPPED_KEY, index]))
		else:
			seen_equipped[ability_id] = true
	return errors


static func _error(code: String, field: String, detail: String = "") -> String:
	var message := "[ability_savedata_state:%s] field=%s" % [code, field]
	if detail != "":
		message += " " + detail
	return message


static func _result(ok: bool, value: Dictionary, error: String) -> Dictionary:
	return {"ok": ok, "value": value.duplicate(true), "error": error}
