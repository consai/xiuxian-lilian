extends Node
class_name UiDragMove

## 通用窗口拖动：可挂在 [Control] 节点上，或作为子节点挂载并指定 [member target_path]。
## 拖动时约束面板中心点始终在视口内。

signal drag_started
signal drag_ended

@export var target_path: NodePath = NodePath("..")
## 留空则整个 [member target_path] 可拖；可指向标题栏等子节点。
@export var handle_path: NodePath = NodePath("")
@export var drag_button: MouseButton = MOUSE_BUTTON_LEFT
@export_range(0.0, 32.0) var drag_threshold: float = 4.0
@export var clamp_to_viewport: bool = true
## 手柄为 [constant Control.MOUSE_FILTER_IGNORE] 时改为 [constant Control.MOUSE_FILTER_STOP]。
@export var take_mouse_if_ignored: bool = true

var _target: Control
var _handle: Control
var _dragging := false
var _pointer_down := false
var _press_global := Vector2.ZERO
var _drag_offset := Vector2.ZERO


func _ready() -> void:
	_target = _resolve_target()
	if _target == null:
		push_error("UiDragMove: target_path 未指向有效 Control: %s" % str(target_path))
		return
	_handle = _resolve_handle()
	if _handle == null:
		push_error("UiDragMove: handle_path 未指向有效 Control: %s" % str(handle_path))
		return
	if take_mouse_if_ignored and _handle.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		_handle.mouse_filter = Control.MOUSE_FILTER_STOP
	_handle.gui_input.connect(_on_handle_gui_input)
	_target.tree_exited.connect(_on_target_tree_exited)


func _exit_tree() -> void:
	_stop_drag()
	if is_instance_valid(_handle) and _handle.gui_input.is_connected(_on_handle_gui_input):
		_handle.gui_input.disconnect(_on_handle_gui_input)


func _input(event: InputEvent) -> void:
	if not _pointer_down and not _dragging:
		return
	if event is InputEventMouseMotion:
		var pos := (event as InputEventMouseMotion).global_position
		_try_start_drag(pos)
		if _dragging:
			_apply_drag(pos)
	elif event is InputEventScreenDrag:
		var pos := (event as InputEventScreenDrag).position
		_try_start_drag(pos)
		if _dragging:
			_apply_drag(pos)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == drag_button and not mb.pressed:
			_end_pointer(mb.global_position)
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if not st.pressed:
			_end_pointer(st.position)


static func clamp_center_to_viewport(center: Vector2, panel_size: Vector2, viewport: Rect2) -> Vector2:
	var half := panel_size * 0.5
	var out := center
	var min_x := viewport.position.x + half.x
	var max_x := viewport.end.x - half.x
	if max_x < min_x:
		out.x = viewport.position.x + viewport.size.x * 0.5
	else:
		out.x = clampf(center.x, min_x, max_x)
	var min_y := viewport.position.y + half.y
	var max_y := viewport.end.y - half.y
	if max_y < min_y:
		out.y = viewport.position.y + viewport.size.y * 0.5
	else:
		out.y = clampf(center.y, min_y, max_y)
	return out


func _resolve_target() -> Control:
	var path := target_path
	if path == NodePath("..") and is_instance_of(self, Control):
		path = NodePath(".")
	return get_node_or_null(path) as Control


func _resolve_handle() -> Control:
	if handle_path != NodePath(""):
		return get_node_or_null(handle_path) as Control
	return _target


func _on_handle_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != drag_button:
			return
		if mb.pressed:
			_begin_pointer(mb.global_position)
		else:
			_end_pointer(mb.global_position)
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_begin_pointer(st.position)
		else:
			_end_pointer(st.position)
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		_try_start_drag(motion.global_position)
		if _dragging:
			_apply_drag(motion.global_position)


func _begin_pointer(global_pos: Vector2) -> void:
	_pointer_down = true
	_press_global = global_pos
	_drag_offset = _target.global_position - global_pos
	set_process_input(true)


func _end_pointer(global_pos: Vector2) -> void:
	if _dragging:
		_apply_drag(global_pos)
	_stop_drag()


func _try_start_drag(global_pos: Vector2) -> void:
	if _dragging or not _pointer_down:
		return
	if global_pos.distance_to(_press_global) < drag_threshold:
		return
	_dragging = true
	set_process_input(true)
	drag_started.emit()


func _apply_drag(global_pos: Vector2) -> void:
	if not is_instance_valid(_target):
		_stop_drag()
		return
	_try_start_drag(global_pos)
	if not _dragging:
		return
	var next_pos := global_pos + _drag_offset
	if clamp_to_viewport:
		next_pos = _clamp_global_position(next_pos)
	_target.global_position = next_pos


func _clamp_global_position(top_left: Vector2) -> Vector2:
	var old_pos := _target.global_position
	_target.global_position = top_left
	var rect := _target.get_global_rect()
	_target.global_position = old_pos
	var viewport := _target.get_viewport().get_visible_rect()
	var clamped_center := clamp_center_to_viewport(rect.get_center(), rect.size, viewport)
	return top_left + (clamped_center - rect.get_center())


func _stop_drag() -> void:
	var was_dragging := _dragging
	_dragging = false
	_pointer_down = false
	set_process_input(false)
	if was_dragging:
		drag_ended.emit()


func _on_target_tree_exited() -> void:
	_stop_drag()
