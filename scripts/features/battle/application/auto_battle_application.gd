class_name AutoBattleApplication
extends RefCounted

const StateScript := preload("res://scripts/features/battle/domain/auto_battle_state.gd")
const RulesScript := preload("res://scripts/features/battle/domain/auto_battle_rules.gd")


static func snapshot(savedata: Dictionary) -> Dictionary:
	var candidate := {}
	for key in [StateScript.ENABLED_KEY, StateScript.PRESET_KEY, StateScript.RULES_KEY]:
		if not savedata.has(key):
			var message := "[auto_battle_application:missing_state_slice] field=auto_battle"
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
	for key in [StateScript.ENABLED_KEY, StateScript.PRESET_KEY, StateScript.RULES_KEY]:
		savedata[key] = value[key].duplicate(true) if value[key] is Dictionary or value[key] is Array else value[key]
	return _result(true, value, "")


static func initialize_default(savedata: Dictionary) -> Dictionary:
	var keys := [StateScript.ENABLED_KEY, StateScript.PRESET_KEY, StateScript.RULES_KEY]
	var found := 0
	for key in keys:
		if savedata.has(key): found += 1
	if found == 0:
		return commit(savedata, StateScript.default_state())
	return snapshot(savedata)


static func normalized_rules(savedata: Dictionary) -> Dictionary:
	var state := snapshot(savedata)
	if not bool(state.get("ok", false)):
		return {}
	var rules: Variant = (state["value"] as Dictionary)[StateScript.RULES_KEY]
	return RulesScript.normalize_rules(rules)


static func with_strategies(savedata: Dictionary, strategies: Array) -> Dictionary:
	var state := snapshot(savedata)
	if not bool(state.get("ok", false)):
		return state
	var candidate := state["value"] as Dictionary
	candidate[StateScript.RULES_KEY] = RulesScript.with_config(
		str(candidate[StateScript.PRESET_KEY]), strategies
	)
	return commit(savedata, candidate)


static func _result(ok: bool, value: Dictionary, error: String) -> Dictionary:
	return {"ok": ok, "value": value.duplicate(true), "error": error}
