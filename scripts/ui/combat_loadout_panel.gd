extends Control

const CultivationMethodServiceScript := preload("res://scripts/sim/cultivation_method_service.gd")
const InventoryServiceScript := preload("res://scripts/sim/inventory_service.gd")

@onready var _close_button: TextureButton = %CloseButton
@onready var _back_button: TextureButton = %BackButton
@onready var _methods: VBoxContainer = %MethodsContainer
@onready var _method_summary: Label = %MethodSummaryLabel
@onready var _skills: VBoxContainer = %SkillsContainer
@onready var _equipment: GridContainer = %EquipmentContainer
@onready var _auto: VBoxContainer = %AutoContainer
@onready var _books: HBoxContainer = %BooksContainer
@onready var _status: Label = %StatusLabel


func _ready() -> void:
	_close_button.pressed.connect(_go_back)
	_back_button.pressed.connect(_go_back)
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
	_clear(_books)
	_build_methods()
	_build_skills()
	_build_equipment()
	_build_auto_strategy()
	_build_books()
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
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = 55
		var label := Label.new()
		label.text = str(spec["label"])
		label.custom_minimum_size.x = 76
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(label)
		var option := OptionButton.new()
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for method_id_v in GameState.unlocked_methods:
			var method_id := str(method_id_v)
			var method := CultivationMethodServiceScript.by_id(method_id)
			if not CultivationMethodServiceScript.can_equip(method, slot_key):
				continue
			option.add_item(str(method.get("name", method_id)))
			option.set_item_metadata(option.item_count - 1, method_id)
			if str(GameState.cultivation_method_slots.get(slot_key, "")) == method_id:
				option.select(option.item_count - 1)
		option.item_selected.connect(_on_method_selected.bind(option, slot_key))
		row.add_child(option)
		_methods.add_child(row)
	var main := CultivationMethodServiceScript.by_id(str(GameState.cultivation_method_slots.get("main", "")))
	_method_summary.text = "当前主修：%s\n修炼速度 ×%.2f\n战斗每 2 秒恢复 %.0f 法力" % [
		str(main.get("name", "未配置")),
		CultivationMethodServiceScript.cultivation_speed(GameState.cultivation_method_slots),
		float(main.get("combat_mp_restore_2s", 0.0)),
	]


func _build_skills() -> void:
	for i in 5:
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = 62
		var badge := Label.new()
		badge.text = str(i + 1)
		badge.custom_minimum_size = Vector2(36, 36)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(badge)
		var option := OptionButton.new()
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option.add_item("空槽位")
		option.set_item_metadata(0, -1)
		for sid_v in GameState.unlocked_skills:
			var sid := int(sid_v)
			var skill := ConfigManager.skill_by_id(sid)
			if skill.is_empty():
				continue
			option.add_item(str(skill.get("name", "技能 %d" % sid)))
			option.set_item_metadata(option.item_count - 1, sid)
			if i < GameState.equipped_skills.size() and int(GameState.equipped_skills[i]) == sid:
				option.select(option.item_count - 1)
		option.item_selected.connect(_on_skill_selected.bind(option, i))
		row.add_child(option)
		_skills.add_child(row)


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


func _build_books() -> void:
	var found := false
	for item_id_v in GameState.inventory.keys():
		var item_id := str(item_id_v)
		var def := ConfigManager.item_def_by_id(item_id)
		if def == null or (def.learn_skill_id < 0 and def.learn_method_id == ""):
			continue
		found = true
		var button := Button.new()
		button.text = "%s ×%d" % [def.name, int(GameState.inventory.get(item_id, 0))]
		button.custom_minimum_size = Vector2(150, 42)
		button.pressed.connect(_learn_book.bind(item_id))
		_books.add_child(button)
	if not found:
		var empty := Label.new()
		empty.text = "暂无可学习典籍"
		_books.add_child(empty)


func _add_equipment_button(text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(150, 76)
	button.pressed.connect(action)
	_equipment.add_child(button)


func _on_method_selected(index: int, option: OptionButton, slot_key: String) -> void:
	var result: Dictionary = GameState.equip_method(slot_key, str(option.get_item_metadata(index)))
	_refresh(str(result.get("error", "功法配置已更新。")))


func _on_skill_selected(index: int, option: OptionButton, slot_index: int) -> void:
	var sid := int(option.get_item_metadata(index))
	if sid < 0:
		var slots := GameState.equipped_skills.duplicate(true)
		while slots.size() < 5:
			slots.append(-1)
		slots[slot_index] = -1
		GameState.equipped_skills = slots
		_refresh("技能槽已清空。")
		return
	var result: Dictionary = GameState.equip_skill(slot_index, sid)
	_refresh(str(result.get("error", "技能配置已更新。")))


func _cycle_equip(index: int) -> void:
	InventoryServiceScript.cycle_equip_slot(GameState.owned_equips, GameState.equip_slots, index)
	_refresh("法宝配置已更新。")


func _cycle_item(index: int) -> void:
	InventoryServiceScript.cycle_item_slot(GameState.inventory, GameState.item_slots, index)
	_refresh("道具配置已更新。")


func _learn_book(item_id: String) -> void:
	var result: Dictionary = GameState.use_learning_book(item_id)
	_refresh(str(result.get("error", "典籍学习成功。")))


func _equip_name(index: int) -> String:
	var eid := int(GameState.equip_slots[index]) if index < GameState.equip_slots.size() else -1
	return str(ConfigManager.equip_by_id(eid).get("name", "空"))


func _item_name(index: int) -> String:
	var iid := str(GameState.item_slots[index]) if index < GameState.item_slots.size() else ""
	return ConfigManager.get_item_display_name(iid) if iid != "" else "空"


func _clear(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()


func _go_back() -> void:
	SceneManager.go_back()
