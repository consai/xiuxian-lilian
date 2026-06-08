extends Control

const LocationServiceScript := preload("res://scripts/expedition/location_service.gd")
const ItemDefScript := preload("res://scripts/core/item_def.gd")
const BattleInitDataScript := preload("res://scripts/fight/battle_init_data.gd")

var _locked := false
var _feedback_timer := 0.0

@onready var _loot_items: HBoxContainer = %LootItems
@onready var _loot_item_template: ItemView = (
	_loot_items.get_child(0) as ItemView if _loot_items != null and _loot_items.get_child_count() > 0 else null
)


func _ready() -> void:
	if not ExpeditionState.active:
		call_deferred("_fallback_hub")
		return
	_prepare_loot_template()
	(%ExitButton as Button).pressed.connect(_on_exit_pressed)
	_refresh_all()
	if get_tree().root.has_meta("smoke_auto_exit") and bool(get_tree().root.get_meta("smoke_auto_exit")):
		call_deferred("_on_exit_pressed")


func _process(delta: float) -> void:
	if _feedback_timer > 0.0:
		_feedback_timer -= delta
		if _feedback_timer <= 0.0:
			(%Feedback as Label).text = ""
			_refresh_controls()


func _refresh_all() -> void:
	var location: Dictionary = LocationServiceScript.by_id(ExpeditionState.location_id)
	(%Header as Label).text = "%s · 深入 %d 层 · 预计 %d 日" % [
		str(location.get("name", "")),
		maxi(1, ExpeditionState.depth - 1),
		ExpeditionState.estimated_elapsed_days(),
	]
	(%Runtime as RichTextLabel).text = "气血 %.0f/%.0f\n法力 %.0f/%.0f\n%s\n\n战斗 %d  胜 %d  负 %d" % [
		float(ExpeditionState.runtime.get("hp", 0.0)),
		float((ExpeditionState.player_snapshot.get("attrs", {}) as Dictionary).get(FightAttr.HP_MAX, 100.0)),
		float(ExpeditionState.runtime.get("mp", 0.0)),
		float((ExpeditionState.player_snapshot.get("attrs", {}) as Dictionary).get(FightAttr.MP_MAX, 100.0)),
		_item_summary(),
		int(ExpeditionState.stats.get("battles", 0)),
		int(ExpeditionState.stats.get("wins", 0)),
		int(ExpeditionState.stats.get("losses", 0)),
	]
	_sync_loot_items()
	var log_lines: PackedStringArray = []
	for entry_v in ExpeditionState.event_log.slice(max(0, ExpeditionState.event_log.size() - 5)):
		var entry := entry_v as Dictionary
		log_lines.append("%s：%s" % [str(entry.get("name", "")), str(entry.get("feedback", ""))])
	(%Log as RichTextLabel).text = "\n".join(log_lines)
	_refresh_cards()
	_refresh_controls()


func _refresh_cards() -> void:
	var cards := %EventCards as HBoxContainer
	var card_nodes := cards.get_children()
	for index in card_nodes.size():
		var card = card_nodes[index]
		if index >= ExpeditionState.current_choices.size():
			card.visible = false
			continue
		card.visible = true
		card.setup(ExpeditionState.current_choices[index] as Dictionary)
		if not card.chosen.is_connected(_on_event_chosen):
			card.chosen.connect(_on_event_chosen)
		card.disabled = _locked


func _refresh_controls() -> void:
	var exit_button := %ExitButton as Button
	exit_button.disabled = _locked or not ExpeditionState.can_exit()
	var boss_hint := %BossHint as Label
	boss_hint.visible = bool(ExpeditionState.stats.get("boss_defeated", false))
	boss_hint.text = "已击败首领，建议功成返程。"


func _on_event_chosen(event_id: String) -> void:
	if _locked:
		return
	_locked = true
	_refresh_controls()
	var result: Dictionary = ExpeditionState.choose_event(event_id)
	if not bool(result.get("ok", false)):
		(%Feedback as Label).text = str(result.get("error", "事件失败"))
		_locked = false
		_feedback_timer = 1.0
		_refresh_all()
		return
	if str(result.get("type", "")) == "battle":
		var battle_data := ExpeditionState.build_battle_init()
		var nav: Dictionary = SceneManager.go_fight(battle_data, "expedition")
		if not bool(nav.get("ok", false)):
			(%Feedback as Label).text = "无法进入战斗"
			ExpeditionState.clear_pending_battle()
			_locked = false
			_refresh_all()
		return
	(%Feedback as Label).text = str(result.get("feedback", "事件已结算"))
	_locked = false
	_feedback_timer = 0.8
	_refresh_all()


