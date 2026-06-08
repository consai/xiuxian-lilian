extends Control

const InventoryServiceScript := preload("res://scripts/sim/inventory_service.gd")

@onready var _realm_label: Label = %RealmLabel
@onready var _status_label: Label = %StatusLabel
@onready var _message_label: Label = %MessageLabel
@onready var _inventory_label: RichTextLabel = %InventoryLabel
@onready var _inventory_overlay: Control = %InventoryOverlay
@onready var _breakthrough_button: TextureButton = %BreakthroughButton
@onready var _save_panel: VBoxContainer = %SavePanel
@onready var _equip_buttons: Array[Button] = [%EquipButton1, %EquipButton2]
@onready var _item_buttons: Array[Button] = [%ItemButton1, %ItemButton2]


func _ready() -> void:
	_connect_actions()
	_refresh()


func _connect_actions() -> void:
	$FurnaceButton.pressed.connect(_on_alchemy)
	$StorageButton.pressed.connect(_toggle_inventory)
	$CultivateObjectButton.pressed.connect(_on_cultivate)
	$RestButton.pressed.connect(_on_rest)
	$ExpeditionObjectButton.pressed.connect(_on_encounter)
	$BackpackButton.pressed.connect(_toggle_inventory)
	$BottomActions/CultivateButton.pressed.connect(_on_cultivate)
	$BottomActions/BreakthroughButton.pressed.connect(_on_breakthrough)
	$BottomActions/ExpeditionButton.pressed.connect(_on_encounter)
	$InventoryOverlay/Content/Header/CloseButton.pressed.connect(_toggle_inventory)
	$InventoryOverlay/Content/UtilityRow/SavePanelButton.pressed.connect(_toggle_save_panel)
	$InventoryOverlay/Content/UtilityRow/NewGameButton.pressed.connect(_new_game)
	for i in _equip_buttons.size():
		_equip_buttons[i].pressed.connect(_cycle_equip.bind(i))
	for i in _item_buttons.size():
		_item_buttons[i].pressed.connect(_cycle_item.bind(i))
	for slot in range(1, 4):
		_save_panel.get_node("Slot%d/Save%d" % [slot, slot]).pressed.connect(_save.bind(slot))
		_save_panel.get_node("Slot%d/Load%d" % [slot, slot]).pressed.connect(_load.bind(slot))


func _refresh(message: String = "") -> void:
	var hp_max := float(GameState.attrs.get(FightAttr.HP_MAX, 100.0))
	var mp_max := float(GameState.attrs.get(FightAttr.MP_MAX, 100.0))
	_realm_label.text = "%s · 修为 %d/%d" % [
		GameState.realm_name, GameState.cultivation, GameState.breakthrough_at
	]
	_status_label.text = "第 %d 日  |  灵石 %d  |  气血 %.0f/%.0f  |  法力 %.0f/%.0f  |  伤势 %d 日" % [
		GameState.day, GameState.ling_stones, GameState.hp, hp_max,
		GameState.mp, mp_max, GameState.injury_days
	]
	_breakthrough_button.disabled = not GameState.can_breakthrough()
	_breakthrough_button.modulate = Color.WHITE if not _breakthrough_button.disabled else Color(0.65, 0.65, 0.65, 0.8)
	for i in _equip_buttons.size():
		_equip_buttons[i].text = "法宝槽 %d：%s（点击切换）" % [i + 1, _equip_name(int(GameState.equip_slots[i]))]
	for i in _item_buttons.size():
		_item_buttons[i].text = "丹药槽 %d：%s（点击切换）" % [i + 1, _item_name(str(GameState.item_slots[i]))]
	_refresh_inventory()
	_message_label.text = _resolve_message(message)
	_refresh_save_slots()


func _refresh_inventory() -> void:
	var lines: PackedStringArray = ["[b]灵石：%d[/b]" % GameState.ling_stones]
	if GameState.inventory.is_empty():
		lines.append("背包中暂无丹药与道具。")
	else:
		for iid_v in GameState.inventory.keys():
			var iid := str(iid_v)
			lines.append("%s x%d" % [_item_name(iid), int(GameState.inventory[iid])])
	lines.append("")
	lines.append("[b]历练：%d  胜：%d  负：%d[/b]" % [
		int(GameState.totals.get("battles", 0)),
		int(GameState.totals.get("wins", 0)),
		int(GameState.totals.get("losses", 0)),
	])
	_inventory_label.text = "\n".join(lines)


