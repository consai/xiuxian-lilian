extends Control

const InventoryServiceScript := preload("res://scripts/sim/inventory_service.gd")

var _status: Label
var _message: RichTextLabel
var _inventory_label: RichTextLabel
var _equip_buttons: Array[Button] = []
var _item_buttons: Array[Button] = []
var _save_panel: VBoxContainer


func _ready() -> void:
	_build_ui()
	_refresh()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#f1dfc2")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	var title := Label.new()
	title.text = "清风洞府 · 修行日程"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	root.add_child(title)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 20)
	root.add_child(_status)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 18)
	root.add_child(columns)

	var actions := _panel("今日安排")
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(actions)
	_add_button(actions, "修炼一日", _on_cultivate)
	_add_button(actions, "外出历练", _on_encounter)
	_add_button(actions, "静养休息", _on_rest)
	_add_button(actions, "主动突破", _on_breakthrough, "BreakthroughButton")

	var prep := _panel("洞府整备")
	prep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(prep)
	var skill_label := Label.new()
	skill_label.text = "技能：火焰弹 / 火焰盾 / 毒 / 普攻"
	skill_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prep.add_child(skill_label)
	for i in 2:
		var button := Button.new()
		button.pressed.connect(_cycle_equip.bind(i))
		prep.add_child(button)
		_equip_buttons.append(button)
	for i in 2:
		var button := Button.new()
		button.pressed.connect(_cycle_item.bind(i))
		prep.add_child(button)
		_item_buttons.append(button)

	var records := _panel("背包与记录")
	records.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(records)
	_inventory_label = RichTextLabel.new()
	_inventory_label.fit_content = true
	_inventory_label.bbcode_enabled = true
	_inventory_label.custom_minimum_size = Vector2(250, 260)
	records.add_child(_inventory_label)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	root.add_child(footer)
	_message = RichTextLabel.new()
	_message.bbcode_enabled = true
	_message.fit_content = true
	_message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_message)
	_add_button(footer, "存档 / 读档", _toggle_save_panel)
	_add_button(footer, "新开修行", _new_game)

	_save_panel = _panel("三槽手动存档")
	_save_panel.visible = false
	root.add_child(_save_panel)
	for slot in range(1, 4):
		var row := HBoxContainer.new()
		var label := Label.new()
		label.name = "SlotLabel%d" % slot
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		_add_button(row, "保存", _save.bind(slot))
		_add_button(row, "读取", _load.bind(slot))
		_save_panel.add_child(row)


func _panel(title_text: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 23)
	box.add_child(title)
	return box


func _add_button(parent: Node, text: String, action: Callable, node_name: String = "") -> Button:
	var button := Button.new()
	if node_name != "":
		button.name = node_name
	button.text = text
	button.custom_minimum_size = Vector2(150, 42)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _refresh(message: String = "") -> void:
	_status.text = "第 %d 日   %s   修为 %d/%d   气血 %.0f/%.0f   法力 %.0f/%.0f   伤势 %d 日" % [
		GameState.day, GameState.realm_name, GameState.cultivation, GameState.breakthrough_at,
		GameState.hp, float(GameState.attrs.get(FightAttr.HP_MAX, 100.0)),
		GameState.mp, float(GameState.attrs.get(FightAttr.MP_MAX, 100.0)), GameState.injury_days
	]
	var breakthrough := find_child("BreakthroughButton", true, false) as Button
	if breakthrough != null:
		breakthrough.disabled = not GameState.can_breakthrough()
	for i in _equip_buttons.size():
		var eid := int(GameState.equip_slots[i])
		_equip_buttons[i].text = "法宝槽 %d：%s（点击切换）" % [i + 1, _equip_name(eid)]
	for i in _item_buttons.size():
		var iid := str(GameState.item_slots[i])
		_item_buttons[i].text = "丹药槽 %d：%s（点击切换）" % [i + 1, _item_name(iid)]
	var lines: PackedStringArray = ["[b]灵石：%d[/b]" % GameState.ling_stones]
	for iid_v in GameState.inventory.keys():
		var iid := str(iid_v)
		lines.append("%s x%d" % [_item_name(iid), int(GameState.inventory[iid])])
	lines.append("")
	lines.append("[b]历练：%d  胜：%d  负：%d[/b]" % [
		int(GameState.totals.get("battles", 0)), int(GameState.totals.get("wins", 0)), int(GameState.totals.get("losses", 0))
	])
	_inventory_label.text = "\n".join(lines)
	var display := message
	if display == "" and not GameState.last_rewards.is_empty():
		var rewards: PackedStringArray = []
		for reward in GameState.last_rewards:
			rewards.append(GameState.reward_label(reward))
		display = "上次历练所得：" + "、".join(rewards)
	if display == "" and not GameState.activity_log.is_empty():
		display = str((GameState.activity_log.back() as Dictionary).get("text", ""))
	_message.text = display
	_refresh_save_slots()


func _on_cultivate() -> void:
	var gain: int = GameState.cultivate()
	_refresh("静心修炼一日，修为 +%d。" % gain)


func _on_rest() -> void:
	GameState.rest()
	_refresh("静养一日，气血与法力恢复，伤势减轻。")


func _on_encounter() -> void:
	get_tree().change_scene_to_file("res://scenes/sim/encounter_select.tscn")


func _on_breakthrough() -> void:
	var result: Dictionary = GameState.breakthrough()
	if bool(result.get("ok", false)):
		get_tree().root.set_meta("breakthrough_summary", result)
		get_tree().change_scene_to_file("res://scenes/sim/breakthrough_summary.tscn")
	else:
		_refresh(str(result.get("error", "无法突破")))


func _cycle_equip(index: int) -> void:
	InventoryServiceScript.cycle_equip_slot(GameState.owned_equips, GameState.equip_slots, index)
	_refresh()


func _cycle_item(index: int) -> void:
	InventoryServiceScript.cycle_item_slot(GameState.inventory, GameState.item_slots, index)
	_refresh()


func _toggle_save_panel() -> void:
	_save_panel.visible = not _save_panel.visible
	_refresh_save_slots()


func _save(slot: int) -> void:
	var result: Dictionary = SaveService.save_slot(slot, GameState.to_dict())
	_refresh("槽位 %d：%s" % [slot, "保存成功" if result.get("ok", false) else result.get("error", "保存失败")])


func _load(slot: int) -> void:
	var result: Dictionary = SaveService.load_slot(slot)
	if bool(result.get("ok", false)) and GameState.apply_dict(result["game"]):
		_refresh("已读取槽位 %d。" % slot)
	else:
		_refresh(str(result.get("error", "读取失败")))


func _new_game() -> void:
	GameState.new_game()
	_refresh("新的修行开始了。")


func _refresh_save_slots() -> void:
	if _save_panel == null:
		return
	for slot in range(1, 4):
		var label := _save_panel.find_child("SlotLabel%d" % slot, true, false) as Label
		var info: Dictionary = SaveService.slot_info(slot)
		label.text = "槽位 %d：%s" % [slot, "第%d日 %s 修为%d" % [info.day, info.realm_name, info.cultivation] if info.get("ok", false) else "空"]


func _equip_name(eid: int) -> String:
	if eid <= 0:
		return "空"
	return str(ConfigManager.equip_by_id(eid).get("name", "未知法宝"))


func _item_name(iid: String) -> String:
	if iid == "":
		return "空"
	return ConfigManager.get_item_display_name(iid)