func _on_exit_pressed() -> void:
	if not ExpeditionState.can_exit():
		return
	SceneManager.go_expedition_result("manual")


func _fallback_hub() -> void:
	SceneManager.go_hub()


func _prepare_loot_template() -> void:
	if _loot_item_template == null:
		return
	_loot_item_template.visible = false
	_loot_item_template.set_click_enabled(false)


func _sync_loot_items() -> void:
	if _loot_items == null:
		return
	_clear_generated_loot_items()
	var rewards: Array = ExpeditionState.loot
	var empty_label := %LootEmpty as Label
	if rewards.is_empty():
		_loot_items.visible = false
		if empty_label != null:
			empty_label.visible = true
		return
	var shown := 0
	for reward_v in rewards:
		if not reward_v is Dictionary:
			continue
		var view := _make_loot_item()
		if view == null:
			continue
		_apply_loot_row(view, reward_v as Dictionary)
		shown += 1
	_loot_items.visible = shown > 0
	if empty_label != null:
		empty_label.visible = shown <= 0


func _clear_generated_loot_items() -> void:
	if _loot_items == null:
		return
	var keep: Array[Node] = []
	if _loot_item_template != null and _loot_item_template.get_parent() == _loot_items:
		keep.append(_loot_item_template)
	for child in _loot_items.get_children():
		if keep.has(child):
			child.visible = false
			continue
		child.queue_free()


func _make_loot_item() -> ItemView:
	if _loot_items == null or _loot_item_template == null:
		return null
	var copy_v := _loot_item_template.duplicate()
	if not copy_v is ItemView:
		return null
	var copy := copy_v as ItemView
	copy.visible = true
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.set_click_enabled(false)
	_loot_items.add_child(copy)
	return copy


func _apply_loot_row(view: ItemView, row: Dictionary) -> void:
	if view == null:
		return
	var kind := str(row.get("kind", "item"))
	var count := maxi(1, int(row.get("count", row.get("amount", 1))))
	var item_name := str(row.get("name", row.get("item_name", ""))).strip_edges()
	var quality := str(row.get("quality", row.get("pin_zhi", ""))).strip_edges()
	var icon: Texture2D = null
	var icon_v: Variant = row.get("icon")
	if icon_v is Texture2D:
		icon = icon_v
	elif kind == "currency":
		if item_name == "":
			item_name = "灵石" if str(row.get("id", "")) == "ling_stones" else str(row.get("id", "货币"))
	elif kind == "equip":
		var equip_cfg := _equip_cfg(int(row.get("id", -1)))
		if item_name == "":
			item_name = str(equip_cfg.get("name", "法宝"))
		icon = BattleInitDataScript._resolve_icon_texture(equip_cfg)
		if quality == "":
			quality = _quality_label_from_int(int(equip_cfg.get("quality", 1)))
	elif kind == "item":
		var item_id := str(row.get("id", ""))
		if item_name == "" and ConfigManager != null:
			item_name = str(ConfigManager.get_item_display_name(item_id))
		if ConfigManager != null:
			var def := ConfigManager.item_def_by_id(item_id)
			if def != null:
				icon = ItemDefScript.resolve_icon_texture(def.icon_path, null)
				if quality == "":
					quality = def.rarity
	else:
		if item_name == "":
			item_name = str(row.get("id", "奖励"))
		var path := str(row.get("icon_path", row.get("icon", ""))).strip_edges()
		if path != "":
			icon = ItemDefScript.resolve_icon_texture(path, null)
	view.apply_display(icon, item_name, count, Color.WHITE, quality)
	view.show_name_label = true


func _equip_cfg(equip_id: int) -> Dictionary:
	if ConfigManager != null and ConfigManager.has_method("equip_by_id"):
		return ConfigManager.equip_by_id(equip_id) as Dictionary
	return {}


func _quality_label_from_int(quality: int) -> String:
	if quality >= 5:
		return "传说"
	if quality >= 3:
		return "稀有"
	return ""


func _item_summary() -> String:
	var inv := ExpeditionState.runtime.get("inventory", {}) as Dictionary
	var lines: PackedStringArray = []
	for slot_v in ExpeditionState.runtime.get("item_slots", []) as Array:
		var iid := str(slot_v)
		if iid == "":
			continue
		lines.append("%s x%d" % [ConfigManager.get_item_display_name(iid), int(inv.get(iid, 0))])
	return "\n".join(lines) if not lines.is_empty() else "丹药：无"
