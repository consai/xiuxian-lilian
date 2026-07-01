extends CanvasLayer

## 全局 GM 调试面板。按 F12 或 ` 键开关；主面板 / 战斗调试 / 道具发放可切换。

const PanelScene := preload("res://scenes/ui/gm_panel.tscn")
const BattlePanelScene := preload("res://scenes/ui/gm_battle_panel.tscn")
const ItemGrantPanelScene := preload("res://scenes/ui/gm_item_grant_panel.tscn")

enum GmWindow {
	MAIN,
	BATTLE,
	ITEM_GRANT,
}

var _panel: Control
var _battle_panel: Control
var _item_grant_panel: Control
var _active_window: int = GmWindow.MAIN


func _ready() -> void:
	layer = 1003
	follow_viewport_enabled = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelScene.instantiate() as Control
	add_child(_panel)
	_panel.visible = false
	_battle_panel = BattlePanelScene.instantiate() as Control
	add_child(_battle_panel)
	_battle_panel.visible = false
	if _battle_panel.has_signal("closed"):
		_battle_panel.connect("closed", _on_battle_panel_closed)
	_item_grant_panel = ItemGrantPanelScene.instantiate() as Control
	add_child(_item_grant_panel)
	_item_grant_panel.visible = false
	if _item_grant_panel.has_signal("closed"):
		_item_grant_panel.connect("closed", _on_item_grant_panel_closed)


func toggle() -> void:
	if is_any_open():
		hide_all()
	else:
		show_window(GmWindow.MAIN)


func show_window(window_id: int) -> void:
	_hide_all_panels()
	_active_window = window_id
	match window_id:
		GmWindow.MAIN:
			show_panel()
		GmWindow.BATTLE:
			show_battle_panel()
		GmWindow.ITEM_GRANT:
			show_item_grant_panel()


func show_panel() -> void:
	_hide_all_panels()
	_active_window = GmWindow.MAIN
	if _panel == null:
		return
	if _panel.has_method("refresh"):
		_panel.call("refresh")
	_panel.visible = true


func hide_panel() -> void:
	if _panel != null:
		_panel.visible = false


func show_battle_panel() -> void:
	_hide_all_panels()
	_active_window = GmWindow.BATTLE
	if _battle_panel == null:
		return
	if _battle_panel.has_method("refresh"):
		_battle_panel.call("refresh")
	_battle_panel.visible = true


func hide_battle_panel() -> void:
	if _battle_panel != null:
		_battle_panel.visible = false


func open_item_grant_panel() -> void:
	show_window(GmWindow.ITEM_GRANT)


func hide_item_grant_panel() -> void:
	if _item_grant_panel != null:
		_item_grant_panel.visible = false


func show_item_grant_panel() -> void:
	if _item_grant_panel == null:
		return
	if _item_grant_panel.has_method("refresh"):
		_item_grant_panel.call("refresh")
	_item_grant_panel.visible = true


func hide_all() -> void:
	_hide_all_panels()
	_active_window = GmWindow.MAIN


func is_open() -> bool:
	return _panel != null and _panel.visible


func is_battle_open() -> bool:
	return _battle_panel != null and _battle_panel.visible


func is_item_grant_open() -> bool:
	return _item_grant_panel != null and _item_grant_panel.visible


func is_any_open() -> bool:
	return is_open() or is_battle_open() or is_item_grant_open()


func _hide_all_panels() -> void:
	hide_panel()
	hide_battle_panel()
	hide_item_grant_panel()


func _on_battle_panel_closed() -> void:
	if is_any_open():
		return
	_active_window = GmWindow.MAIN


func _on_item_grant_panel_closed() -> void:
	if is_any_open():
		return
	_active_window = GmWindow.MAIN


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
			if not is_open() and not is_battle_open():
				_active_window = GmWindow.MAIN
			elif is_battle_open():
				show_battle_panel()
			else:
				show_panel()
		elif is_battle_open():
			show_panel()
		else:
			hide_all()
		get_viewport().set_input_as_handled()
