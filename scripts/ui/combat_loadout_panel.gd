extends Control

const CultivationMethodServiceScript := preload("res://scripts/sim/cultivation_method_service.gd")
const AbilityServiceScript := preload("res://scripts/dao/ability_service.gd")
const EffectResolverScript := preload("res://scripts/dao/effect_resolver.gd")
const BattleInitDataScript := preload("res://scripts/fight/battle_init_data.gd")

const METHOD_ROWS := [
	{"node": "Main", "key": "main", "label": "主功法"},
	{"node": "Support1", "key": "support_1", "label": "辅助一"},
	{"node": "Support2", "key": "support_2", "label": "辅助二"},
	{"node": "Movement", "key": "movement", "label": "身法"},
]

@onready var _close_button: TextureButton = %CloseButton
@onready var _fightset_button: TextureButton = %FightsetButton
@onready var _save_button: TextureButton = %SaveButton
@onready var _methods: VBoxContainer = %MethodsContainer
@onready var _method_summary: Label = %MethodSummaryLabel
@onready var _skills: VBoxContainer = %SkillsContainer
@onready var _treasure_slots: HBoxContainer = $Panel/EquipmentCard/TreasurePanel/Slots
@onready var _item_slots: GridContainer = %EquipmentContainer
@onready var _status: Label = %StatusLabel
@onready var _selection_popup: LoadoutSelectionPopup = %SelectionPopup
@onready var _bag_popup = %BagPopup

var _selection_mode := ""
var _selection_target: Variant = -1
var _wired := false


func _ready() -> void:
	_close_button.pressed.connect(_go_back)
	_fightset_button.pressed.connect(_on_fightset_pressed)
	_save_button.pressed.connect(_on_save_pressed)
	_selection_popup.selected.connect(_on_popup_selected)
	_bag_popup.entry_picked.connect(_on_bag_entry_picked)
	_wire_interactions()
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_back()
		get_viewport().set_input_as_handled()


func _wire_interactions() -> void:
	if _wired:
		return
	_wired = true
	for spec in METHOD_ROWS:
		var row := _methods.get_node(str(spec["node"])) as Control
		_make_clickable(row, _open_selection.bind("method", spec["key"]))
	for i in _skills.get_child_count():
		_make_clickable(_skills.get_child(i) as Control, _open_selection.bind("skill", i))
	for i in _treasure_slots.get_child_count():
		_make_clickable(_treasure_slots.get_child(i) as Control, _open_equip_picker.bind(i))
	for i in _item_slots.get_child_count():
		_make_clickable(_item_slots.get_child(i) as Control, _open_item_picker.bind(i))


func _make_clickable(control: Control, action: Callable) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	control.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mouse := event as InputEventMouseButton
			if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
				action.call()
	)


func _refresh(message: String = "") -> void:
	_bind_methods()
	_bind_skills()
	_bind_treasure()
	_bind_items()
	_bind_method_summary()
	_status.text = message if message != "" else "点击功法、技能调整配置；点击法宝或道具槽位打开背包装备。"


func _bind_methods() -> void:
	for spec in METHOD_ROWS:
		var slot_key := str(spec["key"])
		var method_id := str(GameState.cultivation_method_slots.get(slot_key, ""))
		var method := CultivationMethodServiceScript.by_id(method_id)
		_bind_method_row(
			_methods.get_node(str(spec["node"])) as Control,
			str(spec["label"]),
			method
		)


func _bind_method_row(row: Control, type_label: String, method: Dictionary) -> void:
	row.get_node("%TypeLabel").text = type_label
	var name_label := row.get_node("%NameLabel") as Label
	name_label.text = str(method.get("name", "空槽位"))
	name_label.add_theme_color_override("font_color", EnumQuality.get_color(_entry_quality(method)))
	row.get_node("%MetaLabel").text = _method_effect(method)
	row.tooltip_text = str(method.get("desc", "点击选择功法"))
	var icon := row.get_node("%Icon") as TextureRect
	var texture := _entry_icon(method)
	icon.texture = texture
	icon.visible = texture != null


