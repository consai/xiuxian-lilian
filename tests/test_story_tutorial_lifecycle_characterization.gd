extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var data_store := root.get_node("DataStore")
	var scene_manager := root.get_node("SceneManager")
	var tutorial_service := root.get_node("TutorialService")
	assert(root.get_node_or_null("StoryDirector") == null)
	var app_root: Node = load("res://scenes/app/app_root.tscn").instantiate()
	root.add_child(app_root)
	var story_director: Node = app_root.get_node("StoryDirector")
	assert(app_root.find_children("StoryDirector", "Node").size() == 1)
	data_store.reset_all()
	data_store.start_tutorial()
	story_director.skip_active()

	var started: Dictionary = story_director.start_story("prologue_tutorial")
	assert(bool(started.get("ok", false)))
	story_director._on_advance_requested()
	story_director._on_advance_requested()
	story_director._on_advance_requested()
	assert(story_director.is_waiting_for("tutorial.xiulian_mianban_opened"))

	var snapshot_before: Dictionary = data_store.story_runtime()["active_snapshot"].duplicate(true)
	assert(bool(scene_manager.go_to(scene_manager.MAIN_MENU, {}, {"reset_history": true}).get("ok", false)))
	assert(bool(scene_manager.go_to(scene_manager.CHARACTER_CREATION).get("ok", false)))
	assert(story_director.is_waiting_for("tutorial.xiulian_mianban_opened"))
	assert(data_store.story_runtime()["active_snapshot"] == snapshot_before)
	app_root.free()
	app_root = load("res://scenes/app/app_root.tscn").instantiate()
	root.add_child(app_root)
	story_director = app_root.get_node("StoryDirector")
	assert(story_director.is_waiting_for("tutorial.xiulian_mianban_opened"))
	assert(data_store.story_runtime()["active_snapshot"] == snapshot_before)

	tutorial_service.game_event("tutorial.xiulian_mianban_opened")
	assert(story_director.is_waiting_for("tutorial.pill_mode_selected"))
	var tutorial: Dictionary = data_store.savedata["tutorial"] as Dictionary
	assert(tutorial["step"] == "T01")
	assert(bool((tutorial["flags"] as Dictionary)["tutorial.xiulian_mianban_opened"]))

	story_director.skip_active()
	print("PASS: story/tutorial lifecycle characterization")
	quit(0)
