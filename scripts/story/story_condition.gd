class_name StoryCondition
extends RefCounted


static func matches_all(conditions: Variant, state: Dictionary) -> bool:
	if conditions == null:
		return true
	if not conditions is Array:
		return false
	for condition_v in conditions as Array:
		if not condition_v is Dictionary or not matches(condition_v as Dictionary, state):
			return false
	return true


static func matches(condition: Dictionary, state: Dictionary) -> bool:
	var key := str(condition.get("flag", "")).strip_edges()
	if key == "":
		return false
	var op := str(condition.get("op", "eq")).strip_edges()
	var expected: Variant = condition.get("value", true)
	var actual: Variant = state.get(key)
	match op:
		"eq":
			return actual == expected
		"neq":
			return actual != expected
		"has":
			return state.has(key)
		"gte":
			return _is_number(actual) and _is_number(expected) and float(actual) >= float(expected)
		"lte":
			return _is_number(actual) and _is_number(expected) and float(actual) <= float(expected)
	return false


static func apply_effects(effects: Variant, state: Dictionary) -> void:
	if not effects is Array:
		return
	for effect_v in effects as Array:
		if not effect_v is Dictionary:
			continue
		var effect := effect_v as Dictionary
		var key := str(effect.get("flag", "")).strip_edges()
		if key == "":
			continue
		match str(effect.get("op", "set")).strip_edges():
			"set":
				state[key] = effect.get("value")
			"add":
				var amount: Variant = effect.get("value", 0)
				if _is_number(amount):
					state[key] = float(state.get(key, 0.0)) + float(amount)
					if amount is int and state.get(key) is float:
						state[key] = int(state[key])
			"erase":
				state.erase(key)


static func _is_number(value: Variant) -> bool:
	return value is int or value is float
