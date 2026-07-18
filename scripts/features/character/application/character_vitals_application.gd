class_name CharacterVitalsApplication
extends RefCounted

const StateScript := preload("res://scripts/features/character/domain/character_vitals_state.gd")


static func snapshot(savedata: Dictionary) -> Dictionary:
	var candidate := {}
	for key in StateScript.FIELDS:
		if not savedata.has(key):
			var message := "[character_vitals_application:missing_state_slice] field=%s" % key
			push_error(message)
			return _result(false, {}, message)
		candidate[key] = savedata[key]
	return prepare_candidate(candidate)


static func prepare_candidate(candidate: Variant) -> Dictionary:
	var prepared := StateScript.prepare(candidate)
	return _result(bool(prepared.get("ok", false)), prepared.get("value", {}) as Dictionary, str(prepared.get("error", "")))


static func commit(savedata: Dictionary, candidate: Variant) -> Dictionary:
	var prepared := prepare_candidate(candidate)
	if not bool(prepared.get("ok", false)):
		return prepared
	var value := prepared["value"] as Dictionary
	for key in StateScript.FIELDS:
		savedata[key] = value[key].duplicate(true) if value[key] is Dictionary else value[key]
	return _result(true, value, "")


static func initialize_default(savedata: Dictionary) -> Dictionary:
	var found := 0
	for key in StateScript.FIELDS:
		if savedata.has(key):
			found += 1
	if found == 0:
		return commit(savedata, StateScript.default_state())
	return snapshot(savedata)


static func _result(ok: bool, value: Dictionary, error: String) -> Dictionary:
	return {"ok": ok, "value": value.duplicate(true), "error": error}
