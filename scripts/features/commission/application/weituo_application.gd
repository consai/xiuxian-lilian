extends RefCounted
## 委托应用边界：组装长期状态与 GameState，并统一编排榜单和存档副作用。

const SELF_PATH := "res://scripts/features/commission/application/weituo_application.gd"
const WeituoServiceScript := preload("res://scripts/sim/weituo_service.gd")

var _store: Node
var _game_state: Node


static func production() -> RefCounted:
	var application_script := load(SELF_PATH) as GDScript
	return application_script.new(DataStore, GameState) as RefCounted


func _init(store: Node, game_state: Node) -> void:
	_store = store
	_game_state = game_state


func refresh_board_snapshot(entries_override: Array = []) -> Dictionary:
	var savedata := _savedata()
	if savedata.is_empty():
		return {"ok": false, "entries": [], "header": {}, "error": "委托状态存储无效"}
	var refreshed := WeituoServiceScript.refresh_board_if_needed(savedata, _game_state)
	if not bool(refreshed.get("ok", false)):
		return {
			"ok": false,
			"entries": [],
			"header": {},
			"error": str(refreshed.get("error", "委托榜单刷新失败")),
		}
	var entries: Array = (
		entries_override.duplicate(true)
		if not entries_override.is_empty()
		else WeituoServiceScript.visible_entries(savedata, _game_state)
	)
	var header := WeituoServiceScript.refresh_header(savedata)
	return {
		"ok": true,
		"entries": entries.duplicate(true),
		"header": header.duplicate(true),
	}


func accept(weituo_id: String) -> Dictionary:
	var savedata := _savedata()
	if savedata.is_empty():
		return {"ok": false, "error": "委托状态存储无效"}
	var result := WeituoServiceScript.accept(weituo_id, savedata, _game_state)
	if bool(result.get("ok", false)):
		_request_auto_save()
	return result.duplicate(true)


func submit(instance_id: String) -> Dictionary:
	var savedata := _savedata()
	if savedata.is_empty():
		return {"ok": false, "error": "委托状态存储无效", "missing": []}
	return WeituoServiceScript.submit(instance_id, savedata, _game_state).duplicate(true)


func abandon(instance_id: String) -> Dictionary:
	var savedata := _savedata()
	if savedata.is_empty():
		return {"ok": false, "error": "委托状态存储无效"}
	var result := WeituoServiceScript.abandon(instance_id, savedata)
	if bool(result.get("ok", false)):
		_request_auto_save()
	return result.duplicate(true)


func _request_auto_save() -> void:
	if _game_state == null:
		push_error("[weituo_application:missing_game_state] action=auto_save")
		return
	_game_state.call("auto_save")


func _savedata() -> Dictionary:
	if _store == null or not "savedata" in _store:
		push_error("[weituo_application:invalid_store] field=savedata")
		return {}
	var value: Variant = _store.savedata
	if not value is Dictionary:
		push_error("[weituo_application:invalid_savedata] expected=Dictionary")
		return {}
	return value as Dictionary
