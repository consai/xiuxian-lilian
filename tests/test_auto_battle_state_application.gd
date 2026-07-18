extends SceneTree

const StateScript := preload("res://scripts/features/battle/domain/auto_battle_state.gd")
const ApplicationScript := preload("res://scripts/features/battle/application/auto_battle_application.gd")
const RulesScript := preload("res://scripts/features/battle/domain/auto_battle_rules.gd")

var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var store := {}
	var initialized := ApplicationScript.initialize_default(store)
	_check(bool(initialized.get("ok", false)), "default initialization succeeds")
	_check(store == StateScript.default_state(), "default is explicit and contains no strategy policy")
	var snapshot := ApplicationScript.snapshot(store)
	var value := snapshot.get("value", {}) as Dictionary
	(value["auto_battle_rules"] as Dictionary)["changed"] = true
	_check((store["auto_battle_rules"] as Dictionary).is_empty(), "snapshot is deeply cloned")
	var valid := {
		"auto_battle_enabled": true,
		"auto_battle_preset": "aggressive",
		"auto_battle_rules": RulesScript.with_config("aggressive", [], {}),
	}
	_check(bool(ApplicationScript.commit(store, valid).get("ok", false)), "valid state commits")
	(valid["auto_battle_rules"] as Dictionary)["preset"] = "balanced"
	_check(str((store["auto_battle_rules"] as Dictionary).get("preset", "")) == "aggressive", "commit is deeply cloned")
	var before := store.duplicate(true)
	_check_invalid(store, {"auto_battle_enabled": "true", "auto_battle_preset": "balanced", "auto_battle_rules": {}}, "invalid enabled type is atomic")
	_check_invalid(store, {"auto_battle_enabled": false, "auto_battle_preset": "balanced", "auto_battle_rules": {"policy": "bad"}}, "invalid rules are atomic")
	_check(store == before, "invalid commits preserve savedata")
	if not _failures.is_empty():
		for failure in _failures: push_error(failure)
		quit(1)
		return
	print("PASS: auto battle state application ownership")
	quit(0)


func _check_invalid(store: Dictionary, candidate: Dictionary, message: String) -> void:
	Engine.print_error_messages = false
	var result := ApplicationScript.commit(store, candidate)
	Engine.print_error_messages = true
	_check(not bool(result.get("ok", true)), message)


func _check(condition: bool, message: String) -> void:
	if not condition: _failures.append(message)
