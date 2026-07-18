class_name PlayerJournalApplication
extends RefCounted

const StateScript := preload("res://scripts/features/character/domain/player_journal_state.gd")


static func snapshot(savedata: Dictionary) -> Dictionary:
	if not savedata.has("activity_log"):
		return _failure("missing_state_slice")
	return prepare_candidate(savedata["activity_log"])


static func prepare_candidate(candidate: Variant) -> Dictionary:
	var prepared := StateScript.prepare(candidate)
	return _result(bool(prepared.get("ok", false)), prepared.get("value", []) as Array, str(prepared.get("error", "")))


static func commit(savedata: Dictionary, candidate: Variant) -> Dictionary:
	var prepared := prepare_candidate(candidate)
	if not bool(prepared.get("ok", false)):
		return prepared
	savedata["activity_log"] = (prepared["value"] as Array).duplicate(true)
	return prepared


static func initialize_default(savedata: Dictionary) -> Dictionary:
	if not savedata.has("activity_log"):
		return commit(savedata, StateScript.default_state())
	return snapshot(savedata)


static func append(savedata: Dictionary, day: Variant, text: Variant) -> Dictionary:
	var current := snapshot(savedata)
	if not bool(current.get("ok", false)):
		return current
	var next := StateScript.append(current["value"], day, text)
	if not bool(next.get("ok", false)):
		return _result(false, [], str(next.get("error", "")))
	return commit(savedata, next["value"])


static func _failure(code: String) -> Dictionary:
	var message := "[player_journal_application:%s] field=activity_log" % code
	push_error(message)
	return _result(false, [], message)


static func _result(ok: bool, value: Array, error: String) -> Dictionary:
	return {"ok": ok, "value": value.duplicate(true), "error": error}
