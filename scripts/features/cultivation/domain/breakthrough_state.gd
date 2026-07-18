class_name BreakthroughState
extends RefCounted

const BONUSES_KEY := "breakthrough_bonuses"
const QUALITY_KEY := "realm_quality"
const COOLDOWN_KEY := "breakthrough_attempt_cooldown_days"
const BONUS_KEYS := ["pills", "mind", "other"]
const QUALITY_REALMS := ["zhuji", "jindan", "yuanying"]


static func default_state() -> Dictionary:
	return {
		BONUSES_KEY: {"pills": 0, "mind": 0, "other": 0},
		QUALITY_KEY: {"zhuji": 0, "jindan": 0, "yuanying": 0},
		COOLDOWN_KEY: 0,
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
		errors.append(_error("invalid_root_type", "breakthrough"))
		return errors
	var state := candidate as Dictionary
	for key_v in state.keys():
		if key_v not in [BONUSES_KEY, QUALITY_KEY, COOLDOWN_KEY]:
			errors.append(_error("unknown_field", "breakthrough.%s" % str(key_v)))
	for key in [BONUSES_KEY, QUALITY_KEY, COOLDOWN_KEY]:
		if not state.has(key):
			errors.append(_error("missing_field", "breakthrough.%s" % key))
	if not errors.is_empty():
		return errors
	_validate_scores(state[BONUSES_KEY], BONUS_KEYS, BONUSES_KEY, "bonus", errors)
	_validate_scores(state[QUALITY_KEY], QUALITY_REALMS, QUALITY_KEY, "realm", errors)
	var cooldown_v: Variant = state[COOLDOWN_KEY]
	if not cooldown_v is int or int(cooldown_v) < 0:
		errors.append(_error("invalid_cooldown", COOLDOWN_KEY))
	return errors


static func _validate_scores(
		value: Variant, expected_keys: Array, field: String, kind: String, errors: PackedStringArray
) -> void:
	if not value is Dictionary:
		errors.append(_error("invalid_field_type", field))
		return
	var scores := value as Dictionary
	for key_v in scores.keys():
		if key_v not in expected_keys:
			errors.append(_error("unknown_%s" % kind, "%s.%s" % [field, str(key_v)]))
	for key in expected_keys:
		if not scores.has(key):
			errors.append(_error("missing_%s" % kind, "%s.%s" % [field, key]))
			continue
		var score_v: Variant = scores[key]
		if not score_v is int or int(score_v) < 0:
			errors.append(_error("invalid_%s_score" % kind, "%s.%s" % [field, key]))


static func _error(code: String, field: String) -> String:
	return "[breakthrough_state:%s] field=%s" % [code, field]


static func _result(ok: bool, value: Dictionary, error: String) -> Dictionary:
	return {"ok": ok, "value": value.duplicate(true), "error": error}
