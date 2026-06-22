extends Control
class_name OneSkillView

## 技能槽序号；填 -1 时隐藏 skill_num。
@export var hot_key: String = "1":
	get:
		return _hot_key
	set(value):
		_hot_key = value
		_apply_hot_key()

## 紧凑模式：仅显示图标底板，隐藏名称/数量/快捷键；可配合 hover 只读展示（如敌人意图）。
@export var compact_mode: bool = false

var _hot_key: String = "1"

@onready var _back: Panel = %Back
@onready var _icon: TextureRect = %Icon
@onready var _cd_overlay: TextureProgressBar = %CdOverlay
@onready var _skill_num: TextureRect = $skill_num
@onready var _slot_label: Label = %SlotLabel
@onready var _name_label: Label = %NameLabel
@onready var _count_label: Label = %CountLabel
@onready var _quality_tint: Panel = %QualityTint
@onready var _quality_border: Panel = %QualityBorder
@onready var _tier_badge: PanelContainer = %TierBadge
@onready var _tier_label: Label = %TierLabel
@onready var _quality_badge: PanelContainer = %QualityBadge
@onready var _quality_label: Label = %QualityLabel
@onready var _hover_tip: HoverTipSource = %HoverTipSource
@onready var _press: Control = $Control

var _cd_total: float = 0.0
var _blocked_tween: Tween
var _quality: int = 0
var _tier: int = 0
const _COUNT_COLOR_NORMAL := Color(1.0, 0.9647059, 0.74509805, 1.0)
const _COUNT_COLOR_ZERO := Color(0.65, 0.65, 0.65, 1.0)
const _DEFAULT_BACK := Color(0.933, 0.804, 0.702)


func _ready() -> void:
	_apply_hot_key()
	_apply_quality_tier_chrome(_quality, _tier)
	if compact_mode:
		_apply_compact_chrome()


func _apply_hot_key() -> void:
	if not is_node_ready():
		return
	if compact_mode:
		_skill_num.visible = false
		return
	if hot_key == "":
		_skill_num.visible = false
		return
	_skill_num.visible = true
	_slot_label.text = hot_key


func setup(
	skill_name: String,
	icon: Texture2D,
	back_color: Color,
	quality: int = 0,
	tier: int = 0
) -> void:
	if not is_node_ready():
		return
	if compact_mode:
		apply_battle_row({
			"name": skill_name,
			"icon": icon,
			"back_color": back_color,
			"quality": quality,
			"tier": tier,
		})
		return
	_back.self_modulate = back_color
	_icon.texture = icon
	_name_label.text = skill_name
	_apply_quality_tier_chrome(quality, tier)
	set_stack_count(-1)
	set_cooldown(0.0)
	_apply_input_mode(true)


## 绑定战斗槽位数据（图标、冷却、堆叠、hover）。
func apply_battle_row(row: Dictionary, slot_kind: String = "", interactive: bool = true) -> void:
	if not is_node_ready():
		return
	if _is_empty_row(row):
		clear_slot()
		return
	var tex := _row_icon(row)
	var back := _row_back_color(row)
	var kind := slot_kind if slot_kind != "" else _slot_kind_from_row(row)
	if compact_mode:
		_apply_compact_present(row, tex, back)
	else:
		_apply_full_present(row, tex, back)
	_bind_hover_for_row(row, kind, tex)
	_apply_input_mode(interactive)


## 空槽：不显示图标与名称，并禁止点击。
func clear_slot() -> void:
	if not is_node_ready():
		return
	_icon.texture = null
	_cd_overlay.visible = false
	_name_label.text = ""
	_count_label.visible = false
	_back.self_modulate = Color(1.0, 1.0, 1.0, 0.35)
	_apply_quality_tier_chrome(0, 0)
	set_cooldown(0.0)
	_apply_input_mode(false)
	if _hover_tip != null:
		_hover_tip.clear_payload()
		_hover_tip.enabled = false
	if compact_mode:
		_apply_compact_chrome()


func bind_hover_skill(skill_id: int, icon: Texture2D = null) -> void:
	_bind_hover_payload(SkillHoverTipBuilder.build(skill_id, icon))


func bind_hover_item(fight_item_id: int, icon: Texture2D = null, count: int = -1) -> void:
	_bind_hover_payload(ItemHoverTipBuilder.build(fight_item_id, icon, count))


func bind_hover_equip(
	equip_id: int,
	icon: Texture2D = null,
	slot_effects: Variant = null
) -> void:
	_bind_hover_payload(EquipHoverTipBuilder.build(equip_id, icon, slot_effects))


func set_cooldown(remaining: float, total: float = -1.0) -> void:
	if total >= 0.0:
		_cd_total = maxf(total, 0.001)
	var cap := maxf(_cd_total, 0.001)
	remaining = clampf(remaining, 0.0, cap)
	_cd_overlay.value = 100.0 * remaining / cap if remaining > 0.0 else 0.0
	_cd_overlay.visible = remaining > 0.0


