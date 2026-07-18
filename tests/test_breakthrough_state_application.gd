extends SceneTree

const StateScript := preload("res://scripts/features/cultivation/domain/breakthrough_state.gd")
const ApplicationScript := preload(
	"res://scripts/features/cultivation/application/breakthrough_application.gd"
)

var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var store := {}
	var initialized := ApplicationScript.initialize_default(store)
	_check(bool(initialized.get("ok", false)), "default initialization succeeds")
	_check(store == StateScript.default_state(), "default state is explicit")
	var snapshot := ApplicationScript.snapshot(store)
	var snapshot_value := snapshot.get("value", {}) as Dictionary
	(snapshot_value["breakthrough_bonuses"] as Dictionary)["pills"] = 12
	_check(int((store["breakthrough_bonuses"] as Dictionary)["pills"]) == 0, "snapshot is deeply cloned")
	var valid := StateScript.default_state()
	(valid["realm_quality"] as Dictionary)["zhuji"] = 3
	_check(bool(ApplicationScript.commit(store, valid).get("ok", false)), "valid state commits")
	(valid["realm_quality"] as Dictionary)["zhuji"] = 4
	_check(int((store["realm_quality"] as Dictionary)["zhuji"]) == 3, "commit is deeply cloned")
	var before := store.duplicate(true)
	_check_invalid(store, {"breakthrough_bonuses": {}, "realm_quality": {}, "breakthrough_attempt_cooldown_days": 0}, "missing bonus entries reject atomically")
	_check_invalid(store, {"breakthrough_bonuses": {"pills": -1, "mind": 0, "other": 0}, "realm_quality": {"zhuji": 0, "jindan": 0, "yuanying": 0}, "breakthrough_attempt_cooldown_days": 0}, "negative values reject atomically")
	_check_invalid(store, {"breakthrough_bonuses": {"pills": 0, "mind": 0, "other": 0}, "realm_quality": {"zhuji": 0, "jindan": 0, "yuanying": 0, "unknown": 1}, "breakthrough_attempt_cooldown_days": 0}, "unknown realm rejects atomically")
	_check_invalid(store, {"breakthrough_bonuses": {"pills": 0, "mind": 0, "other": 0}, "realm_quality": {"zhuji": 0, "jindan": 0, "yuanying": 0}, "breakthrough_attempt_cooldown_days": -1}, "negative cooldown rejects atomically")
	_check(store == before, "invalid commits preserve savedata")
	if not _failures.is_empty():
		for failure in _failures:
			push_error(failure)
		quit(1)
		return
	print("PASS: breakthrough state application ownership")
	quit(0)


func _check_invalid(store: Dictionary, candidate: Dictionary, message: String) -> void:
	Engine.print_error_messages = false
	var result := ApplicationScript.commit(store, candidate)
	Engine.print_error_messages = true
	_check(not bool(result.get("ok", true)), message)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
