extends Control

const AbilityServiceScript := preload("res://scripts/dao/ability_service.gd")
const ZhandouInitDataScript := preload("res://scripts/zhandou/zhandou_init_data.gd")
const XiulianMethodServiceScript := preload("res://scripts/sim/xiulian_method_service.gd")
const DaoTreeServiceScript := preload("res://scripts/dao/dao_tree_service.gd")
const MethodRowScene := preload("res://scenes/ui/components/peizhi_gongfa_hang.tscn")
const SkillRowScene := preload("res://scenes/ui/components/mastered_skill_row.tscn")

const FILTER_ALL := "all"
const FILTER_ACTIVE := "combat_active"
const FILTER_UPKEEP := "combat_upkeep"
const FILTER_PASSIVE := "combat_passive"

var _skill_filter := FILTER_ALL

@onready var _close_button: TextureButton = %CloseButton
@onready var _configure_button: TextureButton = %ConfigureButton
@onready var _method_count: Label = %MethodCountLabel
@onready var _skill_count: Label = %SkillCountLabel
@onready var _methods: VBoxContainer = %MethodsContainer
@onready var _skills: VBoxContainer = %SkillsContainer
@onready var _filter_all: Button = %FilterAll
@onready var _filter_active: Button = %FilterActive
@onready var _filter_upkeep: Button = %FilterUpkeep
@onready var _filter_passive: Button = %FilterPassive


func _ready() -> void:
	_close_button.pressed.connect(_go_back)
	_configure_button.pressed.connect(func() -> void: SceneManager.go_zhandou_peizhi_mianban())
	_filter_all.pressed.connect(_set_skill_filter.bind(FILTER_ALL))
	_filter_active.pressed.connect(_set_skill_filter.bind(FILTER_ACTIVE))
	_filter_upkeep.pressed.connect(_set_skill_filter.bind(FILTER_UPKEEP))
	_filter_passive.pressed.connect(_set_skill_filter.bind(FILTER_PASSIVE))
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_back()
		get_viewport().set_input_as_handled()


func refresh() -> void:
	_bind_methods()
	_refresh_filter_buttons()
	_bind_skills()


func _bind_methods() -> void:
	_clear(_methods)
	var count := 0
	for method_id_v in GameState.unlocked_methods:
		var method_id := str(method_id_v).strip_edges()
		if method_id == "":
			continue
		var method := XiulianMethodServiceScript.by_id(method_id)
		if method.is_empty():
			continue
		count += 1
		var row := MethodRowScene.instantiate() as Control
		var icon := _method_icon(method)
		row.get_node("%TypeLabel").text = _method_type_label(method)
		var family := XiulianMethodServiceScript.family_by_id(str(method.get("familyId", "")))
		var name_label := row.get_node("%NameLabel") as Label
		name_label.text = str(method.get("name", method_id))
		name_label.add_theme_color_override(
			"font_color",
			EnumQuality.get_color(_entry_quality(method, family))
		)
		row.get_node("%MetaLabel").text = _method_meta(method, method_id)
		row.get_node("%EffectLabel").text = _method_brief_effect(method, method_id)
		_apply_quality_tier_badges(row, method, family)
		var hover := row.get_node("%HoverTipSource") as HoverTipSource
		hover.set_payload(MethodHoverTipBuilder.build(method_id, GameState.to_dict(), icon))
		_set_icon(row.get_node("%Icon") as TextureRect, icon)
		_methods.add_child(row)
	_method_count.text = "已掌握 %d 门" % count
	if count == 0:
		_add_empty_method_row()


func _bind_skills() -> void:
	_clear(_skills)
	var count := 0
	var visible_count := 0
	for ability_id_v in GameState.unlocked_abilities:
		var ability_id := str(ability_id_v).strip_edges()
		if ability_id == "" or ability_id == "-1":
			continue
		var ability := AbilityServiceScript.by_id(ability_id)
		if ability.is_empty():
			continue
		count += 1
		var ability_type := str(ability.get("type", ""))
		if _skill_filter != FILTER_ALL and ability_type != _skill_filter:
			continue
		var skill := AbilityServiceScript.to_runtime_dict(ability_id, GameState.to_dict())
		var display := skill if not skill.is_empty() else ability
		visible_count += 1
		var row := SkillRowScene.instantiate() as Control
		var icon := _entry_icon(display)
		row.get_node("%IndexLabel").text = str(visible_count)
		row.get_node("%TypeLabel").text = SkillHoverTipBuilder.ability_type_label(ability_type)
		var name_label := row.get_node("%NameLabel") as Label
		name_label.text = str(ability.get("name", ability_id))
		name_label.add_theme_color_override("font_color", EnumQuality.get_color(_entry_quality(ability)))
		row.get_node("%MetaLabel").text = _skill_meta(ability, skill, ability_id)
		row.get_node("%EffectLabel").text = _skill_brief_effect(ability, skill, ability_id)
		_apply_quality_tier_badges(row, ability)
		_set_icon(row.get_node("%Icon") as TextureRect, icon)
		var hover := row.get_node("%HoverTipSource") as HoverTipSource
		hover.set_payload(SkillHoverTipBuilder.build_ability(ability_id, GameState.to_dict(), icon))
		_skills.add_child(row)
	_skill_count.text = "已掌握 %d 个    当前显示 %d 个" % [count, visible_count]
	if visible_count == 0:
		_add_empty_skill_row()


