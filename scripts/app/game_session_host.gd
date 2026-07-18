class_name GameSessionHost
extends Node

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
