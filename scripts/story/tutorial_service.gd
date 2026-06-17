extends Node

const STORY_ID := "prologue_tutorial"
const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"


func _ready() -> void:
	StoryDirector.story_finished.connect(_on_story_finished)
	get_tree().scene_changed.connect(_on_scene_changed)
	call_deferred("_ensure_started")


func game_event(event_id: String) -> void:
	if not is_active() or not StoryDirector.is_waiting_for(event_id):
		return
	_set_step_for_event(event_id)
	if event_id == "tutorial.first_battle_won" and ExpeditionState != null:
		ExpeditionState.auto_advance = false
	StoryDirector.notify_game_event(event_id)


func is_active() -> bool:
	var tutorial := DataStore.savedata.get("tutorial", {}) as Dictionary
	return not bool(tutorial.get("completed", false)) and not bool(tutorial.get("skipped", false))


func _ensure_started() -> void:
	if _is_main_menu_scene():
		return
	if is_active() and not StoryDirector.is_active():
		StoryDirector.start_story(STORY_ID)


func _is_main_menu_scene() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path == MAIN_MENU_SCENE


func _on_scene_changed() -> void:
	call_deferred("_ensure_started")


func _on_story_finished(story_id: String, result: String) -> void:
	if story_id != STORY_ID:
		return
	var tutorial := DataStore.savedata.get("tutorial", {}) as Dictionary
	tutorial["step"] = "T10"
	tutorial["completed"] = result == "completed"
	tutorial["skipped"] = result == "skipped"
	DataStore.savedata["tutorial"] = tutorial


func _set_step_for_event(event_id: String) -> void:
	var steps := {
		"tutorial.cultivation_panel_opened": "T01",
		"tutorial.cultivation_started": "T01",
		"tutorial.cultivation_result_shown": "T02",
		"tutorial.cultivation_completed": "T02",
		"tutorial.pill_mode_selected": "T02",
		"tutorial.alchemy_opened": "T09",
		"tutorial.alchemy_notes_backpack_opened": "T09",
		"tutorial.alchemy_notes_item_opened": "T09",
		"tutorial.alchemy_notes_used": "T09",
		"tutorial.alchemy_recipe_selected": "T09",
		"tutorial.alchemy_preview_acknowledged": "T09",
		"tutorial.alchemy_started": "T09",
		"tutorial.alchemy_result_shown": "T10",
		"tutorial.alchemy_completed": "T10",
		"tutorial.attributes_opened": "T03",
		"tutorial.attributes_closed": "T03",
		"tutorial.world_map_opened": "T04",
		"tutorial.wolf_valley_selected": "T04",
		"tutorial.expedition_started": "T05",
		"tutorial.first_battle_won": "T07",
		"tutorial.expedition_returned": "T08",
		"tutorial.result_closed": "T09",
		"tutorial.backpack_opened": "T10",
	}
	if not steps.has(event_id):
		return
	var tutorial := DataStore.savedata.get("tutorial", {}) as Dictionary
	tutorial["step"] = steps[event_id]
	var flags := tutorial.get("flags", {}) as Dictionary
	flags[event_id] = true
	tutorial["flags"] = flags
	DataStore.savedata["tutorial"] = tutorial