func _set_skill_filter(next_filter: String) -> void:
	_skill_filter = next_filter
	_refresh_filter_buttons()
	_bind_skills()


func _refresh_filter_buttons() -> void:
	for pair in [
		[_filter_all, FILTER_ALL],
		[_filter_active, FILTER_ACTIVE],
		[_filter_upkeep, FILTER_UPKEEP],
		[_filter_passive, FILTER_PASSIVE],
	]:
		var button := pair[0] as Button
		button.theme_type_variation = "TabActive" if str(pair[1]) == _skill_filter else "TabIdle"


func _skill_meta(ability: Dictionary, _runtime: Dictionary, _ability_id: String) -> String:
	var parts: PackedStringArray = []
	var realm_id := AbilityService.ability_realm_id(ability)
	parts.append("境界 %s" % DaoTreeServiceScript.realm_display_name(realm_id))
	parts.append(EnumItemTier.label(_entry_tier(ability)))
	parts.append(EnumQuality.display_label(_entry_quality(ability)))
	var combat_v: Variant = ability.get("combat", {})
	if combat_v is Dictionary:
		var combat := combat_v as Dictionary
		var cost := _format_cost_text(combat.get("costs", []))
		if cost != "":
			parts.append(cost)
		var upkeep := _format_cost_text(combat.get("upkeepCostsPerSecond", []))
		if upkeep != "":
			parts.append("维持 %s/秒" % upkeep)
		var cooldown := float(combat.get("cooldown", 0.0))
		if cooldown > 0.0:
			parts.append("冷却 %ss" % _fmt_num(cooldown))
	if parts.is_empty():
		parts.append("学习后生效")
	return "    ".join(parts)


func _skill_brief_effect(ability: Dictionary, runtime: Dictionary, _ability_id: String) -> String:
	var lines := HoverTipEffectFormatter.format_lines(runtime.get("effects", []))
	if lines.is_empty():
		lines = HoverTipEffectFormatter.format_raw_ability_lines(ability.get("effects", []))
	if not lines.is_empty():
		return str(lines[0])
	var desc := str(ability.get("description", "")).strip_edges()
	return desc if desc != "" else "查看悬浮详情了解效果"


func _add_empty_method_row() -> void:
	var row := MethodRowScene.instantiate() as Control
	row.get_node("%TypeLabel").text = "功法"
	row.get_node("%NameLabel").text = "尚未掌握功法"
	row.get_node("%MetaLabel").text = "研读功法典籍后会出现在这里"
	row.get_node("%EffectLabel").text = ""
	_apply_quality_tier_badges(row, {})
	_set_icon(row.get_node("%Icon") as TextureRect, null)
	_methods.add_child(row)


func _add_empty_skill_row() -> void:
	var row := SkillRowScene.instantiate() as Control
	row.get_node("%IndexLabel").text = "-"
	row.get_node("%TypeLabel").text = "技能"
	row.get_node("%NameLabel").text = "尚未掌握技能"
	row.get_node("%MetaLabel").text = "研读技能典籍后会出现在这里"
	row.get_node("%EffectLabel").text = ""
	_apply_quality_tier_badges(row, {})
	_set_icon(row.get_node("%Icon") as TextureRect, null)
	_skills.add_child(row)


func _method_type_label(method: Dictionary) -> String:
	var family := XiulianMethodServiceScript.family_by_id(str(method.get("familyId", "")))
	var role := str(family.get("role", "")).strip_edges()
	if bool(method.get("is_movement", false)) or str(method.get("slot_type", "")) == "movement" \
			or role.find("身法") >= 0 or role.find("遁法") >= 0:
		return "身法"
	if str(family.get("progressionType", method.get("progressionType", ""))) == "side_path":
		return "旁门"
	return "功法"


