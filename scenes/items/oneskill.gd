extends Control
class_name OneSkillView

## 技能槽序号；填 -1 时隐藏 skill_num。
@export var hot_key: String = "1":
	get:
		return _hot_key
	set(value):
		_hot_key = value
		_apply_hot_key()

var _hot_key: String = "1"

@onready var _back: Panel = %Back
@onready var _icon: TextureRect = %Icon
@onready var _cd_overlay: TextureProgressBar = %CdOverlay
@onready var _skill_num: TextureRect = $skill_num
@onready var _slot_label: Label = %SlotLabel
@onready var _name_label: Label = %NameLabel
@onready var _count_label: Label = %CountLabel
@onready var _hover_tip: HoverTipSource = %HoverTipSource

var _cd_total: float = 0.0
var _blocked_tween: Tween
const _COUNT_COLOR_NORMAL := Color(1.0, 0.9647059, 0.74509805, 1.0)
const _COUNT_COLOR_ZERO := Color(0.65, 0.65, 0.65, 1.0)


func _ready() -> void:
	_apply_hot_key()


func _apply_hot_key() -> void:
	if not is_node_ready():
		return
	if hot_key == "":
		_skill_num.visible = false
		return
	_skill_num.visible = true
	_slot_label.text = hot_key


func setup(
	skill_name: String,
	icon: Texture2D,
	back_color: Color
) -> void:
	if not is_node_ready():
		return
	_back.self_modulate = back_color
	_icon.texture = icon
	_name_label.text = skill_name
	set_stack_count(-1)
	set_cooldown(0.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var press := get_node_or_null("Control")
	if press is Control:
		press.mouse_filter = Control.MOUSE_FILTER_STOP


## 空槽：不显示图标与名称，并禁止点击。
func clear_slot() -> void:
	if not is_node_ready():
		return
	_icon.texture = null
	_cd_overlay.visible = false
	_name_label.text = ""
	_count_label.visible = false
	_back.self_modulate = Color(1.0, 1.0, 1.0, 0.35)
	set_cooldown(0.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var press := get_node_or_null("Control")
	if press is Control:
		press.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _hover_tip != null:
		_hover_tip.clear_payload()
		_hover_tip.enabled = false


## 绑定技能 hover tip；[param skill_id] < 0 时不展示。
func bind_hover_skill(skill_id: int, icon: Texture2D = null) -> void:
	_bind_hover_payload(SkillHoverTipBuilder.build(skill_id, icon))


## 绑定道具 hover tip；[param fight_item_id] 为战斗槽位 id（fight_id）。
func bind_hover_item(fight_item_id: int, icon: Texture2D = null, count: int = -1) -> void:
	_bind_hover_payload(ItemHoverTipBuilder.build(fight_item_id, icon, count))


## 绑定法宝 hover tip。
func bind_hover_equip(
	equip_id: int,
	icon: Texture2D = null,
	slot_effects: Variant = null
) -> void:
	_bind_hover_payload(EquipHoverTipBuilder.build(equip_id, icon, slot_effects))


func _bind_hover_payload(payload: Dictionary) -> void:
	if _hover_tip == null:
		return
	if HoverTipPayload.is_empty(payload):
		_hover_tip.clear_payload()
		_hover_tip.enabled = false
		return
	_hover_tip.set_payload(payload)
	_hover_tip.enabled = true


func set_cooldown(remaining: float, total: float = -1.0) -> void:
	if total >= 0.0:
		_cd_total = maxf(total, 0.001)
	var cap := maxf(_cd_total, 0.001)
	remaining = clampf(remaining, 0.0, cap)
	_cd_overlay.value = 100.0 * remaining / cap if remaining > 0.0 else 0.0
	_cd_overlay.visible = remaining > 0.0


func set_stack_count(count: int) -> void:
	if count < 0:
		_count_label.visible = false
		return
	_count_label.visible = true
	var clamped := maxi(0, count)
	_count_label.text = str(clamped)
	_count_label.add_theme_color_override(
		"font_color",
		_COUNT_COLOR_ZERO if clamped == 0 else _COUNT_COLOR_NORMAL
	)


func play_blocked_feedback() -> void:
	if not is_node_ready():
		return
	if _blocked_tween != null:
		_blocked_tween.kill()
	var base := modulate
	modulate = Color(1.0, 0.72, 0.72, base.a)
	_blocked_tween = create_tween()
	_blocked_tween.tween_property(self, "modulate", base, 0.12)