func _resolve_message(message: String) -> String:
	if message != "":
		return message
	if not GameState.last_expedition_summary.is_empty():
		var summary := GameState.last_expedition_summary
		var stats := summary.get("stats", {}) as Dictionary
		return "上次历练：深入 %d 层，消耗 %d 日" % [
			int(stats.get("max_depth", 0)), int(summary.get("elapsed_days", 1))
		]
	if not GameState.last_rewards.is_empty():
		var rewards: PackedStringArray = []
		for reward in GameState.last_rewards:
			rewards.append(GameState.reward_label(reward))
		return "上次所得：" + "、".join(rewards)
	if not GameState.activity_log.is_empty():
		return str((GameState.activity_log.back() as Dictionary).get("text", ""))
	return "洞府清幽，宜静心修行。"


func _on_alchemy() -> void:
	_refresh("炼丹炉火候正好，炼丹功能尚待开启。")


func _on_cultivate() -> void:
	var gain: int = GameState.cultivate()
	_refresh("静心修炼一日，修为 +%d。" % gain)


func _on_rest() -> void:
	GameState.rest()
	_refresh("静养一日，气血与法力恢复，伤势减轻。")


func _on_encounter() -> void:
	if ExpeditionState.active:
		_refresh("当前仍在历练中，请先完成或结算后再操作。")
		return
	get_tree().change_scene_to_file("res://scenes/expedition/location_select.tscn")


func _on_breakthrough() -> void:
	var result: Dictionary = GameState.breakthrough()
	if bool(result.get("ok", false)):
		get_tree().root.set_meta("breakthrough_summary", result)
		get_tree().change_scene_to_file("res://scenes/sim/breakthrough_summary.tscn")
	else:
		_refresh(str(result.get("error", "无法突破")))


func _toggle_inventory() -> void:
	_inventory_overlay.visible = not _inventory_overlay.visible
	if _inventory_overlay.visible:
		if _inventory_overlay.has_method("refresh"):
			_inventory_overlay.refresh()
		_refresh()


func _cycle_equip(index: int) -> void:
	InventoryServiceScript.cycle_equip_slot(GameState.owned_equips, GameState.equip_slots, index)
	_refresh()


func _cycle_item(index: int) -> void:
	InventoryServiceScript.cycle_item_slot(GameState.inventory, GameState.item_slots, index)
	_refresh()


func _toggle_save_panel() -> void:
	if ExpeditionState.active:
		_refresh("历练中无法存档或读档。")
		return
	_save_panel.visible = not _save_panel.visible
	_refresh_save_slots()


func _save(slot: int) -> void:
	if ExpeditionState.active:
		_refresh("历练中无法存档。")
		return
	var result: Dictionary = SaveService.save_slot(slot, GameState.to_dict())
	_refresh("槽位 %d：%s" % [slot, "保存成功" if result.get("ok", false) else result.get("error", "保存失败")])


func _load(slot: int) -> void:
	if ExpeditionState.active:
		_refresh("历练中无法读档。")
		return
	var result: Dictionary = SaveService.load_slot(slot)
	if bool(result.get("ok", false)) and GameState.apply_dict(result["game"]):
		_refresh("已读取槽位 %d。" % slot)
	else:
		_refresh(str(result.get("error", "读取失败")))


func _new_game() -> void:
	GameState.new_game()
	_refresh("新的修行开始了。")


func _refresh_save_slots() -> void:
	for slot in range(1, 4):
		var label := _save_panel.get_node("Slot%d/SlotLabel%d" % [slot, slot]) as Label
		var info: Dictionary = SaveService.slot_info(slot)
		label.text = "槽位 %d：%s" % [
			slot,
			"第%d日 %s 修为%d" % [info.day, info.realm_name, info.cultivation] if info.get("ok", false) else "空",
		]


func _equip_name(eid: int) -> String:
	if eid <= 0:
		return "空"
	return str(ConfigManager.equip_by_id(eid).get("name", "未知法宝"))


func _item_name(iid: String) -> String:
	if iid == "":
		return "空"
	return ConfigManager.get_item_display_name(iid)
