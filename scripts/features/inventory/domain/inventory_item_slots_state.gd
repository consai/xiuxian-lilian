class_name InventoryItemSlotsState
extends RefCounted

const KEY := "item_slots"
const SLOT_COUNT := 3


static func default_state() -> Dictionary:
	return {KEY: ["", "", ""]}


static func prepare(candidate: Variant) -> Dictionary:
	if not candidate is Dictionary:
		return _failure("invalid_root_type", "item_slots")
	var state := candidate as Dictionary
	if state.size() != 1 or not state.has(KEY):
		return _failure("invalid_field_set", "item_slots")
	var slots_v: Variant = state[KEY]
	if not slots_v is Array or (slots_v as Array).size() != SLOT_COUNT:
		return _failure("invalid_slot_count", KEY)
	for index in SLOT_COUNT:
		var slot: Variant = (slots_v as Array)[index]
		if not slot is String:
			return _failure("invalid_slot_type", "%s.%d" % [KEY, index])
	return _result(true, {KEY: (slots_v as Array).duplicate(true)}, "")


static func _failure(code: String, field: String) -> Dictionary:
	var message := "[inventory_item_slots_state:%s] field=%s" % [code, field]
	push_error(message)
	return _result(false, {}, message)


static func _result(ok: bool, value: Dictionary, error: String) -> Dictionary:
	return {"ok": ok, "value": value.duplicate(true), "error": error}
