class_name CultivationMethodSavedataApplication
extends RefCounted

const StateScript := preload("res://scripts/features/cultivation/domain/cultivation_method_savedata_state.gd")

static func snapshot(savedata: Dictionary) -> Dictionary:
	var candidate := {}
	for key in [StateScript.MASTERY_KEY, StateScript.UNLOCKED_KEY, StateScript.CURRENT_KEY, StateScript.SLOTS_KEY]:
		if not savedata.has(key):
			var message := "[cultivation_method_savedata_application:missing_state_slice] field=%s" % key
			push_error(message)
			return _result(false, {}, message)
		candidate[key] = savedata[key]
	return prepare_candidate(candidate)

static func prepare_candidate(candidate: Variant) -> Dictionary:
	var prepared := StateScript.prepare(candidate)
	return _result(bool(prepared.get("ok", false)), prepared.get("value", {}) as Dictionary, str(prepared.get("error", "")))

static func commit(savedata: Dictionary, candidate: Variant) -> Dictionary:
	var prepared := prepare_candidate(candidate)
	if not bool(prepared.get("ok", false)): return prepared
	var value := prepared["value"] as Dictionary
	for key in value.keys(): savedata[key] = value[key].duplicate(true) if value[key] is Dictionary or value[key] is Array else value[key]
	return _result(true, value, "")

static func _result(ok: bool, value: Dictionary, error: String) -> Dictionary:
	return {"ok": ok, "value": value.duplicate(true), "error": error}
