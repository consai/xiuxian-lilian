extends SceneTree

const SceneManagerScript := preload("res://scripts/core/scene_manager.gd")
const GameSessionScript := preload("res://scripts/sim/game_state.gd")
const GameSessionHostScript := preload("res://scripts/app/game_session_host.gd")
const LilianSessionScript := preload("res://scripts/lilian/lilian_state.gd")
const LilianSessionHostScript := preload("res://scripts/app/lilian_session_host.gd")
const TutorialCoordinatorScript := preload("res://scripts/app/tutorial_coordinator.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager := root.get_node("SceneManager")
	var store := root.get_node("DataStore")
	var game_session := GameSessionScript.new()
	root.add_child(game_session)
	game_session.bind_store(store)
	game_session.bind_scene_manager(manager)
	var game_host := GameSessionHostScript.new()
	game_host.bind_session(game_session)
	var lilian_session := LilianSessionScript.new()
	root.add_child(lilian_session)
	lilian_session.bind_scene_manager(manager)
	var lilian_host := LilianSessionHostScript.new()
	lilian_host.bind_session(lilian_session)
	var tutorial := TutorialCoordinatorScript.new()
	root.add_child(tutorial)
	tutorial.bind_scene_manager(manager)
	tutorial.bind_store(store)
	manager.bind_page_dependencies(game_host, lilian_host, null, tutorial)
	for route_id_v in SceneManagerScript.SCENE_PATHS:
		var route_id := str(route_id_v)
		var path := str(SceneManagerScript.SCENE_PATHS[route_id_v])
		var packed := load(path) as PackedScene
		if packed == null:
			push_error("route %s cannot load %s" % [route_id, path])
			quit(1)
			return
		var scene := packed.instantiate()
		manager.call("_inject_page_dependencies", scene)
		root.add_child(scene)
		await process_frame
		scene.queue_free()
		await process_frame
	game_host.queue_free()
	lilian_host.queue_free()
	tutorial.queue_free()
	game_session.queue_free()
	lilian_session.queue_free()
	await process_frame
	await process_frame
	print("PASS: %d route scenes" % SceneManagerScript.SCENE_PATHS.size())
	quit(0)
