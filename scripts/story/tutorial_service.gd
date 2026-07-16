extends Node

const STORY_ID := "prologue_tutorial"
const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const TUTORIAL_ENABLED := true
const StoryDirectorScript := preload("res://scripts/story/story_director.gd")
const TutorialApplicationScript := preload(
	"res://scripts/features/tutorial/application/tutorial_application.gd"
)

var _story_director: StoryDirectorScript
var _application := TutorialApplicationScript.new()
var _store: Node


func _ready() -> void:
	get_tree().scene_changed.connect(_on_scene_changed)
	SceneManager.active_scene_changed.connect(_on_scene_changed)


func bind_store(store: Node) -> void:
	if store == null:
		push_error("TutorialService: Data Store 未绑定")
		return
	if _store != null and _store != store and _store.state_replaced.is_connected(_on_state_replaced):
		_store.state_replaced.disconnect(_on_state_replaced)
	_store = store
	_application.bind_store(_store)
	_application.initialize_missing()
	if not _store.state_replaced.is_connected(_on_state_replaced):
		_store.state_replaced.connect(_on_state_replaced)


func bind_story_director(story_director: StoryDirectorScript) -> void:
	if story_director == null:
		push_error("TutorialService: StoryDirector 未绑定")
		return
	_story_director = story_director
	if not _story_director.story_finished.is_connected(_on_story_finished):
		_story_director.story_finished.connect(_on_story_finished)
	call_deferred("_ensure_started")


func game_event(event_id: String) -> void:
	if not is_active():
		return
	if _story_director == null:
		push_error("TutorialService: StoryDirector 未绑定")
		return
	if event_id == "tutorial.first_battle_won":
		_application.record_game_event(event_id)
	elif not _story_director.is_waiting_for(event_id):
		return
	else:
		_application.record_game_event(event_id)
	if not _story_director.is_waiting_for(event_id):
		return
	_story_director.notify_game_event(event_id)


func is_active() -> bool:
	if not TUTORIAL_ENABLED:
		return false
	return _application.is_active()


func has_event_flag(event_id: String) -> bool:
	return _application.has_event_flag(event_id)


## 首次历练路线图：教程未完成且尚未赢下引导战斗时使用固定三节点地图。
func should_use_tutorial_lilian_map() -> bool:
	return _application.should_use_tutorial_lilian_map()


func is_waiting_for_any(event_ids: Array) -> bool:
	if not is_active():
		return false
	if _story_director == null:
		push_error("TutorialService: StoryDirector 未绑定")
		return false
	for event_id_v in event_ids:
		if _story_director.is_waiting_for(str(event_id_v)):
			return true
	return false


func _ensure_started() -> void:
	if not TUTORIAL_ENABLED:
		_stop_active_tutorial()
		return
	if _is_main_menu_scene():
		return
	if _story_director == null:
		push_error("TutorialService: StoryDirector 未绑定")
		return
	if not is_active() or _story_director.is_active():
		return
	var started: Dictionary = _story_director.start_story(STORY_ID)
	if not bool(started.get("ok", false)):
		push_warning("TutorialService: failed to start %s: %s" % [STORY_ID, str(started.get("error", started.get("errors", "unknown")))])


func _is_main_menu_scene() -> bool:
	var scene := SceneManager.get_active_scene()
	return scene != null and scene.scene_file_path == MAIN_MENU_SCENE


func _stop_active_tutorial() -> void:
	if _story_director != null and _story_director.get_active_story_id() == STORY_ID:
		_story_director.skip_active()


func _on_scene_changed(_scene: Node = null) -> void:
	if _story_director == null:
		return
	call_deferred("_ensure_started")


func _on_story_finished(story_id: String, result: String) -> void:
	if story_id != STORY_ID:
		return
	_application.finish(result == "completed", result == "skipped")


func _on_state_replaced() -> void:
	_application.initialize_missing()
