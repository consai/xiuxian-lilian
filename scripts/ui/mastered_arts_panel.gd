extends Control

const AbilityServiceScript := preload("res://scripts/dao/ability_service.gd")
const BattleInitDataScript := preload("res://scripts/fight/battle_init_data.gd")
const CultivationMethodServiceScript := preload("res://scripts/sim/cultivation_method_service.gd")
const MethodRowScene := preload("res://scenes/ui/components/loadout_method_row.tscn")
const SkillRowScene := preload("res://scenes/ui/components/loadout_skill_order_row.tscn")

@onready var _close_button: TextureButton = %CloseButton
@onready var _configure_button: TextureButton = %ConfigureButton
@onready var _method_count: Label = %MethodCountLabel
@onready var _skill_count: Label = %SkillCountLabel
@onready var _methods: VBoxContainer = %MethodsContainer
@onready var _skills: VBoxContainer = %SkillsContainer


func _ready() -> void:
	_close_button.pressed.connect(_go_back)
	_configure_button.pressed.connect(func() -> void: SceneManager.go_combat_loadout_panel())
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_back()
		get_viewport().set_input_as_handled()


func refresh() -> void:
	_bind_methods()
	_bind_skills()


func _bind_methods() -> void:
	_clear(_methods)
	var count := 0
	for method_id_v in GameState.unlocked_methods:
		var method_id := str(method_id_v).strip_edges()
		if method_id == "":
			continue
		var method := CultivationMethodServiceScript.by_id(method_id)
		if method.is_empty():
			continue
		count += 1
		var row := MethodRowScene.instantiate() as Control
		row.get_node("%TypeLabel").text = _method_type_label(method)
		row.get_node("%NameLabel").text = str(method.get("name", method_id))
		row.get_node("%MetaLabel").text = _method_meta(method, method_id)
		row.tooltip_text = str(method.get("description", method.get("desc", "")))
		_set_icon(row.get_node("%Icon") as TextureRect, _method_icon(method))
		_methods.add_child(row)
	_method_count.text = "已掌握 %d 门" % count
	if count == 0:
		_add_empty_method_row()


func _bind_skills() -> void:
	_clear(_skills)
	var count := 0
	for ability_id_v in GameState.unlocked_abilities:
		var ability_id := str(ability_id_v).strip_edges()
		if ability_id == "" or ability_id == "-1":
			continue
		var skill := AbilityServiceScript.to_runtime_dict(ability_id, GameState.to_dict())
		if skill.is_empty():
			continue
		count += 1
		var row := SkillRowScene.instantiate() as Control
		row.get_node("%PriorityLabel").text = str(count)
		row.get_node("%NameLabel").text = str(skill.get("name", ability_id))
		row.get_node("%MetaLabel").text = _skill_meta(skill, ability_id)
		row.tooltip_text = str(skill.get("desc", ""))
		_set_icon(row.get_node("%Icon") as TextureRect, _entry_icon(skill))
		_skills.add_child(row)
	_skill_count.text = "已掌握 %d 个" % count
	if count == 0:
		_add_empty_skill_row()


func _add_empty_method_row() -> void:
	var row := MethodRowScene.instantiate() as Control
	row.get_node("%TypeLabel").text = "功法"
	row.get_node("%NameLabel").text = "尚未掌握功法"
	row.get_node("%MetaLabel").text = "研读功法典籍后会出现在这里"
	_set_icon(row.get_node("%Icon") as TextureRect, null)
	_methods.add_child(row)


func _add_empty_skill_row() -> void:
	var row := SkillRowScene.instantiate() as Control
	row.get_node("%PriorityLabel").text = "-"
	row.get_node("%NameLabel").text = "尚未掌握技能"
	row.get_node("%MetaLabel").text = "研读技能典籍后会出现在这里"
	_set_icon(row.get_node("%Icon") as TextureRect, null)
	_skills.add_child(row)


func _method_type_label(method: Dictionary) -> String:
	var family := CultivationMethodServiceScript.family_by_id(str(method.get("familyId", "")))
	var role := str(family.get("role", "")).strip_edges()
	if role != "":
		return role
	if bool(method.get("is_movement", false)) or str(method.get("slot_type", "")) == "movement":
		return "身法"
	return "功法"


func _method_meta(method: Dictionary, method_id: String) -> String:
	var parts: PackedStringArray = []
	var realm := str(method.get("realm", "")).strip_edges()
	if realm != "":
		parts.append("境界 %s" % realm)
	var mastery := CultivationMethodServiceScript.method_mastery(GameState.to_dict(), method_id)
	parts.append("熟练 %.0f%%" % (mastery * 100.0))
	var practice: Dictionary = method.get("practice", {}) as Dictionary
	if not practice.is_empty():
		parts.append("修炼速度 x%.2f" % float(practice.get("efficiency", 1.0)))
	return "    ".join(parts)


func _skill_meta(skill: Dictionary, ability_id: String) -> String:
	var parts: PackedStringArray = []
	var tags: Array = skill.get("tags", []) as Array
	parts.append(_skill_category_label(tags))
	var cost := str(skill.get("cost_text", "")).strip_edges()
	if cost != "":
		parts.append(cost)
	var cooldown := float(skill.get("cd_total", skill.get("cd", 0.0)))
	if cooldown > 0.0:
		parts.append("冷却 %.1fs" % cooldown)
	var mastery := AbilityServiceScript.knowledge_mastery_ratio(ability_id, GameState.to_dict())
	if mastery > 0.0:
		parts.append("知识加成 %.0f%%" % (mastery * 100.0))
	return "    ".join(parts)


func _skill_category_label(tags: Array) -> String:
	if tags.has("attack") or tags.has("fire") or tags.has("poison"):
		return "攻击"
	if tags.has("shield"):
		return "防御"
	if tags.has("heal") or tags.has("restore"):
		return "恢复"
	if tags.has("mobility"):
		return "身法"
	return "辅助"


func _method_icon(method: Dictionary) -> Texture2D:
	if method.has("icon") and method.get("icon") != null:
		return _entry_icon(method)
	if _method_type_label(method) == "身法":
		return BattleInitDataScript._resolve_icon_texture({"icon": "ui_new/skill_04.png"})
	return BattleInitDataScript._resolve_icon_texture({"icon": "ui_new/gongfa.png"})


func _entry_icon(entry: Dictionary) -> Texture2D:
	if entry.is_empty() or not entry.has("icon") or entry.get("icon") == null:
		return null
	return BattleInitDataScript._resolve_icon_texture(entry)


func _set_icon(icon: TextureRect, texture: Texture2D) -> void:
	icon.texture = texture
	icon.visible = texture != null


func _clear(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()


func _go_back() -> void:
	SceneManager.go_back()
