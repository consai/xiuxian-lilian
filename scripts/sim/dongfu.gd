extends Control

@onready var _realm_label: Label = %RealmLabel
@onready var _status_label: Label = %StatusLabel
@onready var _message_label: Label = %MessageLabel
@onready var _inventory_overlay: Control = %InventoryOverlay
@onready var _save_slots_overlay: Control = %SaveSlotsOverlay
@onready var _breakthrough_button: TextureButton = %BreakthroughButton
@onready var _furnace_button: TextureButton = %FurnaceButton
@onready var _storage_button: TextureButton = %StorageButton
@onready var _cultivate_object_button: TextureButton = %CultivateObjectButton
@onready var _rest_button: TextureButton = %RestButton
@onready var _lilian_object_button: TextureButton = %LilianObjectButton
@onready var _beibao_button: TextureButton = %BeibaoButton
@onready var _weituo_board_button: TextureButton = %WeituoBoardButton
@onready var _weituo_board: Control = %WeituoBoardPanel
@onready var _knowledge_study_button: TextureButton = %KnowledgeStudyButton
@onready var _attributes_button: TextureButton = %btnattrs
@onready var _skills_button: TextureButton = %Skills
@onready var _save_button: Button = %SaveButton


func _ready() -> void:
	_inventory_overlay.visible = false
	_save_slots_overlay.visible = false
	_weituo_board.visible = false
	_connect_actions()
	GameState.refresh_derived_attrs(true)
	_refresh()


func _connect_actions() -> void:
	_furnace_button.pressed.connect(_on_alchemy)
	_storage_button.pressed.connect(_toggle_inventory)
	_cultivate_object_button.pressed.connect(_on_cultivate)
	_rest_button.pressed.connect(_on_rest)
	_lilian_object_button.pressed.connect(_on_encounter)
	_beibao_button.pressed.connect(_on_backpack)
	_weituo_board_button.pressed.connect(_on_weituo_board)
	_knowledge_study_button.pressed.connect(_on_knowledge_study)
	_skills_button.pressed.connect(_on_skills)
	_breakthrough_button.pressed.connect(_on_breakthrough)
	_attributes_button.pressed.connect(_on_character_attributes)
	_save_button.pressed.connect(_toggle_save_slots)
	_save_slots_overlay.closed.connect(_on_save_slots_closed)
	_weituo_board.close_requested.connect(_close_weituo_board)
	_weituo_board.accept_requested.connect(_on_weituo_accept)
	_weituo_board.submit_requested.connect(_on_weituo_submit)
	_weituo_board.abandon_requested.connect(_on_weituo_abandon)


func _refresh(message: String = "") -> void:
	var hp_max := float(GameState.attrs.get(ZhandouAttr.HP_MAX, 100.0))
	var mp_max := float(GameState.attrs.get(ZhandouAttr.MP_MAX, 100.0))
	_realm_label.text = "%s · 修为 %d/%d" % [
		GameState.realm_name, GameState.cultivation, GameState.breakthrough_at
	]
	var status := "%s  |  灵石 %d  |  气血 %.0f/%.0f  |  法力 %.0f/%.0f  |  伤势 %s  |  灵力驳杂 %d" % [
		GameState.time_date_label(GameState.day), GameState.ling_stones, GameState.hp, hp_max,
		GameState.mp, mp_max, GameState.time_duration_label(GameState.injury_days), GameState.cultivation_instability
	]
	if GameState.active_save_slot > 0:
		status += "  |  存档槽 %d" % GameState.active_save_slot
	_status_label.text = status
	# 仅在大境界可突破时展示入口，避免平时占位干扰洞府布局
	_breakthrough_button.visible = GameState.can_breakthrough()
	_message_label.text = _resolve_message(message)


func _resolve_message(message: String) -> String:
	if message != "":
		return message
	if not GameState.last_lilian_summary.is_empty():
		return _last_lilian_message(GameState.last_lilian_summary)
	if not GameState.last_rewards.is_empty():
		var rewards: PackedStringArray = []
		for reward in GameState.last_rewards:
			rewards.append(GameState.reward_label(reward))
		return "上次所得：" + "、".join(rewards)
	if not GameState.activity_log.is_empty():
		return str((GameState.activity_log.back() as Dictionary).get("text", ""))
	return "可随时出门巡山。"


## PM-401：上次战败时洞府首屏提示恢复路径（休息 / 炼丹 / 研读 / 技能）。
func _last_lilian_message(summary: Dictionary) -> String:
	var stats := summary.get("stats", {}) as Dictionary
	var peak := maxi(int(stats.get("max_difficulty", 0)), int(stats.get("max_depth", 0)))
	var duration := str(summary.get(
		"duration_label",
		GameState.time_duration_label(int(summary.get("elapsed_days", 1)))
	))
	var exit_reason := str(summary.get("exit_reason", "manual"))
	if exit_reason == "defeated":
		return (
			"上次战败撤退（最高难度 %d，耗时 %s）：建议先「休息」清伤势，"
			% [peak, duration]
			+ "再「炼丹」补给或「研读」/「技能」调整后再出发。"
		)
	if exit_reason == "fled":
		return "上次战中遁走（最高难度 %d，耗时 %s）：可「休息」调息后再出门。" % [peak, duration]
	return "上次历练：最高难度 %d，耗时 %s" % [peak, duration]


