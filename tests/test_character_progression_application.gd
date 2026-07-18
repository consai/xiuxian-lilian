extends SceneTree

const ApplicationScript := preload("res://scripts/features/character/application/character_progression_application.gd")

var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var store := {}
	var initialized := ApplicationScript.initialize_default(store)
	_check(bool(initialized.get("ok", false)), "default initialization succeeds")
	_check(int(store.get("day", 0)) == 1, "default day remains one")
	var snapshot := ApplicationScript.snapshot(store)
	var value := snapshot.get("value", {}) as Dictionary
	value["cultivation"] = 50
	_check(int(store.get("cultivation", -1)) == 0, "snapshot is deeply cloned")
	_check(bool(ApplicationScript.commit(store, value).get("ok", false)), "valid state commits")
	var before := store.duplicate(true)
	Engine.print_error_messages = false
	var invalid := ApplicationScript.commit(store, {"day": 0})
	Engine.print_error_messages = true
	_check(not bool(invalid.get("ok", true)), "partial invalid state rejects")
	_check(store == before, "invalid commit is atomic")
	if not _failures.is_empty():
		for failure in _failures:
			push_error(failure)
		quit(1)
		return
	print("PASS: character progression application ownership")
	quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
