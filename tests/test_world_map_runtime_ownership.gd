extends SceneTree

const WORLD_MAP_SCENE_PATH := "res://scenes/map/map.tscn"
const GameSessionScript := preload("res://scripts/sim/game_state.gd")
const GameSessionHostScript := preload("res://scripts/app/game_session_host.gd")


class TutorialFixture extends Node:
	func is_waiting_for_any(_event_ids: Array) -> bool:
		return false

	func game_event(_event_id: String) -> void:
		pass


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var store := root.get_node("DataStore")
	var game_state := GameSessionScript.new()
	root.add_child(game_state)
	game_state.bind_store(store)
	game_state.bind_scene_manager(root.get_node("SceneManager"))
	var game_host := GameSessionHostScript.new()
	game_host.bind_session(game_state)
	var tutorial := TutorialFixture.new()
	var original_savedata: Dictionary = store.savedata.duplicate(true)
	var original_rundata: Dictionary = store.rundata.duplicate(true)
	store.reset_rundata()
	assert(not store.rundata.has("map"))

	var map_state: Dictionary = game_state.map_data()
	map_state["discovered_regions"] = ["qinglan_mountain"]
	map_state["discovered_locations"] = ["wild_wolf_valley"]
	store.savedata["map"] = map_state

	var world_map_scene: PackedScene = load(WORLD_MAP_SCENE_PATH)
	assert(world_map_scene != null)
	var controller := world_map_scene.instantiate()
	controller.bind_game_session_host(game_host)
	controller.bind_tutorial_coordinator(tutorial)
	root.add_child(controller)
	await process_frame
	assert(not store.rundata.has("map"))

	controller.select_city("qingshi_market")
	assert(str(controller.get("_selected_city_id")) == "qingshi_market")
	controller.get_node("CityDetailPopup").emit_signal("closed")
	assert(str(controller.get("_selected_city_id")) == "")

	controller.select_wilderness("qinglan_mountain")
	assert(str(controller.get("_selected_region_id")) == "qinglan_mountain")
	controller.get_node("WildernessDetailPopup").emit_signal("closed")
	assert(str(controller.get("_selected_region_id")) == "")

	controller.select_wilderness_location("wild_wolf_valley")
	assert(str(controller.get("_selected_location_id")) == "wild_wolf_valley")
	controller.get_node("WildernessLocationDetailPopup").emit_signal("closed")
	assert(str(controller.get("_selected_location_id")) == "")

	var travelled_to := [""]
	controller.city_travel_requested.connect(func(city_id: String): travelled_to[0] = city_id)
	controller.request_travel("qingshi_market")
	assert(str(travelled_to[0]) == "qingshi_market")
	assert((controller.get("_pending_travel") as Dictionary).is_empty())
	assert(not store.rundata.has("map"))

	controller.queue_free()
	await process_frame
	store.savedata = original_savedata
	store.rundata = original_rundata
	game_state.queue_free()
	game_host.free()
	tutorial.free()
	print("PASS: world map runtime is owned by the controller")
	quit(0)
