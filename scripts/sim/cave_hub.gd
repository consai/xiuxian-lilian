extends Control

@onready var _realm_label: Label = %RealmLabel
@onready var _status_label: Label = %StatusLabel
@onready var _message_label: Label = %MessageLabel
@onready var _inventory_overlay: Control = %InventoryOverlay
@onready var _breakthrough_button: TextureButton = %BreakthroughButton


func _ready() -> void:
	_inventory_overlay.visible = false
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
	_message_label.text = _resolve_message(message)


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
	var nav: Dictionary = SceneManager.go_location_select()
	if not bool(nav.get("ok", false)):
		_refresh(str(nav.get("error", "无法前往地点选择")))


func _on_breakthrough() -> void:
	var result: Dictionary = GameState.breakthrough()
	if bool(result.get("ok", false)):
		var nav: Dictionary = SceneManager.go_breakthrough_summary(result)
		if not bool(nav.get("ok", false)):
			_refresh(str(nav.get("error", "无法打开突破摘要")))
	else:
		_refresh(str(result.get("error", "无法突破")))


func _toggle_inventory() -> void:
	_inventory_overlay.visible = not _inventory_overlay.visible
	if _inventory_overlay.visible and _inventory_overlay.has_method("refresh"):
		_inventory_overlay.refresh()
