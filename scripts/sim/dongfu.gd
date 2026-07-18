extends Control

const BreakthroughPagePayloadContract := preload(
	"res://scripts/features/cultivation/contracts/breakthrough_page_payload.gd"
)
const WeituoApplicationScript := preload(
	"res://scripts/features/commission/application/weituo_application.gd"
)

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

var _weituo_application: Variant
var _tutorial_coordinator: Node
var _lilian_session_host: Node
var _game_session_host: Node


func bind_tutorial_coordinator(coordinator: Node) -> void:
	_tutorial_coordinator = coordinator


func bind_lilian_session_host(host: Node) -> void:
	_lilian_session_host = host


func bind_game_session_host(host: Node) -> void:
	_game_session_host = host
	_bind_game_session_children()


func _bind_game_session_children() -> void:
	if _game_session_host == null:
		return
	if _save_slots_overlay != null and _save_slots_overlay.has_method("bind_game_session_host"):
		_save_slots_overlay.call("bind_game_session_host", _game_session_host)
	if _inventory_overlay != null and _inventory_overlay.has_method("bind_game_session_host"):
		_inventory_overlay.call("bind_game_session_host", _game_session_host)
	if _weituo_board != null and _weituo_board.has_method("bind_game_session_host"):
		_weituo_board.call("bind_game_session_host", _game_session_host)


func _game_session() -> Node:
	if _game_session_host == null:
		push_error("Dongfu: GameSessionHost 未注入")
		return null
	return _game_session_host.session()


func _lilian_session() -> Node:
	if _lilian_session_host == null:
		push_error("Dongfu: LilianSessionHost 未注入")
		return null
	return _lilian_session_host.session()


func _tutorial_event(event_id: String) -> void:
	if _tutorial_coordinator == null:
		push_error("Dongfu: TutorialCoordinator 未注入")
		return
	_tutorial_coordinator.game_event(event_id)


func _ready() -> void:
	_bind_game_session_children()
	_inventory_overlay.visible = false
	_save_slots_overlay.visible = false
	_weituo_board.visible = false
	_connect_actions()
	call_deferred("_initialize_after_session")


func _initialize_after_session() -> void:
	var game_session := _game_session()
	if game_session == null:
		return
		_weituo_application = WeituoApplicationScript.new(game_session.data_store(), game_session)
	game_session.refresh_derived_attrs(true)
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
	var game_session := _game_session()
	var hp_max := float(game_session.attrs.get(EnumPlayerAttr.HP_MAX, 100.0))
	var mp_max := float(game_session.attrs.get(EnumPlayerAttr.MP_MAX, 100.0))
	_realm_label.text = "%s · 修为 %d/%d" % [
		game_session.realm_name, game_session.cultivation, game_session.breakthrough_at
	]
	var status := "%s  |  灵石 %d  |  气血 %.0f/%.0f  |  法力 %.0f/%.0f  |  伤势 %s  |  灵力驳杂 %d" % [
		game_session.time_date_label(game_session.day), game_session.ling_stones, game_session.hp, hp_max,
		game_session.mp, mp_max, game_session.time_duration_label(game_session.injury_days), game_session.cultivation_instability
	]
	if game_session.active_save_slot > 0:
		status += "  |  存档槽 %d" % game_session.active_save_slot
	_status_label.text = status
	# 仅在大境界可突破时展示入口，避免平时占位干扰洞府布局
	_breakthrough_button.visible = game_session.can_breakthrough()
	_message_label.text = _resolve_message(message)


func _resolve_message(message: String) -> String:
	if message != "":
		return message
	var game_session := _game_session()
	if not game_session.last_lilian_summary.is_empty():
		return _last_lilian_message(game_session.last_lilian_summary)
	if not game_session.last_rewards.is_empty():
		var rewards: PackedStringArray = []
		for reward in game_session.last_rewards:
			rewards.append(game_session.reward_label(reward))
		return "上次所得：" + "、".join(rewards)
	if not game_session.activity_log.is_empty():
		return str((game_session.activity_log.back() as Dictionary).get("text", ""))
	return "可随时出门巡山。"


## PM-401：上次战败时洞府首屏提示恢复路径（休息 / 炼丹 / 研读 / 技能）。
func _last_lilian_message(summary: Dictionary) -> String:
	var stats := summary.get("stats", {}) as Dictionary
	var peak := maxi(int(stats.get("max_difficulty", 0)), int(stats.get("max_depth", 0)))
	var duration := str(summary.get(
		"duration_label",
		_game_session().time_duration_label(int(summary.get("elapsed_days", 1)))
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
	_tutorial_event("tutorial.alchemy_opened")
	var nav: Dictionary = SceneManager.go_liandan_mianban()
	if not bool(nav.get("ok", false)):
		_refresh(str(nav.get("error", "无法打开炼丹界面")))


func _on_cultivate() -> void:
	_tutorial_event("tutorial.xiulian_mianban_opened")
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
	_game_session().rest()
	_refresh("静养一日，气血与法力恢复，伤势减轻约 2 日。")


func _on_encounter() -> void:
	var lilian := _lilian_session()
	if lilian == null:
		return
	if lilian.active:
		_refresh("当前仍在巡山中，请先完成或结算后再操作。")
		return
	var nav: Dictionary = LilianFlowService.open_world_map(lilian, SceneManager)
	if not bool(nav.get("ok", false)):
		_refresh(str(nav.get("error", "无法打开世界地图")))


func _on_breakthrough() -> void:
	if not _game_session().can_breakthrough():
		_refresh("修为尚未达到大境界突破门槛。")
		return
	var payload := BreakthroughPagePayloadContract.panel()
	var nav: Dictionary = SceneManager.go_to(SceneManager.TUPO_ZONGJIE, payload)
	if not bool(nav.get("ok", false)):
		_refresh(str(nav.get("error", "无法打开突破界面")))


func _on_character_attributes() -> void:
	_tutorial_event("tutorial.attributes_opened")
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
	var result: Dictionary = _weituo_application.accept(weituo_id)
	if not bool(result.get("ok", false)):
		if _weituo_board.has_method("show_state_hint"):
			_weituo_board.show_state_hint(str(result.get("error", "无法接受委托")))
		return
	if _weituo_board.has_method("refresh"):
		_weituo_board.refresh()


func _on_weituo_submit(instance_id: String) -> void:
	var result: Dictionary = _weituo_application.submit(instance_id)
	if not bool(result.get("ok", false)):
		if _weituo_board.has_method("show_state_hint"):
			_weituo_board.show_state_hint(str(result.get("error", "无法提交委托")))
		return
	if _weituo_board.has_method("refresh"):
		_weituo_board.refresh()
	if _inventory_overlay.visible and _inventory_overlay.has_method("refresh"):
		_inventory_overlay.refresh()
	_refresh("委托完成，奖励已收入背包。")


func _on_weituo_abandon(instance_id: String) -> void:
	var result: Dictionary = _weituo_application.abandon(instance_id)
	if not bool(result.get("ok", false)):
		if _weituo_board.has_method("show_state_hint"):
			_weituo_board.show_state_hint(str(result.get("error", "无法放弃委托")))
		return
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
