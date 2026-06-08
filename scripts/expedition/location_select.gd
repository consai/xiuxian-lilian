extends Control

const LocationServiceScript := preload("res://scripts/expedition/location_service.gd")
const ItemDefScript := preload("res://scripts/core/item_def.gd")
const BattleInitDataScript := preload("res://scripts/fight/battle_init_data.gd")

const DEFAULT_RULE_TEXT := "每三步消耗一天，可随时返程，战败损失部分战利品。"

var _location: Dictionary = {}
var _blocked := false

@onready var _reward_slots: Array[VBoxContainer] = [%RewardSlot1, %RewardSlot2, %RewardSlot3]
@onready var _reward_icons: Array[TextureRect] = [%RewardIcon1, %RewardIcon2, %RewardIcon3]
@onready var _reward_labels: Array[Label] = [%RewardLabel1, %RewardLabel2, %RewardLabel3]
@onready var _supply_icons: Array[TextureRect] = [%SupplyIcon1, %SupplyIcon2]
@onready var _supply_labels: Array[Label] = [%SupplyLabel1, %SupplyLabel2]


func _ready() -> void:
	var locations := LocationServiceScript.all_locations()
	if not locations.is_empty():
		_location = locations.front() as Dictionary
	if ExpeditionState.active:
		_show_blocked("历练尚未结束，请先完成或结算当前历练。")
	elif _location.is_empty():
		_show_blocked("暂无可前往的历练地点。")
	_refresh()


func _refresh() -> void:
	_refresh_location()
	_refresh_status()
	_refresh_preview_rewards()
	_refresh_supplies()
	if not _blocked:
		%RuleLabel.text = DEFAULT_RULE_TEXT
		%StartButton.disabled = false
		%StartButton.modulate = Color.WHITE


func _refresh_location() -> void:
	if _location.is_empty():
		%LocationName.text = "未知地点"
		%Description.text = ""
		%DangerLabel.text = ""
		%RealmLabel.text = ""
		return
	%LocationName.text = str(_location.get("name", "未知地点"))
	%Description.text = str(_location.get("desc", ""))
	%DangerLabel.text = "危险：%s" % _danger_stars(int(_location.get("danger", 1)))
	%RealmLabel.text = "建议境界：%s" % str(_location.get("recommended_realm", "未知"))
	_apply_preview_image(str(_location.get("preview_image", "")).strip_edges())


func _refresh_status() -> void:
	var hp_max := float(GameState.attrs.get(FightAttr.HP_MAX, 100.0))
	var mp_max := float(GameState.attrs.get(FightAttr.MP_MAX, 100.0))
	%HpBar.max_value = hp_max
	%HpBar.value = GameState.hp
	%HpValue.text = "%.0f/%.0f" % [GameState.hp, hp_max]
	%MpBar.max_value = mp_max
	%MpBar.value = GameState.mp
	%MpValue.text = "%.0f/%.0f" % [GameState.mp, mp_max]


func _refresh_preview_rewards() -> void:
	var rewards := _location.get("preview_rewards", []) as Array
	for i in _reward_slots.size():
		var slot := _reward_slots[i]
		if i >= rewards.size():
			slot.visible = false
			continue
		var display := _resolve_reward_display(rewards[i])
		if display.is_empty():
			slot.visible = false
			continue
		slot.visible = true
		_reward_icons[i].texture = display.get("icon") as Texture2D
		_reward_labels[i].text = str(display.get("name", ""))


func _refresh_supplies() -> void:
	for i in _supply_icons.size():
		var item_id := str(GameState.item_slots[i]) if i < GameState.item_slots.size() else ""
		var display := _resolve_item_display(item_id)
		if display.is_empty():
			_supply_icons[i].visible = false
			_supply_labels[i].text = "丹药槽 %d：空" % (i + 1)
			_supply_labels[i].visible = true
			continue
		_supply_icons[i].texture = display.get("icon") as Texture2D
		_supply_icons[i].visible = display.get("icon") != null
		_supply_labels[i].text = "%s x%d" % [
			str(display.get("name", "")),
			int(display.get("count", 0)),
		]
		_supply_labels[i].visible = true


func _apply_preview_image(path: String) -> void:
	if path == "" or not ResourceLoader.exists(path):
		return
	var res := load(path)
	if res is Texture2D:
		%Preview.texture = res as Texture2D


func _resolve_reward_display(reward_v: Variant) -> Dictionary:
	if reward_v is String:
		return _resolve_item_display(str(reward_v))
	if reward_v is int or reward_v is float:
		return _resolve_equip_display(int(reward_v))
	return {}


func _resolve_item_display(item_id: String) -> Dictionary:
	var iid := item_id.strip_edges()
	if iid == "":
		return {}
	var item_name := iid
	var icon: Texture2D = null
	if ConfigManager != null:
		item_name = ConfigManager.get_item_display_name(iid)
		var def := ConfigManager.item_def_by_id(iid)
		if def != null:
			icon = ItemDefScript.resolve_icon_texture(def.icon_path, null)
	return {
		"name": item_name,
		"icon": icon,
		"count": maxi(0, int(GameState.inventory.get(iid, 0))),
	}


func _resolve_equip_display(equip_id: int) -> Dictionary:
	if equip_id <= 0 or ConfigManager == null:
		return {}
	var cfg := ConfigManager.equip_by_id(equip_id) as Dictionary
	if cfg.is_empty():
		return {}
	return {
		"name": str(cfg.get("name", "法宝")),
		"icon": BattleInitDataScript._resolve_icon_texture(cfg),
		"count": 1,
	}


func _danger_stars(danger: int) -> String:
	var labels := ["无", "一星", "二星", "三星", "四星", "五星"]
	return labels[clampi(danger, 0, labels.size() - 1)]


func _on_start_pressed() -> void:
	if _blocked or _location.is_empty():
		return
	var started: Dictionary = ExpeditionState.start(str(_location.get("id", "")), GameState)
	if not bool(started.get("ok", false)):
		_show_blocked(str(started.get("error", "无法开始历练")))
		return
	get_tree().change_scene_to_file(ExpeditionState.LOOP_SCENE)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(GameState.HUB_SCENE)


func _show_blocked(message: String) -> void:
	_blocked = true
	%RuleLabel.text = message
	%StartButton.disabled = true
	%StartButton.modulate = Color(0.55, 0.55, 0.55, 0.85)
