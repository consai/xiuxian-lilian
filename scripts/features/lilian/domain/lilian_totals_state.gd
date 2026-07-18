class_name LilianTotalsState
extends RefCounted

const BATTLES_KEY := "battles"
const WINS_KEY := "wins"
const LOSSES_KEY := "losses"
const ITEMS_GAINED_KEY := "items_gained"
const LILIAN_COUNT_KEY := "lilian_count"
const LILIAN_STEPS_KEY := "lilian_steps"
const MAX_DIFFICULTY_KEY := "max_difficulty"
const KEYS := [
	BATTLES_KEY, WINS_KEY, LOSSES_KEY, ITEMS_GAINED_KEY, LILIAN_COUNT_KEY,
	LILIAN_STEPS_KEY, MAX_DIFFICULTY_KEY,
]


static func default_state() -> Dictionary:
	return {
		BATTLES_KEY: 0, WINS_KEY: 0, LOSSES_KEY: 0, ITEMS_GAINED_KEY: 0,
		LILIAN_COUNT_KEY: 0, LILIAN_STEPS_KEY: 0, MAX_DIFFICULTY_KEY: 0,
	}


static func prepare(candidate: Variant) -> Dictionary:
	if not candidate is Dictionary:
		return _failure("invalid_root_type", "totals")
	var state := candidate as Dictionary
	if state.size() != KEYS.size():
		return _failure("invalid_field_set", "totals")
	for key in KEYS:
		if not state.has(key):
			return _failure("missing_field", "totals.%s" % key)
		if not state[key] is int or int(state[key]) < 0:
			return _failure("invalid_value", "totals.%s" % key)
	return _result(true, state.duplicate(true), "")


static func _failure(code: String, field: String) -> Dictionary:
	var message := "[lilian_totals_state:%s] field=%s" % [code, field]
	push_error(message)
	return _result(false, {}, message)


static func _result(ok: bool, value: Dictionary, error: String) -> Dictionary:
	return {"ok": ok, "value": value.duplicate(true), "error": error}
