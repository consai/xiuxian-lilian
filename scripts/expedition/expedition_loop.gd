extends Control

const LocationServiceScript := preload("res://scripts/expedition/location_service.gd")
var _locked := false
var _feedback_timer := 0.0


func _ready() -> void:
	if not ExpeditionState.active:
		call_deferred("_fallback_hub")
		return
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
	var loot_lines: PackedStringArray = []
	for reward_v in ExpeditionState.loot:
		loot_lines.append(GameState.reward_label(reward_v as Dictionary))
	(%Loot as RichTextLabel).text = "\n".join(loot_lines) if not loot_lines.is_empty() else "暂无战利品"
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


func _item_summary() -> String:
	var inv := ExpeditionState.runtime.get("inventory", {}) as Dictionary
	var lines: PackedStringArray = []
	for slot_v in ExpeditionState.runtime.get("item_slots", []) as Array:
		var iid := str(slot_v)
		if iid == "":
			continue
		lines.append("%s x%d" % [ConfigManager.get_item_display_name(iid), int(inv.get(iid, 0))])
	return "\n".join(lines) if not lines.is_empty() else "丹药：无"
