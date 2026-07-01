extends Control
class_name BuffStatusItem

## 单个 Buff/被动图标展示。被动平时不显示倒计时，触发冷却后才显示剩余秒数。

@onready var _icon: TextureRect = %Icon
@onready var _time_label: Label = %TimeLabel
@onready var _stacks_label: Label = %StacksLabel
@onready var _hover_tip: HoverTipSource = %HoverTipSource

var _entry_id: String = ""
var _entry_kind: String = "buff"


func apply(buff_id: String, duration_left: float, stacks: int) -> void:
	apply_status({
		"kind": "buff",
		"id": buff_id,
		"duration_left": duration_left,
		"stacks": stacks,
		"show_time": true,
	})


func apply_status(entry: Dictionary) -> void:
	_entry_kind = str(entry.get("kind", "buff"))
	_entry_id = str(entry.get("id", "")).strip_edges()
	var duration_left: float = float(entry.get("duration_left", 0.0))
	var stacks: int = int(entry.get("stacks", 1))
	var show_time: bool = bool(entry.get("show_time", _entry_kind == "buff"))
	if _entry_kind == "passive":
		_apply_passive_display(_entry_id, duration_left, show_time)
	else:
		_apply_buff_display(_entry_id, duration_left, stacks, show_time)


func update_time(duration_left: float, stacks: int = -1) -> void:
	_update_time(duration_left, _entry_kind != "passive" or duration_left > 0.0)
	if stacks >= 0 and _stacks_label != null and _entry_kind == "buff":
		_stacks_label.visible = stacks > 1
		_stacks_label.text = str(stacks)


func clear_item() -> void:
	_entry_id = ""
	_entry_kind = "buff"
	if _icon != null:
		_icon.texture = null
	if _time_label != null:
		_time_label.text = ""
		_time_label.visible = false
	if _stacks_label != null:
		_stacks_label.visible = false
	if _hover_tip != null:
		_hover_tip.clear_payload()
		_hover_tip.enabled = false


func _apply_buff_display(buff_id: String, duration_left: float, stacks: int, show_time: bool) -> void:
	_entry_id = buff_id.strip_edges()
	_entry_kind = "buff"
	var cfg := ConfigManager.buff_by_id(_entry_id)
	var icon := ZhandouInitData._resolve_icon_texture(cfg)
	if _icon != null:
		_icon.texture = icon
	_update_time(duration_left, show_time)
	if _stacks_label != null:
		_stacks_label.visible = stacks > 1
		_stacks_label.text = str(stacks)
	_bind_buff_hover(icon)


func _apply_passive_display(ability_id: String, cd_left: float, show_time: bool) -> void:
	_entry_id = ability_id.strip_edges()
	_entry_kind = "passive"
	var runtime: Dictionary = AbilityService.to_runtime_dict(_entry_id, {})
	var ability: Dictionary = AbilityService.by_id(_entry_id)
	var icon: Texture2D = ZhandouInitData._resolve_icon_texture(runtime)
	if icon == null and not ability.is_empty():
		icon = ZhandouInitData._resolve_icon_texture(ability)
	if _icon != null:
		_icon.texture = icon
	if _stacks_label != null:
		_stacks_label.visible = false
	_update_time(cd_left, show_time)
	_bind_passive_hover(icon)


func _update_time(duration_left: float, show_time_label: bool = true) -> void:
	if _time_label == null:
		return
	if not show_time_label:
		_time_label.text = ""
		_time_label.visible = false
		return
	_time_label.visible = true
	_time_label.text = "%0.1fs" % maxf(0.0, duration_left)


func _bind_buff_hover(icon: Texture2D) -> void:
	if _hover_tip == null:
		return
	if _entry_id == "":
		_hover_tip.clear_payload()
		_hover_tip.enabled = false
		return
	var payload := BuffHoverTipBuilder.build(_entry_id, icon)
	if HoverTipPayload.is_empty(payload):
		_hover_tip.clear_payload()
		_hover_tip.enabled = false
		return
	_hover_tip.set_payload(payload)
	_hover_tip.enabled = true


func _bind_passive_hover(icon: Texture2D) -> void:
	if _hover_tip == null:
		return
	if _entry_id == "":
		_hover_tip.clear_payload()
		_hover_tip.enabled = false
		return
	var payload := SkillHoverTipBuilder.build_ability(_entry_id, {}, icon)
	if HoverTipPayload.is_empty(payload):
		_hover_tip.clear_payload()
		_hover_tip.enabled = false
		return
	_hover_tip.set_payload(payload)
	_hover_tip.enabled = true
