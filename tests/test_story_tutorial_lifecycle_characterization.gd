extends SceneTree

const StoryCatalogScript := preload("res://scripts/story/story_catalog.gd")
const StoryApplicationScript := preload("res://scripts/features/story/application/story_application.gd")
const TutorialApplicationScript := preload(
	"res://scripts/features/tutorial/application/tutorial_application.gd"
)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var story := StoryCatalogScript.load_story("prologue_tutorial")
	assert(story["schema_version"] is int)
	assert(story["schema_version"] == 1)
	assert(story["id"] == "prologue_tutorial")
	assert(story["entry"] == "empty_cave")
	assert(story["nodes"] is Dictionary)
	var nodes := story["nodes"] as Dictionary
	assert(not (nodes["empty_cave"] as Dictionary).has("speaker"))
	assert((nodes["open_pill_cultivation"] as Dictionary)["commands"] is Array)

	var data_store := root.get_node("DataStore")
	var scene_manager := root.get_node("SceneManager")
	assert(root.get_node_or_null("StoryDirector") == null)
	var app_root: Node = load("res://scenes/app/app_root.tscn").instantiate()
	root.add_child(app_root)
	var game_state: Node = app_root.get_node("GameSessionHost/GameSession")
	var story_director: Node = app_root.get_node("StoryDirector")
	var tutorial_coordinator: Node = app_root.get_node("TutorialCoordinator")
	var gm_panel_host: Node = app_root.get_node("GmPanelHost")
	var story_application := StoryApplicationScript.new()
	story_application.bind_store(data_store)
	var tutorial_application := TutorialApplicationScript.new()
	tutorial_application.bind_store(data_store)
	assert(app_root.find_children("StoryDirector", "Node").size() == 1)
	assert(tutorial_coordinator != null)
	assert(tutorial_coordinator != null)
	assert(gm_panel_host.tutorial_coordinator() == tutorial_coordinator)
	assert(not story_director.is_active())
	assert(bool(scene_manager.go_to(scene_manager.WORLD_MAP).get("ok", false)))
	var world_map: Node = scene_manager.get_active_scene()
	assert(world_map.tutorial_coordinator() == tutorial_coordinator)
	game_state.new_game({"player_name": "剧情生命周期"})
	story_director.skip_active()

	var started: Dictionary = story_director.start_story("prologue_tutorial")
	assert(bool(started.get("ok", false)))
	story_director._on_advance_requested()
	story_director._on_advance_requested()
	story_director._on_advance_requested()
	assert(story_director.is_waiting_for("tutorial.xiulian_mianban_opened"))

	var snapshot_before: Dictionary = story_application.session_snapshot()["active_snapshot"]
	assert(bool(scene_manager.go_to(scene_manager.MAIN_MENU, {}, {"reset_history": true}).get("ok", false)))
	assert(bool(scene_manager.go_to(scene_manager.CHARACTER_CREATION).get("ok", false)))
	assert(story_director.is_waiting_for("tutorial.xiulian_mianban_opened"))
	assert(story_application.session_snapshot()["active_snapshot"] == snapshot_before)
	app_root.free()
	app_root = load("res://scenes/app/app_root.tscn").instantiate()
	root.add_child(app_root)
	story_director = app_root.get_node("StoryDirector")
	tutorial_coordinator = app_root.get_node("TutorialCoordinator")
	assert(tutorial_coordinator != null)
	assert(story_director.is_waiting_for("tutorial.xiulian_mianban_opened"))
	assert(story_application.session_snapshot()["active_snapshot"] == snapshot_before)

	tutorial_coordinator.game_event("tutorial.xiulian_mianban_opened")
	assert(story_director.is_waiting_for("tutorial.pill_mode_selected"))
	var tutorial: Dictionary = tutorial_application.snapshot()
	assert(tutorial["step"] == "T01")
	assert(bool((tutorial["flags"] as Dictionary)["tutorial.xiulian_mianban_opened"]))

	var before_failed_load: Dictionary = data_store.export_savedata()
	var missing_story := before_failed_load.duplicate(true)
	missing_story.erase("story")
	Engine.print_error_messages = false
	assert(not game_state.apply_dict(missing_story))
	assert(story_director.is_waiting_for("tutorial.pill_mode_selected"))
	assert(data_store.export_savedata() == before_failed_load)
	var invalid_story := before_failed_load.duplicate(true)
	invalid_story["story"] = (invalid_story["story"] as Dictionary).duplicate(true)
	invalid_story["story"]["completed"] = "bad"
	assert(not game_state.apply_dict(invalid_story))
	assert(story_director.is_waiting_for("tutorial.pill_mode_selected"))
	assert(data_store.export_savedata() == before_failed_load)
	var missing_tutorial := before_failed_load.duplicate(true)
	missing_tutorial.erase("tutorial")
	assert(not game_state.apply_dict(missing_tutorial))
	assert(story_director.is_waiting_for("tutorial.pill_mode_selected"))
	assert(data_store.export_savedata() == before_failed_load)
	var invalid_tutorial := before_failed_load.duplicate(true)
	invalid_tutorial["tutorial"] = (invalid_tutorial["tutorial"] as Dictionary).duplicate(true)
	invalid_tutorial["tutorial"]["seen_context_tips"] = [1]
	assert(not game_state.apply_dict(invalid_tutorial))
	Engine.print_error_messages = true
	assert(story_director.is_waiting_for("tutorial.pill_mode_selected"))
	assert(data_store.export_savedata() == before_failed_load)

	var valid_load := before_failed_load.duplicate(true)
	story_director.skip_active()
	assert(not story_director.is_active())
	assert(game_state.apply_dict(valid_load))
	assert(story_director.is_waiting_for("tutorial.pill_mode_selected"))

	data_store.reset_all()
	assert(not story_director.is_active())
	game_state.new_game({"player_name": "剧情重置"})
	assert(not story_director.is_active())

	story_director.skip_active()
	print("PASS: story/tutorial lifecycle characterization")
	quit(0)