func _bind_method_summary() -> void:
	var main := CultivationMethodServiceScript.by_id(str(GameState.cultivation_method_slots.get("main", "")))
	var mastery := CultivationMethodServiceScript.method_mastery_value_ratio(
		GameState.to_dict(), str(main.get("id", ""))
	)
	var mp_restore := EffectResolverScript.combat_mp_restore_from_method(
		main.get("effects", []) as Array, mastery
	)
	_method_summary.text = "当前主修：%s\n修炼速度 ×%.2f\n战斗每 2 秒恢复 %.0f 法力" % [
		str(main.get("name", "未配置")),
		CultivationMethodServiceScript.cultivation_speed(GameState.cultivation_method_slots),
		mp_restore,
	]


func _bind_skills() -> void:
	for i in _skills.get_child_count():
		var aid := str(GameState.equipped_abilities[i]) if i < GameState.equipped_abilities.size() else ""
		var sid := AbilityServiceScript.combat_id_for(aid)
		var skill := AbilityServiceScript.to_runtime_dict(aid, GameState.to_dict()) if aid != "" else {}
		var row := _skills.get_child(i) as Control
		row.get_node("%PriorityLabel").text = str(i + 1)
		var name_label := row.get_node("%NameLabel") as Label
		name_label.text = str(skill.get("name", "空槽位"))
		name_label.add_theme_color_override("font_color", EnumQuality.get_color(_entry_quality(skill)))
		row.get_node("%MetaLabel").text = _skill_effect(skill)
		row.tooltip_text = "点击选择第 %d 顺位技能" % (i + 1)
		var icon := row.get_node("%Icon") as TextureRect
		var texture := _entry_icon(skill)
		icon.texture = texture
		icon.visible = texture != null


func _bind_treasure() -> void:
	for i in _treasure_slots.get_child_count():
		var slot := _treasure_slots.get_child(i) as Control
		_bind_equipment_slot(slot, _equip_entry(i))
		slot.tooltip_text = "点击打开背包，选择法宝装备"


func _bind_items() -> void:
	for i in _item_slots.get_child_count():
		var slot := _item_slots.get_child(i) as Control
		_bind_equipment_slot(slot, _item_entry(i))
		slot.tooltip_text = "点击打开背包，选择战斗道具"


func _bind_equipment_slot(slot: Control, entry: Dictionary) -> void:
	slot.get_node("%NameLabel").text = str(entry.get("label", "空"))
	var icon := slot.get_node("%Icon") as TextureRect
	var texture: Texture2D = entry.get("icon")
	icon.texture = texture
	icon.visible = texture != null


func _equip_entry(index: int) -> Dictionary:
	var item_id := ""
	if index < GameState.treasure_item_slots.size():
		item_id = str(GameState.treasure_item_slots[index]).strip_edges()
	if item_id != "":
		var def := ConfigManager.item_def_by_id(item_id)
		if def != null:
			var runtime := def.to_fight_runtime_dict()
			return {
				"label": def.name,
				"icon": _entry_icon(runtime),
			}
		return {"label": ConfigManager.get_item_display_name(item_id)}
	var eid := int(GameState.equip_slots[index]) if index < GameState.equip_slots.size() else -1
	if eid <= 0:
		return {"label": "空"}
	var equip := ConfigManager.equip_by_id(eid)
	return {
		"label": str(equip.get("name", "空")),
		"icon": _entry_icon(equip),
	}


func _item_entry(index: int) -> Dictionary:
	var iid := str(GameState.item_slots[index]) if index < GameState.item_slots.size() else ""
	if iid == "":
		return {"label": "空"}
	var item_name := ConfigManager.get_item_display_name(iid)
	var count := int(GameState.inventory.get(iid, 0))
	var label := "%s x%d" % [item_name, count] if count > 1 else item_name
	var icon: Texture2D = null
	var def := ConfigManager.item_def_by_id(iid)
	if def != null:
		icon = _entry_icon(def.to_fight_runtime_dict())
	return {
		"label": label,
		"icon": icon,
	}


func _open_selection(mode: String, target: Variant) -> void:
	_selection_mode = mode
	_selection_target = target
	_selection_popup.open_for(mode, target)


