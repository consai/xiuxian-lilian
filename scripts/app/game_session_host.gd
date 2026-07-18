class_name GameSessionHost
extends Node

const SaveApplicationScript := preload("res://scripts/core/save_application.gd")

## AppRoot owns the explicit game-session dependency used while GameState
## callers are migrated away from the Autoload boundary.
var _session: Node


func bind_session(session: Node) -> void:
	if session == null:
		push_error("GameSessionHost: session 未注入")
		return
	_session = session


func session() -> Node:
	if _session == null:
		push_error("GameSessionHost: session 未注入")
	return _session


func continue_game() -> Dictionary:
	if _session == null:
		push_error("GameSessionHost: session 未注入")
		return {"ok": false, "error": "游戏会话未注入"}
	var loaded := SaveApplicationScript.load_auto()
	if not bool(loaded.get("ok", false)):
		return loaded
	if not _session.can_persist():
		return {"ok": false, "error": "历练中无法继续游戏"}
	if not _session.apply_dict(loaded.get("game", {}) as Dictionary):
		return {"ok": false, "error": "自动存档数据无效"}
	return {"ok": true}
