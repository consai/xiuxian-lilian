extends CanvasLayer

## 全局道具信息弹窗：任意场景调用 [method show_entry] / [method show_item] / [method show_equip]。

const PopupScene := preload("res://scenes/ui/item_info_popup.tscn")
const BuilderScript := preload("res://scripts/ui/item_info_payload_builder.gd")

var _popup: ItemInfoPopupView


func _ready() -> void:
	layer = 1002
	follow_viewport_enabled = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_popup = PopupScene.instantiate() as ItemInfoPopupView
	add_child(_popup)
	_popup.close_requested.connect(hide_popup)


func show_entry(entry: Dictionary) -> void:
	show_payload(BuilderScript.from_entry(entry))


func show_item(item_id: String, count: int = 1) -> void:
	show_payload(BuilderScript.from_item_id(item_id, count))


func show_equip(equip_id: int) -> void:
	show_payload(BuilderScript.from_equip_id(equip_id))


func show_payload(payload: Dictionary) -> void:
	if _popup == null or BuilderScript.is_empty(payload):
		return
	_popup.apply_payload(payload)
	_popup.visible = true


func hide_popup() -> void:
	if _popup != null:
		_popup.visible = false


func is_open() -> bool:
	return _popup != null and _popup.visible


func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed("ui_cancel"):
		hide_popup()
		get_viewport().set_input_as_handled()
