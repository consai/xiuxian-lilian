class_name AbilitySavedataApplication
extends RefCounted

const AbilitySavedataStateScript := preload(
	"res://scripts/features/ability/domain/ability_savedata_state.gd"
)


static func snapshot(savedata: Dictionary) -> Dictionary:
	if not savedata.has(AbilitySavedataStateScript.UNLOCKED_KEY) or not savedata.has(AbilitySavedataStateScript.EQUIPPED_KEY):
		var message := "[ability_savedata_application:missing_state_slice] field=abilities"
		push_error(message)
		return _result(false, {}, message)
	return prepare_candidate({
		AbilitySavedataStateScript.UNLOCKED_KEY: savedata[AbilitySavedataStateScript.UNLOCKED_KEY],
		AbilitySavedataStateScript.EQUIPPED_KEY: savedata[AbilitySavedataStateScript.EQUIPPED_KEY],
	})


static func prepare_candidate(candidate: Variant) -> Dictionary:
	var prepared := AbilitySavedataStateScript.prepare(candidate)
	return _result(bool(prepared.get("ok", false)), prepared.get("value", {}) as Dictionary, str(prepared.get("error", "")))


static func commit(savedata: Dictionary, candidate: Variant) -> Dictionary:
	var prepared := prepare_candidate(candidate)
	if not bool(prepared["ok"]):
		return prepared
	var value := prepared["value"] as Dictionary
	var working_copy := savedata.duplicate(true)
	working_copy[AbilitySavedataStateScript.UNLOCKED_KEY] = (value[AbilitySavedataStateScript.UNLOCKED_KEY] as Array).duplicate(true)
	working_copy[AbilitySavedataStateScript.EQUIPPED_KEY] = (value[AbilitySavedataStateScript.EQUIPPED_KEY] as Array).duplicate(true)
	var verified := snapshot(working_copy)
	if not bool(verified["ok"]):
		return verified
	savedata[AbilitySavedataStateScript.UNLOCKED_KEY] = (value[AbilitySavedataStateScript.UNLOCKED_KEY] as Array).duplicate(true)
	savedata[AbilitySavedataStateScript.EQUIPPED_KEY] = (value[AbilitySavedataStateScript.EQUIPPED_KEY] as Array).duplicate(true)
	return _result(true, verified["value"] as Dictionary, "")


static func initialize_default(savedata: Dictionary) -> Dictionary:
	if savedata.has(AbilitySavedataStateScript.UNLOCKED_KEY) or savedata.has(AbilitySavedataStateScript.EQUIPPED_KEY):
		return snapshot(savedata)
	return commit(savedata, AbilitySavedataStateScript.default_state())


static func normalize_slots(raw: Variant) -> Array:
	var slots: Array = []
	if raw is Array:
		for entry_v in raw as Array:
			var entry := str(entry_v).strip_edges()
			slots.append("" if entry == "-1" else entry)
	while slots.size() < AbilitySavedataStateScript.SLOT_COUNT:
		slots.append("")
	return slots.slice(0, AbilitySavedataStateScript.SLOT_COUNT)


static func _result(ok: bool, value: Dictionary, error: String) -> Dictionary:
	return {"ok": ok, "value": value.duplicate(true), "error": error}
