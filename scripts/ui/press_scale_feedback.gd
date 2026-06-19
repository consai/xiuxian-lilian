extends Node
class_name PressScale

## 通用点击：按下/抬起缩放完成后，通过 [signal clicked] 通知（[BaseButton] 走 [signal BaseButton.pressed]；非按钮控件走左键/触摸抬起）。
signal clicked

## 通用按压缩放反馈：作为子节点挂在 [Button]、[TextureButton] 或 [TextureRect] 等 [Control] 下使用。
## 默认 [member target_path] 为 [code]".."[/code]，即对父节点做缩放；也可指向同场景内任意 [Control]。
## 也可把本脚本直接挂在 [BaseButton] 上：此时请把 [member target_path] 设为 [code]"."[/code]（缩放自身），或留空 [code]".."[/code] 时脚本会自动按自身处理。

@export var target_path: NodePath = NodePath(".")
@export_range(0.5, 1.0) var press_scale: float = 0.95
@export var press_duration: float = 0.06
@export var release_duration: float = 0.12
@export var release_trans: Tween.TransitionType = Tween.TRANS_BACK
@export var release_ease: Tween.EaseType = Tween.EASE_OUT
@export var pivot_to_center: bool = true
## 对非 [BaseButton]：若当前为 [constant Control.MOUSE_FILTER_IGNORE]，则改为 [constant Control.MOUSE_FILTER_STOP]，否则点不到 [TextureRect]。
@export var take_mouse_if_ignored: bool = true

var _target: Control
var _base_button: BaseButton
var _pressed_depth: int = 0
var _tw: Tween


func _ready() -> void:
	var path := target_path
	## 脚本挂在 [BaseButton] 节点上时，[code]".."[/code] 会变成父级 [VBox] 等，误连信号；改为自身。
	if path == NodePath("..") and get_parent() != null and not (get_parent() is BaseButton):
		var self_btn := self as Node
		if self_btn is BaseButton:
			path = NodePath(".")
	_target = get_node_or_null(path) as Control
	if _target == null:
		push_error("PressScaleFeedback: target_path 未指向有效 Control: %s" % str(target_path))
		return
	if pivot_to_center:
		_target.resized.connect(_center_pivot)
		_center_pivot()
	if _target is BaseButton:
		_base_button = _target as BaseButton
		_base_button.button_down.connect(_on_button_down)
		_base_button.button_up.connect(_on_button_up)
		_base_button.pressed.connect(_on_clicked)
	else:
		if take_mouse_if_ignored and _target.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			_target.mouse_filter = Control.MOUSE_FILTER_STOP
		_target.gui_input.connect(_on_gui_input)


func _exit_tree() -> void:
	_kill_tween()
	if is_instance_valid(_target):
		if _base_button != null:
			if _base_button.button_down.is_connected(_on_button_down):
				_base_button.button_down.disconnect(_on_button_down)
			if _base_button.button_up.is_connected(_on_button_up):
				_base_button.button_up.disconnect(_on_button_up)
			if _base_button.pressed.is_connected(_on_clicked):
				_base_button.pressed.disconnect(_on_clicked)
		else:
			if _target.gui_input.is_connected(_on_gui_input):
				_target.gui_input.disconnect(_on_gui_input)
		if _target.resized.is_connected(_center_pivot):
			_target.resized.disconnect(_center_pivot)


func _center_pivot() -> void:
	if is_instance_valid(_target) and pivot_to_center:
		_target.pivot_offset = _target.size * 0.5


func _on_button_down() -> void:
	_pressed_depth += 1
	_play_press()


func _on_button_up() -> void:
	_pressed_depth = maxi(_pressed_depth - 1, 0)
	if _pressed_depth == 0:
		_play_release()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_pressed_depth += 1
				_play_press()
			else:
				_pressed_depth = maxi(_pressed_depth - 1, 0)
				if _pressed_depth == 0:
					_play_release()
					clicked.emit()
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_pressed_depth += 1
			_play_press()
		else:
			_pressed_depth = maxi(_pressed_depth - 1, 0)
			if _pressed_depth == 0:
				_play_release()
				clicked.emit()


func _on_clicked() -> void:
	clicked.emit()


func cancel_press_feedback() -> void:
	_pressed_depth = 0
	_play_release()


func _play_press() -> void:
	if not is_instance_valid(_target):
		return
	_kill_tween()
	_tw = create_tween()
	_tw.tween_property(_target, "scale", Vector2(press_scale, press_scale), press_duration)


func _play_release() -> void:
	if not is_instance_valid(_target):
		return
	_kill_tween()
	_tw = create_tween()
	_tw.set_trans(release_trans).set_ease(release_ease)
	_tw.tween_property(_target, "scale", Vector2.ONE, release_duration)


func _kill_tween() -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = null
