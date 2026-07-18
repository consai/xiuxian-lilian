class_name InventoryItemSlotsApplication
extends RefCounted

const StateScript := preload("res://scripts/features/inventory/domain/inventory_item_slots_state.gd")


static func snapshot(savedata: Dictionary) -> Dictionary:
	if not savedata.has(StateScript.KEY):
		return _failure("missing_state_slice")
	return prepare_candidate({StateScript.KEY: savedata[StateScript.KEY]})


static func prepare_candidate(candidate: Variant) -> Dictionary:
	var prepared := StateScript.prepare(candidate)
	return _result(bool(prepared.get("ok", false)), prepared.get("value", {}) as Dictionary, str(prepared.get("error", "")))


static func commit(savedata: Dictionary, candidate: Variant) -> Dictionary:
	var prepared := prepare_candidate(candidate)
	if not bool(prepared.get("ok", false)):
		return prepared
	var value := prepared["value"] as Dictionary
	savedata[StateScript.KEY] = (value[StateScript.KEY] as Array).duplicate(true)
	return _result(true, value, "")


static func initialize_default(savedata: Dictionary) -> Dictionary:
	if not savedata.has(StateScript.KEY):
		return commit(savedata, StateScript.default_state())
	return snapshot(savedata)


static func _failure(code: String) -> Dictionary:
	var message := "[inventory_item_slots_application:%s] field=item_slots" % code
	push_error(message)
	return _result(false, {}, message)


static func _result(ok: bool, value: Dictionary, error: String) -> Dictionary:
	return {"ok": ok, "value": value.duplicate(true), "error": error}
