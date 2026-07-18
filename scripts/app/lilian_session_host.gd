class_name LilianSessionHost
extends Node

## AppRoot owns the explicit dependency used by Lilian scenes during the
## migration away from the LilianState Autoload.
var _session: Node


func bind_session(session: Node) -> void:
	if session == null:
		push_error("LilianSessionHost: session 未注入")
		return
	_session = session


func session() -> Node:
	if _session == null:
		push_error("LilianSessionHost: session 未注入")
	return _session