func _on_popup_selected(entry_id: Variant) -> void:
	if _selection_mode == "method":
		var method_result: Dictionary = GameState.equip_method(str(_selection_target), str(entry_id))
		_refresh(str(method_result.get("error", "功法配置已更新。")))
		return
	var aid := str(entry_id).strip_edges()
	if aid == "" or aid == "-1":
		var slots := DataStore._normalize_ability_slots(GameState.equipped_abilities)
		slots[int(_selection_target)] = ""
		GameState.equipped_abilities = slots
		_refresh("技能槽已清空。")
		return
	var skill_result: Dictionary = GameState.equip_ability(int(_selection_target), aid)
	_refresh(str(skill_result.get("error", "技能配置已更新。")))


func _open_equip_picker(slot_index: int) -> void:
	_bag_popup.open_for_equip(slot_index)


func _open_item_picker(slot_index: int) -> void:
	_bag_popup.open_for_item(slot_index)


func _on_bag_entry_picked(entry: Dictionary) -> void:
	var slot_index := int(entry.get("loadout_slot", -1))
	var kind := str(entry.get("loadout_kind", ""))
	if kind == "equip":
		var result: Dictionary
		if str(entry.get("kind", "item")) == "item":
			result = GameState.assign_treasure_item_slot(slot_index, str(entry.get("id", "")))
		else:
			result = GameState.assign_equip_slot(slot_index, int(entry.get("id", -1)))
		_refresh(_loadout_message(result, "法宝配置已更新。"))
		return
	if kind == "item":
		var result: Dictionary = GameState.assign_item_slot(slot_index, str(entry.get("id", "")))
		_refresh(_loadout_message(result, "道具配置已更新。"))
		return
	_refresh("配置失败。")


func _loadout_message(result: Dictionary, fallback: String) -> String:
	if not bool(result.get("ok", false)):
		return str(result.get("error", fallback))
	return str(result.get("message", fallback))


func _on_fightset_pressed() -> void:
	SceneManager.go_skill_release_strategy_panel()


func _on_save_pressed() -> void:
	_refresh("战斗配置已保存。")


func _method_effect(method: Dictionary) -> String:
	if method.is_empty():
		return "点击选择功法"
	var parts: PackedStringArray = [
		EnumItemTier.label(_entry_tier(method)),
		EnumQuality.display_label(_entry_quality(method)),
	]
	if float(method.get("combat_mp_restore_2s", 0.0)) > 0.0:
		parts.append("每 2 秒恢复 %.0f 法力" % float(method.get("combat_mp_restore_2s", 0.0)))
	else:
		parts.append(str(method.get("desc", "提供修炼与战斗加成")))
	return " · ".join(parts)


func _skill_effect(skill: Dictionary) -> String:
	if skill.is_empty():
		return "未配置技能"
	var parts: PackedStringArray = [
		EnumItemTier.label(_entry_tier(skill)),
		EnumQuality.display_label(_entry_quality(skill)),
	]
	var effects := skill.get("effects", []) as Array
	if effects.is_empty():
		parts.append("基础战斗行动")
		return " · ".join(parts)
	match str((effects[0] as Dictionary).get("type", "")):
		"damage": parts.append("对敌人造成伤害")
		"shield": parts.append("为自身提供护盾")
		"heal": parts.append("恢复自身气血")
		"restore_mp": parts.append("恢复自身法力")
		_: parts.append("提供战斗辅助效果")
	return " · ".join(parts)


func _entry_icon(entry: Dictionary) -> Texture2D:
	if entry.is_empty() or not entry.has("icon") or entry.get("icon") == null:
		return null
	return BattleInitDataScript._resolve_icon_texture(entry)


func _entry_quality(entry: Dictionary) -> int:
	return clampi(int(entry.get("quality", 1)), EnumQuality.Type.LOW, EnumQuality.Type.SUPREME)


func _entry_tier(entry: Dictionary) -> int:
	return EnumItemTier.clamp_tier(int(entry.get("tier", 1)))


func _go_back() -> void:
	SceneManager.go_back()
