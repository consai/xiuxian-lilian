extends SceneTree

const StateScript := preload("res://scripts/features/lilian/domain/lilian_totals_state.gd")
const ApplicationScript := preload("res://scripts/features/lilian/application/lilian_totals_application.gd")

var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var store := {}
	_check(bool(ApplicationScript.initialize_default(store).get("ok", false)), "default initialization succeeds")
	_check(store["totals"] == StateScript.default_state(), "default is explicit")
	var read := ApplicationScript.snapshot(store).get("value", {}) as Dictionary
	read["wins"] = 9
	_check(int((store["totals"] as Dictionary)["wins"]) == 0, "snapshot deep clones")
	var candidate := StateScript.default_state()
	(candidate as Dictionary)["battles"] = 2
	_check(bool(ApplicationScript.commit(store, candidate).get("ok", false)), "valid commit succeeds")
	candidate["battles"] = 3
	_check(int((store["totals"] as Dictionary)["battles"]) == 2, "commit deep clones")
	var before := store.duplicate(true)
	Engine.print_error_messages = false
	_check(not bool(ApplicationScript.commit(store, {"battles": 0}).get("ok", true)), "invalid rejects")
	_check(not bool(ApplicationScript.commit(store, {"battles": -1, "wins": 0, "losses": 0, "items_gained": 0, "lilian_count": 0, "lilian_steps": 0, "max_difficulty": 0}).get("ok", true)), "negative rejects")
	Engine.print_error_messages = true
	_check(store == before, "invalid commits are atomic")
	if not _failures.is_empty():
		for failure in _failures: push_error(failure)
		quit(1)
		return
	print("PASS: lilian totals application ownership")
	quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition: _failures.append(message)
