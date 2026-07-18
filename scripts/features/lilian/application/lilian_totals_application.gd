class_name LilianTotalsApplication
extends RefCounted

const StateScript := preload("res://scripts/features/lilian/domain/lilian_totals_state.gd")


static func snapshot(savedata: Dictionary) -> Dictionary:
	if not savedata.has("totals"):
		return _failure("missing_state_slice")
	return prepare_candidate(savedata["totals"])


static func prepare_candidate(candidate: Variant) -> Dictionary:
	var prepared := StateScript.prepare(candidate)
	return _result(bool(prepared.get("ok", false)), prepared.get("value", {}) as Dictionary, str(prepared.get("error", "")))


static func commit(savedata: Dictionary, candidate: Variant) -> Dictionary:
	var prepared := prepare_candidate(candidate)
	if not bool(prepared.get("ok", false)):
		return prepared
	savedata["totals"] = (prepared["value"] as Dictionary).duplicate(true)
	return prepared


static func initialize_default(savedata: Dictionary) -> Dictionary:
	if not savedata.has("totals"):
		return commit(savedata, StateScript.default_state())
	return snapshot(savedata)


static func apply_lilian_settlement(savedata: Dictionary, rewards: Array, stats: Dictionary) -> Dictionary:
	var current := snapshot(savedata)
	if not bool(current.get("ok", false)):
		return current
	var next := current["value"] as Dictionary
	for reward_v in rewards:
		if reward_v is Dictionary:
			next[StateScript.ITEMS_GAINED_KEY] += int((reward_v as Dictionary).get("count", 0))
	next[StateScript.LILIAN_COUNT_KEY] += 1
	next[StateScript.LILIAN_STEPS_KEY] += int(stats.get("steps", 0))
	var max_diff := maxi(int(stats.get("max_difficulty", 0)), int(stats.get("max_depth", 0)))
	next[StateScript.MAX_DIFFICULTY_KEY] = maxi(int(next[StateScript.MAX_DIFFICULTY_KEY]), max_diff)
	next[StateScript.BATTLES_KEY] += int(stats.get("battles", 0))
	next[StateScript.WINS_KEY] += int(stats.get("wins", 0))
	next[StateScript.LOSSES_KEY] += int(stats.get("losses", 0))
	return commit(savedata, next)


static func _failure(code: String) -> Dictionary:
	var message := "[lilian_totals_application:%s] field=totals" % code
	push_error(message)
	return _result(false, {}, message)


static func _result(ok: bool, value: Dictionary, error: String) -> Dictionary:
	return {"ok": ok, "value": value.duplicate(true), "error": error}
