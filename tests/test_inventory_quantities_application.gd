extends SceneTree

const ApplicationScript := preload("res://scripts/features/inventory/application/inventory_quantities_application.gd")
const GameSessionScript := preload("res://scripts/sim/game_state.gd")

var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var store := {}
	_check(bool(ApplicationScript.initialize_default(store).get("ok", false)), "default initialization succeeds")
	_check(store == {"inventory": {}, "storage": {}}, "defaults are feature owned")
	var snapshot := ApplicationScript.snapshot(store)
	var value := snapshot.get("value", {}) as Dictionary
	(value["inventory"] as Dictionary)["items_LingCao"] = 2
	_check((store["inventory"] as Dictionary).is_empty(), "snapshot is deeply cloned")
	_check(bool(ApplicationScript.commit(store, value).get("ok", false)), "valid state commits")
	var before := store.duplicate(true)
	Engine.print_error_messages = false
	var invalid := ApplicationScript.commit(store, {"inventory": {"items_LingCao": -1}, "storage": {}})
	Engine.print_error_messages = true
	_check(not bool(invalid.get("ok", true)), "negative count rejects")
	_check(store == before, "invalid commit is atomic")
	var game_state := GameSessionScript.new()
	root.add_child(game_state)
	game_state.bind_store(root.get_node("DataStore"))
	game_state.bind_scene_manager(root.get_node("SceneManager"))
	game_state.inventory = {"items_HuiQiDan": 1}
	_check(game_state._consume_inventory_item("items_HuiQiDan", 1), "GameState item consumption path commits")
	_check(int(game_state.inventory.get("items_HuiQiDan", 0)) == 0, "GameState consumption persists")
	game_state.queue_free()
	if not _failures.is_empty():
		for failure in _failures:
			push_error(failure)
		quit(1)
		return
	print("PASS: inventory quantities application ownership")
	quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
