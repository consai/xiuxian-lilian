class_name AutoBattleState
extends RefCounted

const ENABLED_KEY := "auto_battle_enabled"
const PRESET_KEY := "auto_battle_preset"
const RULES_KEY := "auto_battle_rules"
const PRESETS := ["balanced", "aggressive", "conservative"]
const RulesScript := preload("res://scripts/features/battle/domain/auto_battle_rules.gd")


static func default_state() -> Dictionary:
	return {ENABLED_KEY: false, PRESET_KEY: "balanced", RULES_KEY: {}}


static func prepare(candidate: Variant) -> Dictionary:
	var errors := collect_errors(candidate)
	if not errors.is_empty():
		for message in errors:
			push_error(message)
		return _result(false, {}, str(errors[0]))
	return _result(true, (candidate as Dictionary).duplicate(true), "")


static func collect_errors(candidate: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not candidate is Dictionary:
		errors.append(_error("invalid_root_type", "auto_battle"))
		return errors
	var state := candidate as Dictionary
	for key_v in state.keys():
		if key_v not in [ENABLED_KEY, PRESET_KEY, RULES_KEY]:
			errors.append(_error("unknown_field", "auto_battle.%s" % str(key_v)))
	for key in [ENABLED_KEY, PRESET_KEY, RULES_KEY]:
		if not state.has(key):
			errors.append(_error("missing_field", "auto_battle.%s" % key))
	if not errors.is_empty():
		return errors
	if not state[ENABLED_KEY] is bool:
		errors.append(_error("invalid_enabled", ENABLED_KEY))
	var preset_v: Variant = state[PRESET_KEY]
	if not preset_v is String or not PRESETS.has(preset_v):
		errors.append(_error("invalid_preset", PRESET_KEY))
	var rules_v: Variant = state[RULES_KEY]
	if not rules_v is Dictionary:
		errors.append(_error("invalid_rules", RULES_KEY))
		return errors
	var rules := rules_v as Dictionary
	if rules.is_empty():
		return errors
	for key in ["version", "policy", "preset", "strategies", "settings"]:
		if not rules.has(key):
			errors.append(_error("missing_rule_field", "%s.%s" % [RULES_KEY, key]))
	if not errors.is_empty():
		return errors
	if rules.size() != 5:
		errors.append(_error("unknown_rule_field", RULES_KEY))
	if not (rules["version"] is int) or int(rules["version"]) != RulesScript.VERSION:
		errors.append(_error("invalid_rule_version", "%s.version" % RULES_KEY))
	if rules["policy"] != RulesScript.POLICY:
		errors.append(_error("invalid_rule_policy", "%s.policy" % RULES_KEY))
	if not rules["preset"] is String or not PRESETS.has(rules["preset"]):
		errors.append(_error("invalid_rule_preset", "%s.preset" % RULES_KEY))
	if not rules["strategies"] is Array:
		errors.append(_error("invalid_strategies", "%s.strategies" % RULES_KEY))
	else:
		for index in (rules["strategies"] as Array).size():
			var strategy_v: Variant = (rules["strategies"] as Array)[index]
			if not strategy_v is Dictionary or not (strategy_v as Dictionary).get("action", {}) is Dictionary:
				errors.append(_error("invalid_strategy", "%s.strategies[%d]" % [RULES_KEY, index]))
	if not rules["settings"] is Dictionary:
		errors.append(_error("invalid_settings", "%s.settings" % RULES_KEY))
	return errors


static func _error(code: String, field: String) -> String:
	return "[auto_battle_state:%s] field=%s" % [code, field]


static func _result(ok: bool, value: Dictionary, error: String) -> Dictionary:
	return {"ok": ok, "value": value.duplicate(true), "error": error}
