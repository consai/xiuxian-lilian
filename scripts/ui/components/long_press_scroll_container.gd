class_name LongPressScrollContainer
extends ScrollContainer

## 支持鼠标拖拽（移动阈值）与触屏长按拖拽的滚动容器；通过修改 scroll_* 属性滚动，兼容虚拟列表等逻辑。

signal user_scrolled()

@export var drag_enabled: bool = true
@export var long_press_ms: int = 300
@export var drag_threshold: float = 8.0

var _pointer_down := false
var _dragging := false
var _armed := false
var _press_local := Vector2.ZERO
var _press_scroll := Vector2i.ZERO
var _active_touch_index := -1
var _long_press_generation := 0
var _suppress_scroll_signal := false
var _suppressed_controls: Array[Dictionary] = []


func _ready() -> void:
	_connect_scroll_bars()


func _connect_scroll_bars() -> void:
	var v_bar := get_v_scroll_bar()
	if v_bar != null and not v_bar.value_changed.is_connected(_on_bar_value_changed):
		v_bar.value_changed.connect(_on_bar_value_changed)
	var h_bar := get_h_scroll_bar()
	if h_bar != null and not h_bar.value_changed.is_connected(_on_bar_value_changed):
		h_bar.value_changed.connect(_on_bar_value_changed)


## 经 GUI 输入链接收拖拽，上层遮罩/面板可正常挡住滚动（区别于全局 _input）。
func _gui_input(event: InputEvent) -> void:
	if not drag_enabled:
		return
	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventScreenTouch:
		_handle_screen_touch(event as InputEventScreenTouch)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event as InputEventMouseMotion)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event as InputEventScreenDrag)


func scroll_vertical_quiet(value: int) -> void:
	_suppress_scroll_signal = true
	scroll_vertical = value
	_suppress_scroll_signal = false


func scroll_horizontal_quiet(value: int) -> void:
	_suppress_scroll_signal = true
	scroll_horizontal = value
	_suppress_scroll_signal = false


func scroll_vertical_to_end() -> void:
	await get_tree().process_frame
	scroll_vertical_quiet(int(get_v_scroll_bar().max_value))


func _handle_mouse_button(mb: InputEventMouseButton) -> void:
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var local := _event_local(mb.global_position)
	if mb.pressed:
		if not _is_local_inside(local):
			return
		_begin_press(local, -1)
	elif _pointer_down:
		var was_dragging := _dragging
		_end_press()
		if was_dragging:
			accept_event()


func _handle_screen_touch(st: InputEventScreenTouch) -> void:
	var local := _event_local(st.position)
	if st.pressed:
		if not _is_local_inside(local):
			return
		_begin_press(local, st.index)
	elif st.index == _active_touch_index:
		var was_dragging := _dragging
		_end_press()
		if was_dragging:
			accept_event()


func _handle_mouse_motion(motion: InputEventMouseMotion) -> void:
	if not _pointer_down or _active_touch_index >= 0:
		return
	_update_drag(_event_local(motion.global_position), false)
	if _dragging:
		accept_event()


func _handle_screen_drag(sd: InputEventScreenDrag) -> void:
	if not _pointer_down or sd.index != _active_touch_index:
		return
	_update_drag(_event_local(sd.position), true)
	if _dragging:
		accept_event()


func _begin_press(local: Vector2, touch_index: int) -> void:
	_pointer_down = true
	_dragging = false
	_armed = false
	_press_local = local
	_press_scroll = Vector2i(scroll_horizontal, scroll_vertical)
	_active_touch_index = touch_index
	_long_press_generation += 1
	if touch_index >= 0:
		var generation := _long_press_generation
		var timer := get_tree().create_timer(float(long_press_ms) / 1000.0)
		timer.timeout.connect(func() -> void:
			_on_long_press_timeout(generation)
		, CONNECT_ONE_SHOT)


func _on_long_press_timeout(generation: int) -> void:
	if generation != _long_press_generation or not _pointer_down or _dragging:
		return
	_armed = true


func _update_drag(local: Vector2, from_touch: bool) -> void:
	if not _pointer_down:
		return
	var delta := local - _press_local
	if not _armed:
		if from_touch:
			return
		if delta.length() < drag_threshold:
			return
		_armed = true
	if not _can_drag_any():
		return
	var was_dragging := _dragging
	if not _dragging:
		_dragging = true
		_suppress_descendant_clicks()
	_apply_scroll_from_delta(delta)
	if not was_dragging:
		user_scrolled.emit()


func _end_press() -> void:
	var was_dragging := _dragging
	_pointer_down = false
	_dragging = false
	_armed = false
	_active_touch_index = -1
	_long_press_generation += 1
	if was_dragging:
		call_deferred("_restore_descendant_clicks")


func _apply_scroll_from_delta(delta: Vector2) -> void:
	_suppress_scroll_signal = true
	if _can_scroll_vertical():
		var bar := get_v_scroll_bar()
		scroll_vertical = clampi(
			_press_scroll.y - int(delta.y),
			int(bar.min_value),
			int(bar.max_value)
		)
	if _can_scroll_horizontal():
		var bar := get_h_scroll_bar()
		scroll_horizontal = clampi(
			_press_scroll.x - int(delta.x),
			int(bar.min_value),
			int(bar.max_value)
		)
	_suppress_scroll_signal = false


func _can_scroll_vertical() -> bool:
	if vertical_scroll_mode == SCROLL_MODE_DISABLED:
		return false
	var bar := get_v_scroll_bar()
	return bar != null and bar.max_value > bar.min_value


func _can_scroll_horizontal() -> bool:
	if horizontal_scroll_mode == SCROLL_MODE_DISABLED:
		return false
	var bar := get_h_scroll_bar()
	return bar != null and bar.max_value > bar.min_value


func _can_drag_any() -> bool:
	return _can_scroll_vertical() or _can_scroll_horizontal()


func _is_local_inside(local: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).has_point(local)


func _event_local(global_pos: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * global_pos


func _on_bar_value_changed(_value: float) -> void:
	if _suppress_scroll_signal or _dragging:
		return
	user_scrolled.emit()


func _suppress_descendant_clicks() -> void:
	if not _suppressed_controls.is_empty():
		return
	
	_cancel_descendant_press_feedback(self)
	_collect_click_suppression(self)


func _cancel_descendant_press_feedback(node: Node) -> void:
	for child in node.get_children():
		if child.has_method("cancel_press_feedback"):
			child.call("cancel_press_feedback")
		_cancel_descendant_press_feedback(child)


func _collect_click_suppression(node: Node) -> void:
	for child in node.get_children():
		if child is BaseButton:
			var button := child as BaseButton
			_suppressed_controls.append({
				"node": button,
				"disabled": button.disabled,
				"mouse_filter": button.mouse_filter,
			})
			button.disabled = true
			button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		elif child is Control and child != self:
			var control := child as Control
			if control.mouse_filter == Control.MOUSE_FILTER_STOP:
				_suppressed_controls.append({
					"node": control,
					"mouse_filter": control.mouse_filter,
				})
				control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_collect_click_suppression(child)


func _restore_descendant_clicks() -> void:
	for row in _suppressed_controls:
		var node := row.get("node") as Control
		if not is_instance_valid(node):
			continue
		node.mouse_filter = row.get("mouse_filter", node.mouse_filter)
		if node is BaseButton:
			(node as BaseButton).disabled = bool(row.get("disabled", false))
	_suppressed_controls.clear()