func set_stack_count(count: int) -> void:
	if compact_mode or count < 0:
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


func _apply_full_present(row: Dictionary, icon: Texture2D, back_color: Color) -> void:
	_restore_default_chrome()
	_back.self_modulate = back_color
	_icon.texture = icon
	_name_label.text = str(row.get("name", ""))
	_apply_quality_tier_chrome(_row_quality(row), _row_tier(row))
	var count_v = row.get("count", null)
	if count_v is int:
		set_stack_count(int(count_v))
	else:
		set_stack_count(-1)
	var cd_rem := float(row.get("cd_remaining", 0.0))
	var cd_total := float(row.get("cd_total", -1.0))
	set_cooldown(cd_rem, cd_total)


func _apply_compact_present(row: Dictionary, icon: Texture2D, back_color: Color) -> void:
	_apply_compact_chrome()
	_back.self_modulate = back_color
	_icon.texture = icon
	_apply_quality_tier_chrome(_row_quality(row), _row_tier(row))
	set_stack_count(-1)
	set_cooldown(0.0)


func _apply_compact_chrome() -> void:
	_name_label.visible = false
	_count_label.visible = false
	_skill_num.visible = false


func _restore_default_chrome() -> void:
	_name_label.visible = true
	_apply_hot_key()


func _apply_input_mode(interactive: bool) -> void:
	if interactive:
		mouse_filter = Control.MOUSE_FILTER_STOP
		if _press != null:
			_press.mouse_filter = Control.MOUSE_FILTER_STOP
		return
	mouse_filter = Control.MOUSE_FILTER_STOP if compact_mode else Control.MOUSE_FILTER_IGNORE
	if _press != null:
		_press.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _bind_hover_for_row(row: Dictionary, slot_kind: String, icon: Texture2D) -> void:
	match slot_kind:
		"item":
			bind_hover_item(int(row.get("item_id", -1)), icon, int(row.get("count", -1)))
		"equip":
			bind_hover_equip(
				int(row.get("equip_id", row.get("item_id", -1))),
				icon,
				row.get("effects", [])
			)
		_:
			bind_hover_skill(int(row.get("skill_id", -1)), icon)


func _bind_hover_payload(payload: Dictionary) -> void:
	if _hover_tip == null:
		return
	if HoverTipPayload.is_empty(payload):
		_hover_tip.clear_payload()
		_hover_tip.enabled = false
		return
	_hover_tip.set_payload(payload)
	_hover_tip.enabled = true


func _is_empty_row(row: Variant) -> bool:
	if not row is Dictionary:
		return true
	var dict := row as Dictionary
	if dict.is_empty() or bool(dict.get("empty", false)):
		return true
	return _row_icon(dict) == null


func _row_icon(row: Dictionary) -> Texture2D:
	var icon_v: Variant = row.get("icon")
	return icon_v as Texture2D if icon_v is Texture2D else null


func _row_back_color(row: Dictionary) -> Color:
	var back_v: Variant = row.get("back_color")
	return back_v as Color if back_v is Color else _DEFAULT_BACK


func _row_quality(row: Dictionary) -> int:
	if row.has("quality"):
		return EnumQuality.clamp_quality(int(row.get("quality", EnumQuality.Type.LOW)))
	return 0


func _row_tier(row: Dictionary) -> int:
	if row.has("tier"):
		return EnumItemTier.clamp_tier(int(row.get("tier", EnumItemTier.Type.QI)))
	return 0


func _apply_quality_tier_chrome(quality: int, tier: int) -> void:
	_quality = quality
	_tier = tier
	var has_quality := quality > 0
	var has_tier := tier > 0
	var quality_color := EnumQuality.get_color(quality) if has_quality else Color.WHITE
	var tier_color := EnumItemTier.get_color(tier) if has_tier else Color.WHITE
	if _quality_tint != null:
		_quality_tint.visible = has_quality
		_quality_tint.self_modulate = Color(quality_color.r, quality_color.g, quality_color.b, 0.18)
	if _quality_border != null:
		_quality_border.visible = has_quality
		_quality_border.self_modulate = quality_color
	if _tier_badge != null:
		_tier_badge.visible = has_tier
		_tier_badge.self_modulate = tier_color
	if _tier_label != null:
		_tier_label.text = EnumItemTier.label(tier)
	if _quality_badge != null:
		_quality_badge.visible = has_quality
		_quality_badge.self_modulate = quality_color
	if _quality_label != null:
		_quality_label.text = EnumQuality.display_label(quality)


func _slot_kind_from_row(row: Dictionary) -> String:
	var action_type := str(row.get("action_type", "")).strip_edges().to_lower()
	match action_type:
		"item":
			return "item"
		"equip":
			return "equip"
		"skill", "basic":
			return "skill"
	if row.has("item_id") and int(row.get("item_id", -1)) >= 0:
		return "item"
	if row.has("equip_id") and int(row.get("equip_id", -1)) > 0:
		return "equip"
	return "skill"
