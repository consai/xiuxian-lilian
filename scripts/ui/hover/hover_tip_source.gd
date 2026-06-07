extends Node
class_name HoverTipSource

## 通用 Hover 触发器：挂在任意 [Control] 下，鼠标悬停时向 [HoverTipHost] 请求展示 tip。
## [member payload_provider] 优先于静态 [member payload]；返回空载荷时不展示。

@export var target_path: NodePath = NodePath("..")
@export var enabled: bool = true
@export_range(0, 2000, 1) var show_delay_ms: int = 280
@export_range(0, 2000, 1) var hide_delay_ms: int = 80

var payload: Dictionary = {}
var payload_provider: Callable = Callable()

var _target: Control
var _hover_depth: int = 0


func _ready() -> void:
	_target = get_node_or_null(target_path) as Control
	if _target == null:
		push_error("HoverTipSource: target_path 未指向有效 Control: %s" % str(target_path))
		return
	if not _target.mouse_entered.is_connected(_on_mouse_entered):
		_target.mouse_entered.connect(_on_mouse_entered)
	if not _target.mouse_exited.is_connected(_on_mouse_exited):
		_target.mouse_exited.connect(_on_mouse_exited)


func _exit_tree() -> void:
	if is_instance_valid(_target):
		if _target.mouse_entered.is_connected(_on_mouse_entered):
			_target.mouse_entered.disconnect(_on_mouse_entered)
		if _target.mouse_exited.is_connected(_on_mouse_exited):
			_target.mouse_exited.disconnect(_on_mouse_exited)
	_get_host().hide_for(_target, 0)


func set_payload(next_payload: Dictionary) -> void:
	payload = next_payload.duplicate(true)


func clear_payload() -> void:
	payload = {}
	_hover_depth = 0
	if is_instance_valid(_target):
		_get_host().hide_for(_target, 0)


func set_provider(provider: Callable) -> void:
	payload_provider = provider


func clear_provider() -> void:
	payload_provider = Callable()


func _resolve_payload() -> Dictionary:
	if payload_provider.is_valid():
		var result: Variant = payload_provider.call()
		if result is Dictionary:
			return (result as Dictionary).duplicate(true)
		return {}
	return payload.duplicate(true)


func _on_mouse_entered() -> void:
	if not enabled or _target == null:
		return
	_hover_depth += 1
	var host := _get_host()
	if host == null:
		return
	var resolved := _resolve_payload()
	if HoverTipPayload.is_empty(resolved):
		return
	host.show_for(_target, resolved, show_delay_ms)


func _on_mouse_exited() -> void:
	if _target == null:
		return
	_hover_depth = maxi(_hover_depth - 1, 0)
	if _hover_depth > 0:
		return
	var host := _get_host()
	if host == null:
		return
	host.hide_for(_target, hide_delay_ms)


func _get_host() -> CanvasLayer:
	var host := get_node_or_null("/root/HoverTipHost")
	return host as CanvasLayer if host is CanvasLayer else null
