extends Control

const CultivationMethodServiceScript := preload("res://scripts/sim/cultivation_method_service.gd")
const InventoryServiceScript := preload("res://scripts/sim/inventory_service.gd")
const BattleInitDataScript := preload("res://scripts/fight/battle_init_data.gd")

@onready var _close_button: TextureButton = %CloseButton
@onready var _back_button: TextureButton = %BackButton
@onready var _methods: VBoxContainer = %MethodsContainer
@onready var _method_summary: Label = %MethodSummaryLabel
@onready var _skills: VBoxContainer = %SkillsContainer
@onready var _equipment: GridContainer = %EquipmentContainer
@onready var _auto: VBoxContainer = %AutoContainer
@onready var _status: Label = %StatusLabel
@onready var _selection_popup: LoadoutSelectionPopup = %SelectionPopup

var _selection_mode := ""
var _selection_target: Variant = -1


func _ready() -> void:
	_close_button.pressed.connect(_go_back)
	_back_button.pressed.connect(_go_back)
	_selection_popup.selected.connect(_on_popup_selected)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_back()
		get_viewport().set_input_as_handled()


func _refresh(message: String = "") -> void:
	_clear(_methods)
	_clear(_skills)
	_clear(_equipment)
	_clear(_auto)
	_build_methods()
	_build_skills()
	_build_equipment()
	_build_auto_strategy()
	_status.text = message if message != "" else "点击功法、技能、法宝或道具槽位即可调整配置。"


func _build_methods() -> void:
	var specs := [
		{"key": "main", "label": "主功法"},
		{"key": "support_1", "label": "辅助一"},
		{"key": "support_2", "label": "辅助二"},
		{"key": "movement", "label": "身法"},
	]
	for spec in specs:
		var slot_key := str(spec["key"])
		var method_id := str(GameState.cultivation_method_slots.get(slot_key, ""))
		var method := CultivationMethodServiceScript.by_id(method_id)
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 54)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = "%s  |  %s\n%s" % [
			str(spec["label"]),
			str(method.get("name", "空槽位")),
			_method_effect(method),
		]
		button.tooltip_text = str(method.get("desc", "点击选择功法"))
		button.icon = _entry_icon(method)
		button.expand_icon = true
		button.pressed.connect(_open_selection.bind("method", slot_key))
		_methods.add_child(button)
	var main := CultivationMethodServiceScript.by_id(str(GameState.cultivation_method_slots.get("main", "")))
	_method_summary.text = "当前主修：%s\n修炼速度 ×%.2f\n战斗每 2 秒恢复 %.0f 法力" % [
		str(main.get("name", "未配置")),
		CultivationMethodServiceScript.cultivation_speed(GameState.cultivation_method_slots),
		float(main.get("combat_mp_restore_2s", 0.0)),
	]


func _build_skills() -> void:
	for i in 5:
		var sid := int(GameState.equipped_skills[i]) if i < GameState.equipped_skills.size() else -1
		var skill := ConfigManager.skill_by_id(sid)
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 54)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = "%d    %s\n%s" % [
			i + 1,
			str(skill.get("name", "空槽位")),
			_skill_effect(skill),
		]
		button.tooltip_text = "点击选择第 %d 顺位技能" % (i + 1)
		button.icon = _entry_icon(skill)
		button.expand_icon = true
		button.pressed.connect(_open_selection.bind("skill", i))
		_skills.add_child(button)


func _build_equipment() -> void:
	for i in 2:
		_add_equipment_button("法宝 %d\n%s" % [i + 1, _equip_name(i)], _cycle_equip.bind(i))
	for i in 2:
		_add_equipment_button("道具 %d\n%s" % [i + 1, _item_name(i)], _cycle_item.bind(i))


