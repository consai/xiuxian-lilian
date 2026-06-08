extends Control

const LocationServiceScript := preload("res://scripts/expedition/location_service.gd")
const ItemDefScript := preload("res://scripts/core/item_def.gd")
const BattleInitDataScript := preload("res://scripts/fight/battle_init_data.gd")

const DEFAULT_RULE_TEXT := "每三步消耗一天，可随时返程，战败损失部分战利品。"

var _location: Dictionary = {}
var _blocked := false

@onready var _preview_rewards: Array[ItemView] = [
	%PreviewReward1, %PreviewReward2, %PreviewReward3, %PreviewReward4,
]
@onready var _supply_items: Array[ItemView] = [%SupplyItem1, %SupplyItem2]


func _ready() -> void:
	_configure_item_views()
	var locations := LocationServiceScript.all_locations()
	if not locations.is_empty():
		_location = locations.front() as Dictionary
	if ExpeditionState.active:
		_show_blocked("历练尚未结束，请先完成或结算当前历练。")
	elif _location.is_empty():
		_show_blocked("暂无可前往的历练地点。")
	_refresh()


func _configure_item_views() -> void:
	for view in _preview_rewards:
		if view == null:
			continue
		view.click_enabled = false
		view.show_name_label = true
	for view in _supply_items:
		if view == null:
			continue
		view.click_enabled = false
		view.show_name_label = true


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
	for i in _preview_rewards.size():
		var view := _preview_rewards[i]
		if view == null:
			continue
		if i >= rewards.size():
			_bind_item_view(view, {})
			continue
		_bind_item_view(view, _resolve_reward_display(rewards[i]))


func _refresh_supplies() -> void:
	for i in _supply_items.size():
		var view := _supply_items[i]
		if view == null:
			continue
		var item_id := str(GameState.item_slots[i]) if i < GameState.item_slots.size() else ""
		_bind_item_view(view, _resolve_item_display(item_id))


func _bind_item_view(view: ItemView, display: Dictionary) -> void:
	if display.is_empty():
		view.apply_empty(null, Color(1, 1, 1, 0))
		view.visible = true
		return
	view.visible = true
	view.apply_display(
		display.get("icon") as Texture2D,
		str(display.get("name", "")),
		maxi(0, int(display.get("count", 0))),
		Color.WHITE,
		str(display.get("quality", ""))
	)


func _apply_preview_image(path: String) -> void:
	if path == "" or not ResourceLoader.exists(path):
		return
	var res := load(path)
	if res is Texture2D:
		%Preview.texture = res as Texture2D


func _resolve_reward_display(reward_v: Variant) -> Dictionary:
	if reward_v is String:
		return _resolve_item_preview(str(reward_v))
	if reward_v is int or reward_v is float:
		return _resolve_equip_display(int(reward_v))
	return {}


func _resolve_item_preview(item_id: String) -> Dictionary:
	var display := _resolve_item_display(item_id)
	if display.is_empty():
		return {}
	display["count"] = 1
	return display


func _resolve_item_display(item_id: String) -> Dictionary:
	var iid := item_id.strip_edges()
	if iid == "":
		return {}
	var item_name := iid
	var icon: Texture2D = null
	var quality := ""
	if ConfigManager != null:
		item_name = ConfigManager.get_item_display_name(iid)
		var def := ConfigManager.item_def_by_id(iid)
		if def != null:
			icon = ItemDefScript.resolve_icon_texture(def.icon_path, null)
			quality = def.rarity
	return {
		"name": item_name,
		"icon": icon,
		"count": maxi(0, int(GameState.inventory.get(iid, 0))),
		"quality": quality,
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
		"quality": _quality_label_from_int(int(cfg.get("quality", 1))),
	}


func _quality_label_from_int(quality: int) -> String:
	if quality >= 5:
		return "传说"
	if quality >= 3:
		return "稀有"
	return ""


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
