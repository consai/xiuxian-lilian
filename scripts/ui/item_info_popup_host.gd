extends CanvasLayer

## 全局道具信息弹窗：任意场景调用 [method show_entry] / [method show_item] / [method show_equip]。

const PopupScene := preload("res://scenes/ui/item_info_popup.tscn")
const BuilderScript := preload("res://scripts/ui/item_info_payload_builder.gd")
const TipIntentScript := preload("res://scripts/ui/tips/core/tip_intent.gd")

var _popup: ItemInfoPopupView
var _current_payload: Dictionary = {}


func _ready() -> void:
	layer = 1002
	follow_viewport_enabled = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_popup = PopupScene.instantiate() as ItemInfoPopupView
	add_child(_popup)
	_popup.close_requested.connect(hide_popup)
	_popup.use_requested.connect(_on_use_requested)


func show_entry(entry: Dictionary) -> void:
	show_payload(BuilderScript.from_entry(entry))


func show_item(item_id: String, count: int = 1) -> void:
	show_payload(BuilderScript.from_item_id(item_id, count))


func show_equip(equip_id: int) -> void:
	show_payload(BuilderScript.from_equip_id(equip_id))


func show_payload(payload: Dictionary) -> void:
	if _popup == null or BuilderScript.is_empty(payload):
		return
	_current_payload = payload.duplicate(true)
	_popup.apply_payload(_current_payload)
	_popup.visible = true


func hide_popup() -> void:
	_current_payload = {}
	if _popup != null:
		_popup.visible = false


func _on_use_requested() -> void:
	if _current_payload.is_empty() or GameState == null:
		return
	var item_id := str(_current_payload.get("item_id", "")).strip_edges()
	if item_id == "":
		return
	var result := GameState.use_inventory_item(item_id)
	if bool(result.get("ok", false)):
		var message := str(result.get("message", "")).strip_edges()
		if message != "":
			_emit_use_success_tip(message)
		hide_popup()
		return
	var error_text := str(result.get("error", "无法使用该物品")).strip_edges()
	_emit_use_error_tip(error_text)


func _emit_use_error_tip(text: String) -> void:
	_emit_use_tip(text, EnumTipTone.LABEL_LOSS)


func _emit_use_success_tip(text: String) -> void:
	_emit_use_tip(text, EnumTipTone.LABEL_GAIN)


func _emit_use_tip(text: String, tone: String) -> void:
	var message := text.strip_edges()
	if message == "":
		return
	DataEvents.emit_tip_intent(TipIntentScript.make({
		"type": EnumTipIntentType.LABEL_TOAST,
		"text": message,
		"tone": tone,
		"channel": TipIntentScript.CHANNEL_BAR,
		"source": "item_info_popup",
		"ttl_ms": 2000,
	}))


func is_open() -> bool:
	return _popup != null and _popup.visible


func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed("ui_cancel"):
		hide_popup()
		get_viewport().set_input_as_handled()