func _build_auto_strategy() -> void:
	var row := HBoxContainer.new()
	var enabled := CheckButton.new()
	enabled.text = "历练自动战斗"
	enabled.button_pressed = GameState.auto_battle_enabled
	enabled.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enabled.toggled.connect(func(value: bool) -> void:
		GameState.auto_battle_enabled = value
		_status.text = "历练自动战斗已%s。" % ("开启" if value else "关闭")
	)
	row.add_child(enabled)
	var preset := OptionButton.new()
	for entry in [["balanced", "均衡"], ["aggressive", "进攻"], ["conservative", "保守"]]:
		preset.add_item(str(entry[1]))
		preset.set_item_metadata(preset.item_count - 1, str(entry[0]))
		if GameState.auto_battle_preset == str(entry[0]):
			preset.select(preset.item_count - 1)
	preset.item_selected.connect(func(index: int) -> void:
		GameState.auto_battle_preset = str(preset.get_item_metadata(index))
		GameState.auto_battle_rules = {}
		_status.text = "自动战斗策略已切换为%s。" % preset.get_item_text(index)
	)
	row.add_child(preset)
	_auto.add_child(row)
	var note := Label.new()
	note.text = "均衡按槽位施法；进攻优先输出；保守低血先用道具。"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_auto.add_child(note)


func _add_equipment_button(text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(150, 76)
	button.pressed.connect(action)
	_equipment.add_child(button)


func _open_selection(mode: String, target: Variant) -> void:
	_selection_mode = mode
	_selection_target = target
	_selection_popup.open_for(mode, target)


func _on_popup_selected(entry_id: Variant) -> void:
	if _selection_mode == "method":
		var result: Dictionary = GameState.equip_method(str(_selection_target), str(entry_id))
		_refresh(str(result.get("error", "功法配置已更新。")))
		return
	var sid := int(entry_id)
	if sid < 0:
		var slots := GameState.equipped_skills.duplicate(true)
		while slots.size() < 5:
			slots.append(-1)
		slots[int(_selection_target)] = -1
		GameState.equipped_skills = slots
		_refresh("技能槽已清空。")
		return
	var result: Dictionary = GameState.equip_skill(int(_selection_target), sid)
	_refresh(str(result.get("error", "技能配置已更新。")))


func _cycle_equip(index: int) -> void:
	InventoryServiceScript.cycle_equip_slot(GameState.owned_equips, GameState.equip_slots, index)
	_refresh("法宝配置已更新。")


func _cycle_item(index: int) -> void:
	InventoryServiceScript.cycle_item_slot(GameState.inventory, GameState.item_slots, index)
	_refresh("道具配置已更新。")


func _equip_name(index: int) -> String:
	var eid := int(GameState.equip_slots[index]) if index < GameState.equip_slots.size() else -1
	return str(ConfigManager.equip_by_id(eid).get("name", "空"))


func _item_name(index: int) -> String:
	var iid := str(GameState.item_slots[index]) if index < GameState.item_slots.size() else ""
	return ConfigManager.get_item_display_name(iid) if iid != "" else "空"


func _method_effect(method: Dictionary) -> String:
	if method.is_empty():
		return "点击选择功法"
	if float(method.get("combat_mp_restore_2s", 0.0)) > 0.0:
		return "每 2 秒恢复 %.0f 法力" % float(method.get("combat_mp_restore_2s", 0.0))
	return str(method.get("desc", "提供修炼与战斗加成"))


func _skill_effect(skill: Dictionary) -> String:
	if skill.is_empty():
		return "未配置技能"
	var effects := skill.get("effects", []) as Array
	if effects.is_empty():
		return "基础战斗行动"
	match str((effects[0] as Dictionary).get("type", "")):
		"damage": return "对敌人造成伤害"
		"shield": return "为自身提供护盾"
		"heal": return "恢复自身气血"
		"restore_mp": return "恢复自身法力"
		_: return "提供战斗辅助效果"


func _entry_icon(entry: Dictionary) -> Texture2D:
	if entry.is_empty() or not entry.has("icon") or entry.get("icon") == null:
		return null
	return BattleInitDataScript._resolve_icon_texture(entry)


func _clear(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()


func _go_back() -> void:
	SceneManager.go_back()
