extends SceneTree

const StateScript := preload("res://scripts/features/inventory/domain/inventory_item_slots_state.gd")
const ApplicationScript := preload("res://scripts/features/inventory/application/inventory_item_slots_application.gd")
const GameSessionScript := preload("res://scripts/sim/game_state.gd")

var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var store := {}
	_check(bool(ApplicationScript.initialize_default(store).get("ok", false)), "default initialization succeeds")
	_check(store == StateScript.default_state(), "default is explicit")
	var snapshot := ApplicationScript.snapshot(store).get("value", {}) as Dictionary
	(snapshot["item_slots"] as Array)[0] = "item.changed"
	_check((store["item_slots"] as Array)[0] == "", "snapshot deep clones")
	var candidate := {"item_slots": ["item.a", "", ""]}
	_check(bool(ApplicationScript.commit(store, candidate).get("ok", false)), "valid commit succeeds")
	(candidate["item_slots"] as Array)[0] = "item.changed"
	_check((store["item_slots"] as Array)[0] == "item.a", "commit deep clones")
	var before := store.duplicate(true)
	Engine.print_error_messages = false
	_check(not bool(ApplicationScript.commit(store, {"item_slots": ["", ""]}).get("ok", true)), "short slots reject")
	_check(not bool(ApplicationScript.commit(store, {"item_slots": ["", "", 1]}).get("ok", true)), "non-string slot rejects")
	Engine.print_error_messages = true
	_check(store == before, "invalid commit is atomic")
	var game_state := GameSessionScript.new()
	root.add_child(game_state)
	game_state.bind_store(root.get_node("DataStore"))
	game_state.bind_scene_manager(root.get_node("SceneManager"))
	game_state.item_slots = ["", "", ""]
	game_state.inventory = {"items_HuiQiDan": 1}
	var assigned: Dictionary = game_state.assign_item_slot(0, "items_HuiQiDan")
	_check(bool(assigned.get("ok", false)), "GameState assignment succeeds")
	_check((game_state.item_slots as Array)[0] == "items_HuiQiDan", "GameState assignment uses application state")
	_check((root.get_node("DataStore").savedata["item_slots"] as Array)[0] == "items_HuiQiDan", "GameState assignment persists")
	game_state.queue_free()
	if not _failures.is_empty():
		for failure in _failures: push_error(failure)
		quit(1)
		return
	print("PASS: inventory item slots application ownership")
	quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition: _failures.append(message)
