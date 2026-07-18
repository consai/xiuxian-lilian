extends SceneTree

const StateScript := preload("res://scripts/features/character/domain/player_journal_state.gd")
const ApplicationScript := preload("res://scripts/features/character/application/player_journal_application.gd")

var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var store := {}
	_check(bool(ApplicationScript.initialize_default(store).get("ok", false)), "default initialization succeeds")
	_check(store["activity_log"] == StateScript.default_state(), "default is explicit")
	var read := ApplicationScript.snapshot(store).get("value", []) as Array
	read.append({"day": 1, "text": "changed"})
	_check((store["activity_log"] as Array).is_empty(), "snapshot deep clones")
	_check(bool(ApplicationScript.append(store, 1, "first").get("ok", false)), "append succeeds")
	_check((store["activity_log"] as Array)[0] == {"day": 1, "text": "first"}, "append preserves entry")
	for index in 30:
		_check(bool(ApplicationScript.append(store, index + 2, "row%d" % index).get("ok", false)), "repeated append succeeds")
	_check((store["activity_log"] as Array).size() == 30, "append caps entries")
	_check(int(((store["activity_log"] as Array)[0] as Dictionary)["day"]) == 2, "append retains newest 30")
	var before := store.duplicate(true)
	Engine.print_error_messages = false
	_check(not bool(ApplicationScript.commit(store, [{"day": 0, "text": "bad"}]).get("ok", true)), "invalid day rejects")
	_check(not bool(ApplicationScript.commit(store, [{"day": 1, "text": "ok", "extra": true}]).get("ok", true)), "unknown entry field rejects")
	Engine.print_error_messages = true
	_check(store == before, "invalid commits are atomic")
	if not _failures.is_empty():
		for failure in _failures: push_error(failure)
		quit(1)
		return
	print("PASS: player journal application ownership")
	quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition: _failures.append(message)
