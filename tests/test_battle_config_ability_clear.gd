extends SceneTree

const PANEL_SCENE_PATH := "res://scenes/ui/zhandou_peizhi_mianban.tscn"
const AUTO_SAVE_PATH := "user://save_slot_0.json"
const GameSessionHostScript := preload("res://scripts/app/game_session_host.gd")
const GameSessionScript := preload("res://scripts/sim/game_state.gd")

var _failures: PackedStringArray = []
var _game_state: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_game_state = GameSessionScript.new()
	root.add_child(_game_state)
	_game_state.bind_store(root.get_node("DataStore"))
	_game_state.bind_scene_manager(root.get_node("SceneManager"))
	var game_session_host := GameSessionHostScript.new()
	game_session_host.bind_session(_game_state)
	var save_before := _file_snapshot(AUTO_SAVE_PATH)
	_game_state.unlocked_abilities = ["skill_lq_001", "skill_lq_002"]
	_game_state.equipped_abilities = ["skill_lq_001", "skill_lq_002", "", "", ""]

	var panel := (load(PANEL_SCENE_PATH) as PackedScene).instantiate()
	panel.bind_game_session_host(game_session_host)
	root.add_child(panel)
	await process_frame

	panel.set("_selection_mode", "skill")
	panel.set("_selection_target", 0)
	panel.call("_on_popup_selected", "")
	_check(str(_game_state.equipped_abilities[0]) == "", "empty selection clears the target slot")
	_check(str(_game_state.equipped_abilities[1]) == "skill_lq_002", "empty selection keeps other slots unchanged")
	_check(str(panel.get_node("%StatusLabel").text) == "技能槽已清空。", "successful empty selection reports success")

	panel.set("_selection_target", 3)
	panel.call("_on_popup_selected", -1)
	_check(str(_game_state.equipped_abilities[3]) == "", "integer -1 selection clears the target slot")
	_check(str(_game_state.equipped_abilities[1]) == "skill_lq_002", "integer -1 keeps other slots unchanged")

	var before_invalid: Array = (_game_state.equipped_abilities as Array).duplicate(true)
	panel.set("_selection_target", 7)
	panel.call("_on_popup_selected", "")
	_check(_game_state.equipped_abilities == before_invalid, "invalid target leaves every slot unchanged")
	_check(str(panel.get_node("%StatusLabel").text) == "无法配置该技能", "invalid target reports the application failure")
	_check(_file_snapshot(AUTO_SAVE_PATH) == save_before, "skill clearing does not write the autosave file")

	panel.queue_free()
	_game_state.queue_free()
	game_session_host.queue_free()
	await process_frame
	if not _failures.is_empty():
		for failure in _failures:
			push_error(failure)
		quit(1)
		return
	print("PASS: battle config ability clear")
	quit(0)


func _file_snapshot(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"exists": false}
	var file := FileAccess.open(path, FileAccess.READ)
	return {
		"exists": true,
		"content": file.get_buffer(file.get_length()),
		"modified": FileAccess.get_modified_time(path),
	}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
