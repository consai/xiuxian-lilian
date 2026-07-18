class_name InventoryEquipState
extends RefCounted

const FIELDS := ["owned_equips", "equip_slots", "treasure_item_slots", "storage_equips"]
const SLOT_COUNT := 3


static func default_state() -> Dictionary:
	return {
		"owned_equips": [], "equip_slots": [-1, -1, -1],
		"treasure_item_slots": ["", "", ""], "storage_equips": [],
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
		errors.append(_error("invalid_root_type", "equip_state"))
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
	for field in ["owned_equips", "storage_equips"]:
		_validate_unique_positive_ids(state[field], field, errors)
	_validate_slots(state["equip_slots"], state["owned_equips"] as Array, errors)
	_validate_treasure_slots(state["treasure_item_slots"], errors)
	return errors


static func _validate_unique_positive_ids(value: Variant, field: String, errors: PackedStringArray) -> void:
	if not value is Array:
		errors.append(_error("invalid_array", field))
		return
	var seen := {}
	for index in (value as Array).size():
		var equip_id: Variant = (value as Array)[index]
		if not equip_id is int or int(equip_id) <= 0:
			errors.append(_error("invalid_positive_integer", "%s.%d" % [field, index]))
		elif seen.has(equip_id):
			errors.append(_error("duplicate_equip_id", "%s.%d" % [field, index]))
		else:
			seen[equip_id] = true


static func _validate_slots(value: Variant, owned: Array, errors: PackedStringArray) -> void:
	if not value is Array or (value as Array).size() != SLOT_COUNT:
		errors.append(_error("invalid_slot_count", "equip_slots"))
		return
	for index in SLOT_COUNT:
		var equip_id: Variant = (value as Array)[index]
		if not equip_id is int or int(equip_id) < -1:
			errors.append(_error("invalid_slot_id", "equip_slots.%d" % index))
		elif int(equip_id) > 0 and not owned.has(equip_id):
			errors.append(_error("unowned_slot_id", "equip_slots.%d" % index))


static func _validate_treasure_slots(value: Variant, errors: PackedStringArray) -> void:
	if not value is Array or (value as Array).size() != SLOT_COUNT:
		errors.append(_error("invalid_slot_count", "treasure_item_slots"))
		return
	for index in SLOT_COUNT:
		if not (value as Array)[index] is String:
			errors.append(_error("invalid_slot_type", "treasure_item_slots.%d" % index))


static func _error(code: String, field: String) -> String:
	return "[inventory_equip_state:%s] field=%s" % [code, field]


static func _result(ok: bool, value: Dictionary, error: String) -> Dictionary:
	return {"ok": ok, "value": value.duplicate(true), "error": error}
