extends CanvasLayer

## 全局 GM 调试面板。按 F12 或 ` 键开关主面板；道具发放为独立子面板。

const PanelScene := preload("res://scenes/ui/gm_panel.tscn")
const ItemGrantPanelScene := preload("res://scenes/ui/gm_item_grant_panel.tscn")

var _panel: Control
var _item_grant_panel: Control


func _ready() -> void:
	layer = 1003
	follow_viewport_enabled = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelScene.instantiate() as Control
	add_child(_panel)
	_panel.visible = false
	_item_grant_panel = ItemGrantPanelScene.instantiate() as Control
	add_child(_item_grant_panel)
	_item_grant_panel.visible = false


func toggle() -> void:
	if is_item_grant_open():
		hide_item_grant_panel()
		return
	if is_open():
		hide_panel()
	else:
		show_panel()


func show_panel() -> void:
	if _panel == null:
		return
	if _panel.has_method("refresh"):
		_panel.call("refresh")
	_panel.visible = true


func hide_panel() -> void:
	if _panel != null:
		_panel.visible = false


func open_item_grant_panel() -> void:
	if _item_grant_panel == null:
		return
	if _item_grant_panel.has_method("refresh"):
		_item_grant_panel.call("refresh")
	_item_grant_panel.visible = true


func hide_item_grant_panel() -> void:
	if _item_grant_panel != null:
		_item_grant_panel.visible = false


func is_open() -> bool:
	return _panel != null and _panel.visible


func is_item_grant_open() -> bool:
	return _item_grant_panel != null and _item_grant_panel.visible


func is_any_open() -> bool:
	return is_open() or is_item_grant_open()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_F12 or key_event.physical_keycode == KEY_QUOTELEFT:
			toggle()
			get_viewport().set_input_as_handled()
			return
	if not is_any_open():
		return
	if event.is_action_pressed("ui_cancel"):
		if is_item_grant_open():
			hide_item_grant_panel()
		else:
			hide_panel()
		get_viewport().set_input_as_handled()
