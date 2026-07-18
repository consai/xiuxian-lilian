extends SceneTree

const StateScript := preload("res://scripts/features/inventory/domain/inventory_equip_state.gd")
const ApplicationScript := preload(
	"res://scripts/features/inventory/application/inventory_equip_application.gd"
)
const GameSessionScript := preload("res://scripts/sim/game_state.gd")

var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var store := {}
	_check(bool(ApplicationScript.initialize_default(store).get("ok", false)), "default initialization succeeds")
	_check(store == StateScript.default_state(), "default state is explicit")
	var snapshot := ApplicationScript.snapshot(store).get("value", {}) as Dictionary
	(snapshot["owned_equips"] as Array).append(11)
	_check((store["owned_equips"] as Array).is_empty(), "snapshot deep clones")
	var candidate := StateScript.default_state()
	candidate["owned_equips"] = [11]
	candidate["equip_slots"] = [11, -1, -1]
	_check(bool(ApplicationScript.commit(store, candidate).get("ok", false)), "valid commit succeeds")
	(candidate["owned_equips"] as Array).append(12)
	_check((store["owned_equips"] as Array) == [11], "commit deep clones")
	var before := store.duplicate(true)
	_check_invalid(store, {"owned_equips": [], "equip_slots": [-1, -1, -1]}, "partial state rejects atomically")
	var invalid := StateScript.default_state()
	invalid["equip_slots"] = [99, -1, -1]
	_check_invalid(store, invalid, "unowned slot rejects atomically")
	_check(store == before, "invalid commits preserve savedata")
	_check_game_state_write()
	if not _failures.is_empty():
		for failure in _failures:
			push_error(failure)
		quit(1)
		return
	print("PASS: inventory equip application ownership")
	quit(0)


func _check_game_state_write() -> void:
	var data_store := root.get_node_or_null("DataStore")
	var game_state := GameSessionScript.new()
	root.add_child(game_state)
	game_state.bind_store(data_store)
	game_state.bind_scene_manager(root.get_node("SceneManager"))
	if data_store == null or game_state == null:
		_failures.append("DataStore 与游戏会话可用")
		return
	var original := ApplicationScript.snapshot(data_store.savedata)
	if not bool(original.get("ok", false)):
		_failures.append("GameState savedata slice is available")
		return
	var state := StateScript.default_state()
	state["owned_equips"] = [1]
	_check(bool(ApplicationScript.commit(data_store.savedata, state).get("ok", false)), "GameState setup succeeds")
	var assigned: Dictionary = game_state.assign_equip_slot(0, 1) as Dictionary
	_check(bool(assigned.get("ok", false)), "GameState equip write succeeds")
	_check((game_state.to_dict().get("equip_slots", []) as Array)[0] == 1, "GameState write persists")
	ApplicationScript.commit(data_store.savedata, original.get("value", {}) as Dictionary)
	game_state.queue_free()


func _check_invalid(store: Dictionary, candidate: Dictionary, message: String) -> void:
	Engine.print_error_messages = false
	var result := ApplicationScript.commit(store, candidate)
	Engine.print_error_messages = true
	_check(not bool(result.get("ok", true)), message)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