func _on_alchemy() -> void:
	TutorialService.game_event("tutorial.alchemy_opened")
	var nav: Dictionary = SceneManager.go_liandan_mianban()
	if not bool(nav.get("ok", false)):
		_refresh(str(nav.get("error", "无法打开炼丹界面")))


func _on_cultivate() -> void:
	TutorialService.game_event("tutorial.xiulian_mianban_opened")
	var nav: Dictionary = SceneManager.go_xiulian_mianban()
	if not bool(nav.get("ok", false)):
		_refresh(str(nav.get("error", "无法打开修炼界面")))


func _on_knowledge_study() -> void:
	var nav: Dictionary = SceneManager.go_knowledge_study_panel()
	if not bool(nav.get("ok", false)):
		_refresh(str(nav.get("error", "无法打开自主研读")))


func _on_skills() -> void:
	var nav: Dictionary = SceneManager.go_mastered_arts_panel()
	if not bool(nav.get("ok", false)):
		_refresh(str(nav.get("error", "无法打开已学技能")))


func _on_rest() -> void:
	GameState.rest()
	_refresh("静养一日，气血与法力恢复，伤势减轻约 2 日。")


func _on_encounter() -> void:
	if LilianState.active:
		_refresh("当前仍在巡山中，请先完成或结算后再操作。")
		return
	var nav: Dictionary = SceneManager.go_world_map()
	if not bool(nav.get("ok", false)):
		_refresh(str(nav.get("error", "无法打开世界地图")))


func _on_breakthrough() -> void:
	if not GameState.can_breakthrough():
		_refresh("修为尚未达到大境界突破门槛。")
		return
	var nav: Dictionary = SceneManager.go_tupo_mianban()
	if not bool(nav.get("ok", false)):
		_refresh(str(nav.get("error", "无法打开突破界面")))


func _on_character_attributes() -> void:
	TutorialService.game_event("tutorial.attributes_opened")
	var nav: Dictionary = SceneManager.go_character_attributes_panel()
	if not bool(nav.get("ok", false)):
		_refresh(str(nav.get("error", "无法打开人物属性")))


func _on_backpack() -> void:
	var nav: Dictionary = SceneManager.go_beibao_panel()
	if not bool(nav.get("ok", false)):
		_refresh(str(nav.get("error", "无法打开背包")))


func _on_weituo_board() -> void:
	_weituo_board.visible = true
	if _weituo_board.has_method("refresh"):
		_weituo_board.refresh()


func _close_weituo_board() -> void:
	_weituo_board.visible = false
	_refresh()


func _on_weituo_accept(weituo_id: String) -> void:
	var result: Dictionary = WeituoService.accept(weituo_id, DataStore.savedata, GameState)
	if not bool(result.get("ok", false)):
		if _weituo_board.has_method("show_state_hint"):
			_weituo_board.show_state_hint(str(result.get("error", "无法接受委托")))
		return
	GameState.auto_save()
	if _weituo_board.has_method("refresh"):
		_weituo_board.refresh()


func _on_weituo_submit(instance_id: String) -> void:
	var result: Dictionary = WeituoService.submit(instance_id, DataStore.savedata, GameState)
	if not bool(result.get("ok", false)):
		if _weituo_board.has_method("show_state_hint"):
			_weituo_board.show_state_hint(str(result.get("error", "无法提交委托")))
		return
	if _weituo_board.has_method("refresh"):
		_weituo_board.refresh()
	_refresh("委托完成，奖励已收入背包。")


func _on_weituo_abandon(instance_id: String) -> void:
	var result: Dictionary = WeituoService.abandon(instance_id, DataStore.savedata)
	if not bool(result.get("ok", false)):
		if _weituo_board.has_method("show_state_hint"):
			_weituo_board.show_state_hint(str(result.get("error", "无法放弃委托")))
		return
	GameState.auto_save()
	if _weituo_board.has_method("refresh"):
		_weituo_board.refresh()


func _toggle_inventory() -> void:
	_inventory_overlay.visible = not _inventory_overlay.visible
	if _inventory_overlay.visible and _inventory_overlay.has_method("refresh"):
		_inventory_overlay.refresh()


func _toggle_save_slots() -> void:
	_save_slots_overlay.visible = not _save_slots_overlay.visible
	if _save_slots_overlay.visible and _save_slots_overlay.has_method("refresh"):
		_save_slots_overlay.refresh()


func _on_save_slots_closed(message: String) -> void:
	_refresh(message)
	if _inventory_overlay.visible and _inventory_overlay.has_method("refresh"):
		_inventory_overlay.refresh()
