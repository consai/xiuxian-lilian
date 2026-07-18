extends SceneTree

const ApplicationScript := preload("res://scripts/features/character/application/character_vitals_application.gd")

var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var store := {}
	_check(bool(ApplicationScript.initialize_default(store).get("ok", false)), "default initialization succeeds")
	_check(store == {"attrs": {}, "hp": 1000.0, "mp": 1000.0}, "defaults preserve legacy values")
	var snapshot := ApplicationScript.snapshot(store)
	var value := snapshot.get("value", {}) as Dictionary
	(value["attrs"] as Dictionary)["attack"] = 42.0
	_check((store["attrs"] as Dictionary).is_empty(), "snapshot is deeply cloned")
	_check(bool(ApplicationScript.commit(store, value).get("ok", false)), "valid state commits")
	var before := store.duplicate(true)
	Engine.print_error_messages = false
	var invalid := ApplicationScript.commit(store, {"attrs": {}, "hp": -1.0, "mp": 1.0})
	Engine.print_error_messages = true
	_check(not bool(invalid.get("ok", true)), "negative vitals reject")
	_check(store == before, "invalid commit is atomic")
	if not _failures.is_empty():
		for failure in _failures:
			push_error(failure)
		quit(1)
		return
	print("PASS: character vitals application ownership")
	quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