func _method_meta(method: Dictionary, method_id: String) -> String:
	var parts: PackedStringArray = []
	var realm := str(method.get("realm", "")).strip_edges()
	if realm != "":
		parts.append("境界 %s" % DaoTreeServiceScript.realm_display_name(realm))
	var family := XiulianMethodServiceScript.family_by_id(str(method.get("familyId", "")))
	parts.append(EnumItemTier.label(_entry_tier(method)))
	parts.append(EnumQuality.display_label(_entry_quality(method, family)))
	var mastery := XiulianMethodServiceScript.method_mastery(GameState.to_dict(), method_id)
	parts.append("熟练 %.0f%%" % (mastery * 100.0))
	var practice: Dictionary = method.get("practice", {}) as Dictionary
	if not practice.is_empty():
		parts.append("修炼速度 x%.2f" % float(practice.get("efficiency", 1.0)))
	return "    ".join(parts)


func _method_brief_effect(method: Dictionary, method_id: String) -> String:
	var lines := HoverTipEffectFormatter.format_raw_ability_lines(
		method.get("effects", []),
		XiulianMethodServiceScript.method_mastery_value_ratio(GameState.to_dict(), method_id)
	)
	if not lines.is_empty():
		return str(lines[0])
	var practice: Dictionary = method.get("practice", {}) as Dictionary
	if not practice.is_empty():
		return "修炼速度 x%s" % _fmt_num(float(practice.get("efficiency", 1.0)))

	var desc := str(method.get("description", "")).strip_edges()
	return desc if desc != "" else "查看悬浮详情了解效果"


func _method_icon(method: Dictionary) -> Texture2D:
	if method.has("icon") and method.get("icon") != null:
		return _entry_icon(method)
	if _method_type_label(method) == "身法":
		return ZhandouInitDataScript._resolve_icon_texture({"icon": "ui_new/skill_04.png"})
	return ZhandouInitDataScript._resolve_icon_texture({"icon": "ui_new/gongfa.png"})


func _entry_icon(entry: Dictionary) -> Texture2D:
	if entry.is_empty() or not entry.has("icon") or entry.get("icon") == null:
		return null
	return ZhandouInitDataScript._resolve_icon_texture(entry)


func _set_icon(icon: TextureRect, texture: Texture2D) -> void:
	icon.texture = texture
	icon.visible = texture != null


func _entry_quality(entry: Dictionary, fallback: Dictionary = {}) -> int:
	return clampi(
		int(entry.get("quality", fallback.get("quality", EnumQuality.Type.LOW))),
		EnumQuality.Type.LOW,
		EnumQuality.Type.SUPREME
	)


func _entry_tier(entry: Dictionary) -> int:
	return EnumItemTier.clamp_tier(int(entry.get("tier", 1)))


func _apply_quality_tier_badges(row: Control, entry: Dictionary, fallback: Dictionary = {}) -> void:
	var tier_badge := row.get_node_or_null("%TierBadge") as CanvasItem
	var quality_badge := row.get_node_or_null("%QualityBadge") as CanvasItem
	var tier_label := row.get_node_or_null("%TierBadgeLabel") as Label
	var quality_label := row.get_node_or_null("%QualityBadgeLabel") as Label
	var has_entry := not entry.is_empty()
	if tier_badge != null:
		tier_badge.visible = has_entry
		if has_entry:
			tier_badge.self_modulate = EnumItemTier.get_color(_entry_tier(entry))
	if quality_badge != null:
		quality_badge.visible = has_entry
		if has_entry:
			quality_badge.self_modulate = EnumQuality.get_color(_entry_quality(entry, fallback))
	if tier_label != null and has_entry:
		tier_label.text = EnumItemTier.label(_entry_tier(entry))
	if quality_label != null and has_entry:
		quality_label.text = EnumQuality.display_label(_entry_quality(entry, fallback))


func _format_cost_text(costs_v: Variant) -> String:
	if not costs_v is Array:
		return ""
	var labels: PackedStringArray = []
	for cost_v in costs_v as Array:
		if not cost_v is Dictionary:
			continue
		var cost := cost_v as Dictionary
		var value := float(cost.get("value", 0.0))
		if value <= 0.0:
			continue
		labels.append("%s %s" % [_resource_label(str(cost.get("resource", "mana"))), _fmt_num(value)])
	return "、".join(labels)


func _resource_label(resource: String) -> String:
	match resource.strip_edges().to_lower():
		"stamina":
			return "体力"
		"spirit":
			return "神魂"
		_:
			return "法力"


func _fmt_num(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return "%0.1f" % value


func _clear(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()


func _go_back() -> void:
	SceneManager.go_back()
