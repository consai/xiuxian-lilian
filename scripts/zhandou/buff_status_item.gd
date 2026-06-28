extends Control
class_name BuffStatusItem

## 单个 Buff 图标与剩余时间展示。整个根区域 hover 时弹出 Buff 详情。

@onready var _icon: TextureRect = %Icon
@onready var _time_label: Label = %TimeLabel
@onready var _stacks_label: Label = %StacksLabel
@onready var _hover_tip: HoverTipSource = %HoverTipSource

var _buff_id: String = ""


func apply(buff_id: String, duration_left: float, stacks: int) -> void:
	_buff_id = buff_id.strip_edges()
	var cfg := ConfigManager.buff_by_id(_buff_id)
	var icon := ZhandouInitData._resolve_icon_texture(cfg)
	if _icon != null:
		_icon.texture = icon
	_update_time(duration_left)
	if _stacks_label != null:
		_stacks_label.visible = stacks > 1
		_stacks_label.text = str(stacks)
	_bind_hover(icon)


func update_time(duration_left: float, stacks: int = -1) -> void:
	_update_time(duration_left)
	if stacks >= 0 and _stacks_label != null:
		_stacks_label.visible = stacks > 1
		_stacks_label.text = str(stacks)


func clear_item() -> void:
	_buff_id = ""
	if _icon != null:
		_icon.texture = null
	if _time_label != null:
		_time_label.text = ""
	if _stacks_label != null:
		_stacks_label.visible = false
	if _hover_tip != null:
		_hover_tip.clear_payload()
		_hover_tip.enabled = false


func _update_time(duration_left: float) -> void:
	if _time_label == null:
		return
	_time_label.text = "%0.1fs" % maxf(0.0, duration_left)


func _bind_hover(icon: Texture2D) -> void:
	if _hover_tip == null:
		return
	if _buff_id == "":
		_hover_tip.clear_payload()
		_hover_tip.enabled = false
		return
	var payload := BuffHoverTipBuilder.build(_buff_id, icon)
	if HoverTipPayload.is_empty(payload):
		_hover_tip.clear_payload()
		_hover_tip.enabled = false
		return
	_hover_tip.set_payload(payload)
	_hover_tip.enabled = true
