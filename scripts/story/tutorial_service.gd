extends Node

const STORY_ID := "prologue_tutorial"
const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const TUTORIAL_ENABLED := true


func _ready() -> void:
	StoryDirector.story_finished.connect(_on_story_finished)
	get_tree().scene_changed.connect(_on_scene_changed)
	SceneManager.active_scene_changed.connect(_on_scene_changed)
	call_deferred("_ensure_started")


func game_event(event_id: String) -> void:
	if not is_active():
		return
	# 首战胜利标记决定历练是否仍用新手三节点图，须写入存档，不能仅依赖剧情层是否在等待。
	if event_id == "tutorial.first_battle_won":
		_set_step_for_event(event_id)
		if LilianState != null:
			LilianState.auto_advance = false
	if not StoryDirector.is_waiting_for(event_id):
		return
	_set_step_for_event(event_id)
	StoryDirector.notify_game_event(event_id)


func is_active() -> bool:
	if not TUTORIAL_ENABLED:
		return false
	var tutorial := DataStore.savedata.get("tutorial", {}) as Dictionary
	return not bool(tutorial.get("completed", false)) and not bool(tutorial.get("skipped", false))


## 首次历练路线图：教程未完成且尚未赢下引导战斗时使用固定三节点地图。
func should_use_tutorial_lilian_map() -> bool:
	if not is_active():
		return false
	var flags := (DataStore.savedata.get("tutorial", {}) as Dictionary).get("flags", {}) as Dictionary
	return not bool(flags.get("tutorial.first_battle_won", false))


func is_waiting_for_any(event_ids: Array) -> bool:
	if not is_active():
		return false
	for event_id_v in event_ids:
		if StoryDirector.is_waiting_for(str(event_id_v)):
			return true
	return false


func _ensure_started() -> void:
	if not TUTORIAL_ENABLED:
		_stop_active_tutorial()
		return
	if _is_main_menu_scene():
		return
	if not is_active() or StoryDirector.is_active():
		return
	var started: Dictionary = StoryDirector.start_story(STORY_ID)
	if not bool(started.get("ok", false)):
		push_warning("TutorialService: failed to start %s: %s" % [STORY_ID, str(started.get("error", started.get("errors", "unknown")))])


func _is_main_menu_scene() -> bool:
	var scene := SceneManager.get_active_scene()
	return scene != null and scene.scene_file_path == MAIN_MENU_SCENE


func _stop_active_tutorial() -> void:
	if StoryDirector.has_method("get_active_story_id") and StoryDirector.get_active_story_id() == STORY_ID:
		StoryDirector.skip_active()


func _on_scene_changed(_scene: Node = null) -> void:
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
		"tutorial.xiulian_mianban_opened": "T01",
		"tutorial.cultivation_started": "T01",
		"tutorial.cultivation_result_shown": "T02",
		"tutorial.cultivation_completed": "T02",
		"tutorial.pill_mode_selected": "T02",
		"tutorial.alchemy_opened": "T09",
		"tutorial.alchemy_recipe_selected": "T09",
		"tutorial.alchemy_preview_acknowledged": "T09",
		"tutorial.alchemy_started": "T09",
		"tutorial.alchemy_result_shown": "T09",
		"tutorial.alchemy_completed": "T10",
		"tutorial.attributes_opened": "T03",
		"tutorial.attributes_closed": "T03",
		"tutorial.world_map_opened": "T03",
		"tutorial.wolf_valley_selected": "T04",
		"tutorial.lilian_started": "T04",
		"tutorial.first_battle_won": "T05",
		"tutorial.lilian_returned": "T06",
		"tutorial.result_closed": "T07",
	}
	if not steps.has(event_id):
		return
	var tutorial := DataStore.savedata.get("tutorial", {}) as Dictionary
	tutorial["step"] = steps[event_id]
	var flags := tutorial.get("flags", {}) as Dictionary
	flags[event_id] = true
	tutorial["flags"] = flags
	DataStore.savedata["tutorial"] = tutorial
