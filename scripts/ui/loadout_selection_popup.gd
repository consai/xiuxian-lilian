class_name LoadoutSelectionPopup
extends Control

const CultivationMethodServiceScript := preload("res://scripts/sim/cultivation_method_service.gd")
const BattleInitDataScript := preload("res://scripts/fight/battle_init_data.gd")

signal selected(entry_id: Variant)
signal closed

var _mode := "skill"
var _target_key: Variant = -1
var _filter := "all"

@onready var _title: Label = %Title
@onready var _filters: HBoxContainer = %Filters
@onready var _entries: VBoxContainer = %Entries
@onready var _close_button: TextureButton = %CloseButton


func _ready() -> void:
	_close_button.pressed.connect(_close)
	visible = false


func open_for(mode: String, target_key: Variant) -> void:
	_mode = mode
	_target_key = target_key
	_filter = "all"
	_title.text = "功法列表" if mode == "method" else "技能列表"
	_build_filters()
	_build_entries()
	visible = true


func _build_filters() -> void:
	_clear(_filters)
	for spec in [
		["all", "全部"], ["attack", "攻击"], ["defense", "防御"],
		["support", "辅助"], ["movement", "身法"], ["recover", "恢复"],
	]:
		var key := str(spec[0])
		var button := Button.new()
		button.text = str(spec[1])
		button.custom_minimum_size = Vector2(88, 42)
		button.theme_type_variation = "TabActive" if key == _filter else "TabIdle"
		button.pressed.connect(_set_filter.bind(key))
		_filters.add_child(button)


func _build_entries() -> void:
	_clear(_entries)
	if _mode == "method":
		_build_method_entries()
	else:
		_build_skill_entries()


func _build_method_entries() -> void:
	for method_id_v in GameState.unlocked_methods:
		var method_id := str(method_id_v)
		var row := CultivationMethodServiceScript.by_id(method_id)
		if not CultivationMethodServiceScript.can_equip(row, str(_target_key)):
			continue
		var category := _method_category(row)
		if _filter != "all" and category != _filter:
			continue
		var equipped := GameState.cultivation_method_slots.values().has(method_id)
		_add_entry(method_id, row, category, equipped)


func _build_skill_entries() -> void:
	for skill_id_v in GameState.unlocked_skills:
		var skill_id := int(skill_id_v)
		var row := ConfigManager.skill_by_id(skill_id)
		if row.is_empty():
			continue
		var category := _skill_category(row)
		if _filter != "all" and category != _filter:
			continue
		var equipped := GameState.equipped_skills.has(skill_id)
		_add_entry(skill_id, row, category, equipped)
	_add_empty_skill_entry()


func _add_entry(entry_id: Variant, row: Dictionary, category: String, equipped: bool) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 82)
	button.text = "%s    [%s]\n%s" % [
		str(row.get("name", "未命名")),
		_category_label(category),
		str(row.get("desc", _skill_description(row))),
	]
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.icon = _entry_icon(row)
	button.expand_icon = true
	button.disabled = equipped and _is_equipped_at_target(entry_id)
	if button.disabled:
		button.text += "    已装备"
	button.pressed.connect(_choose.bind(entry_id))
	_entries.add_child(button)


func _add_empty_skill_entry() -> void:
	if _filter != "all":
		return
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 66)
	button.text = "清空槽位\n移除当前已装备技能"
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(_choose.bind(-1))
	_entries.add_child(button)


func _set_filter(key: String) -> void:
	_filter = key
	_build_filters()
	_build_entries()


func _choose(entry_id: Variant) -> void:
	selected.emit(entry_id)
	_close()


func _close() -> void:
	visible = false
	closed.emit()


func _is_equipped_at_target(entry_id: Variant) -> bool:
	if _mode == "method":
		return str(GameState.cultivation_method_slots.get(str(_target_key), "")) == str(entry_id)
	var index := int(_target_key)
	return index >= 0 and index < GameState.equipped_skills.size() and int(GameState.equipped_skills[index]) == int(entry_id)


func _entry_icon(row: Dictionary) -> Texture2D:
	if row.is_empty() or not row.has("icon") or row.get("icon") == null:
		return null
	return BattleInitDataScript._resolve_icon_texture(row)


func _method_category(row: Dictionary) -> String:
	var slot_type := str(row.get("slot_type", ""))
	if slot_type == "movement":
		return "movement"
	var flat := row.get("flat_attrs", {}) as Dictionary
	if flat.has(FightAttr.HP_MAX) or flat.has(FightAttr.PHYSICAL_DEF):
		return "defense"
	if float(row.get("combat_mp_restore_2s", 0.0)) > 0.0:
		return "recover"
	return "support"


func _skill_category(row: Dictionary) -> String:
	var tags := row.get("tags", []) as Array
	if tags.has("attack") or tags.has("fire") or tags.has("poison"):
		return "attack"
	if tags.has("shield"):
		return "defense"
	return "support"


func _skill_description(row: Dictionary) -> String:
	var effects := row.get("effects", []) as Array
	if effects.is_empty():
		return "基础战斗行动。"
	var first := effects[0] as Dictionary
	match str(first.get("type", "")):
		"damage": return "对敌人造成伤害。"
		"shield": return "为自身提供护盾。"
		"heal": return "恢复自身气血。"
		"restore_mp": return "恢复自身法力。"
		_: return "提供战斗辅助效果。"


func _category_label(category: String) -> String:
	return {
		"attack": "攻击", "defense": "防御", "support": "辅助",
		"movement": "身法", "recover": "恢复",
	}.get(category, "辅助")


func _clear(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()
