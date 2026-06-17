class_name EnemyFormationSlotView
extends Node2D

## 战斗阵型单格：布局由 enemy_formation_slot.tscn 定义，代码只负责绑定显示数据。

const _SWORD_ICON := preload("res://assets/art/ui_new/item_jian.png")
const _SHIELD_ICON := preload("res://assets/art/ui_new/hudun_icon.png")

@onready var _intent_badge: Control = %IntentBadge
@onready var _intent_icon: TextureRect = %IntentIcon
@onready var _intent_damage: Label = %IntentDamage
@onready var _intent_hover: HoverTipSource = %IntentHover
@onready var sprite: Sprite2D = $Sprite
@onready var hp_bar: ProgressBar = $HpBar
@onready var name_label: Label = $Name
@onready var _buff_status: BuffStatusBar = %BuffStatusBar


func apply_slot(
		row_data: Dictionary,
		unit: FightObj,
		intent_row: Dictionary,
		active: bool,
		dead: bool
) -> void:
	visible = unit != null
	if unit == null:
		if _buff_status != null:
			_buff_status.sync_buffs({})
		return
	var enabled := active and not dead
	modulate = Color(1, 1, 1, 1) if enabled else Color(0.66, 0.66, 0.66, 0.72)
	var avatar := BattleInitData._resolve_avatar_texture(row_data)
	if sprite != null:
		sprite.texture = avatar
	if hp_bar != null:
		var hp_max := maxf(unit.get_hp_max(), 0.001)
		hp_bar.min_value = 0.0
		hp_bar.max_value = hp_max
		hp_bar.value = clampf(unit.hp, 0.0, hp_max)
	if name_label != null:
		var name_text := str(row_data.get("name", "敌人")).strip_edges()
		name_label.text = name_text if name_text != "" else "敌人"
	if _buff_status != null:
		_buff_status.sync_buffs(unit.buffs)
	_apply_intent(intent_row, enabled)


func _apply_intent(intent_row: Dictionary, enabled: bool) -> void:
	if _intent_badge == null:
		return
	if not enabled or intent_row.is_empty():
		_intent_badge.visible = false
		_clear_intent_hover()
		return
	var overlay := str(intent_row.get("intent_overlay", "")).strip_edges().to_lower()
	match overlay:
		"damage":
			_intent_badge.visible = true
			_intent_icon.texture = _SWORD_ICON
			_intent_icon.visible = true
			var damage := int(intent_row.get("estimated_damage", 0))
			if _intent_damage != null:
				_intent_damage.visible = damage > 0
				if damage > 0:
					_intent_damage.text = str(damage)
		"shield":
			_intent_badge.visible = true
			_intent_icon.texture = _SHIELD_ICON
			_intent_icon.visible = true
			if _intent_damage != null:
				_intent_damage.visible = false
		_:
			var fallback_icon_v: Variant = intent_row.get("icon")
			if fallback_icon_v is Texture2D:
				_intent_badge.visible = true
				_intent_icon.texture = fallback_icon_v as Texture2D
				_intent_icon.visible = true
				if _intent_damage != null:
					_intent_damage.visible = false
			else:
				_intent_badge.visible = false
				_clear_intent_hover()
				return
	_bind_intent_hover(intent_row)


func _bind_intent_hover(intent_row: Dictionary) -> void:
	if _intent_hover == null:
		return
	var action_type := str(intent_row.get("action_type", "")).strip_edges().to_lower()
	var payload := {}
	match action_type:
		"item":
			payload = ItemHoverTipBuilder.build(
				int(intent_row.get("item_id", -1)),
				intent_row.get("icon") as Texture2D,
				int(intent_row.get("count", -1))
			)
		"equip":
			payload = EquipHoverTipBuilder.build(
				int(intent_row.get("equip_id", -1)),
				intent_row.get("icon") as Texture2D,
				intent_row.get("effects", [])
			)
		_:
			payload = SkillHoverTipBuilder.build(
				int(intent_row.get("skill_id", -1)),
				intent_row.get("icon") as Texture2D
			)
	if HoverTipPayload.is_empty(payload):
		_clear_intent_hover()
		return
	_intent_hover.set_payload(payload)
	_intent_hover.enabled = true


func _clear_intent_hover() -> void:
	if _intent_hover == null:
		return
	_intent_hover.clear_payload()
	_intent_hover.enabled = false
