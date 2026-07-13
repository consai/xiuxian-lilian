extends Node
## 剧情编排层：连接 StoryPlayer、剧情 UI、DataStore 快照和外部游戏事件。

signal story_finished(story_id: String, result: String)

const StoryPlayerScript := preload("res://scripts/story/story_player.gd")
const StoryCatalogScript := preload("res://scripts/story/story_catalog.gd")

var _player = StoryPlayerScript.new()
var _presenter: StoryPlaybackPresenter
var _story_id := ""
var _waiting_event := ""


func bind_presenter(presenter: StoryPlaybackPresenter) -> void:
	_presenter = presenter
	_presenter.advance_requested.connect(_on_advance_requested)
	_presenter.choice_requested.connect(_on_choice_requested)
	_presenter.skip_requested.connect(skip_active)
	_presenter.hide_all()
	_restore_active()


func start_story(story_id: String, initial_state: Dictionary = {}) -> Dictionary:
	var story := _load_story(story_id)
	if story.is_empty():
		return {"ok": false, "error": "unknown_story:%s" % story_id}
	var loaded: Dictionary = _player.load_story(story, initial_state)
	if not bool(loaded.get("ok", false)):
		return loaded
	_story_id = story_id
	_waiting_event = ""
	DataStore.story_runtime()["pending_event"] = ""
	return _consume(_player.start())


func notify_game_event(event_id: String) -> void:
	if event_id == "" or event_id != _waiting_event:
		return
	_waiting_event = ""
	DataStore.story_runtime()["pending_event"] = ""
	_consume(_player.advance())


func skip_active() -> void:
	if _story_id == "":
		return
	_finish("skipped")


func is_active() -> bool:
	return _story_id != ""


func get_active_story_id() -> String:
	return _story_id


func is_waiting_for(event_id: String) -> bool:
	return _story_id != "" and _waiting_event == event_id


func _on_advance_requested() -> void:
	if _waiting_event == "":
		_consume(_player.advance())


func _on_choice_requested(choice_id: String) -> void:
	_consume(_player.select_choice(choice_id))


func _consume(frame: Dictionary) -> Dictionary:
	if not bool(frame.get("ok", false)):
		push_warning("StoryDirector: %s" % str(frame.get("error", "unknown_error")))
		return frame
	_save_snapshot()
	# command 节点可能连续推进，所以统一从这里递归消费下一帧。
	match str(frame.get("type", "")):
		"line", "choice":
			_presenter.show_frame(frame)
		"command":
			_consume_commands(frame.get("commands", []) as Array)
		"end":
			_finish(str(frame.get("result", "completed")))
	return frame


func _consume_commands(commands: Array) -> void:
	var target := ""
	var reason := ""
	for command_v in commands:
		if not command_v is Dictionary:
			continue
		var command := command_v as Dictionary
		match str(command.get("type", "")):
			"guide_focus":
				target = str(command.get("target", ""))
				reason = str(command.get("reason", ""))
			"await_game_event":
				_waiting_event = str(command.get("event", ""))
	# 引导遮罩与等待事件可以共存：遮罩先展示，流程停在 pending_event。
	if target != "":
		_presenter.show_guide(target, reason)
	elif _waiting_event != "":
		_presenter.clear_guide()
	if _waiting_event != "":
		DataStore.story_runtime()["pending_event"] = _waiting_event
		_save_snapshot()
	else:
		_consume(_player.advance())


func _finish(result: String) -> void:
	var finished_id := _story_id
	var story_savedata := DataStore.savedata.get("story", {}) as Dictionary
	var completed := story_savedata.get("completed", []) as Array
	if result == "completed" and not completed.has(finished_id):
		completed.append(finished_id)
	story_savedata["completed"] = completed
	story_savedata["history"] = _player.snapshot().get("history", [])
	DataStore.savedata["story"] = story_savedata
	DataStore.story_runtime()["active_snapshot"] = {}
	story_savedata["active_snapshot"] = {}
	DataStore.savedata["story"] = story_savedata
	DataStore.story_runtime()["pending_event"] = ""
	_story_id = ""
	_waiting_event = ""
	_presenter.hide_all()
	story_finished.emit(finished_id, result)


func _save_snapshot() -> void:
	if _story_id == "":
		return
	var snapshot: Dictionary = _player.snapshot()
	snapshot["story_file_id"] = _story_id
	DataStore.story_runtime()["active_snapshot"] = snapshot
	var story_savedata := DataStore.savedata.get("story", {}) as Dictionary
	story_savedata["active_snapshot"] = snapshot.duplicate(true)
	DataStore.savedata["story"] = story_savedata


func _restore_active() -> void:
	var snapshot_v: Variant = DataStore.story_runtime().get("active_snapshot", {})
	if not snapshot_v is Dictionary or (snapshot_v as Dictionary).is_empty():
		# 切场景优先读 rundata，读档/重启时再回退到 savedata。
		snapshot_v = (DataStore.savedata.get("story", {}) as Dictionary).get("active_snapshot", {})
	if not snapshot_v is Dictionary or (snapshot_v as Dictionary).is_empty():
		return
	var snapshot := snapshot_v as Dictionary
	var file_id := str(snapshot.get("story_file_id", ""))
	var story := _load_story(file_id)
	if story.is_empty() or not bool(_player.restore(story, snapshot).get("ok", false)):
		DataStore.story_runtime()["active_snapshot"] = {}
		return
	_story_id = file_id
	_waiting_event = str(DataStore.story_runtime().get("pending_event", ""))
	if _waiting_event != "":
		_consume_commands((_player.current_frame().get("commands", []) as Array))
	else:
		_consume(_player.current_frame())


func _load_story(story_id: String) -> Dictionary:
	return StoryCatalogScript.load_story(story_id)
