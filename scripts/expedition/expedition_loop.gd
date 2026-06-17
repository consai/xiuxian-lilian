extends Control

const LocationServiceScript := preload("res://scripts/expedition/location_service.gd")
const ExpeditionEventServiceScript := preload("res://scripts/expedition/expedition_event_service.gd")
const ExpeditionRulesServiceScript := preload("res://scripts/expedition/expedition_rules_service.gd")
const ItemDefScript := preload("res://scripts/core/item_def.gd")
const ExpeditionBattlePopupView := preload("res://scripts/expedition/expedition_battle_popup_view.gd")
const ExpeditionLogServiceScript := preload("res://scripts/expedition/expedition_log_service.gd")

var _locked := false
var _auto_chain_after_timer := false

@onready var _auto_advance_timer: Timer = %AutoAdvanceTimer
@onready var _loot_items: GridContainer = %LootItems
@onready var _loot_item_template: ItemView = (
	_loot_items.get_child(0) as ItemView if _loot_items != null and _loot_items.get_child_count() > 0 else null
)


func _ready() -> void:
	if not ExpeditionState.active:
		call_deferred("_fallback_hub")
		return
	if ExpeditionState.should_go_to_result():
		call_deferred("_go_completed_result")
		return
	_prepare_loot_template()
	_prepare_battle_popup()
	_auto_advance_timer.timeout.connect(_on_auto_advance_timeout)
	if not ExpeditionState.log_updated.is_connected(_refresh_log_display):
		ExpeditionState.log_updated.connect(_refresh_log_display)
	(%ExitButton as Button).pressed.connect(_on_exit_pressed)
	(%AdvanceButton as Button).pressed.connect(_on_advance_pressed)
	(%AutoAdvanceButton as Button).toggled.connect(_on_auto_advance_toggled)
	_refresh_all()
	if ExpeditionState.phase == "battle" and ExpeditionState.pending_battle_event_id != "":
		var pending_event := ExpeditionEventServiceScript.by_id(ExpeditionState.pending_battle_event_id)
		if not pending_event.is_empty():
			_show_pending_battle_popup(pending_event)
		elif ExpeditionState.auto_advance:
			_schedule_auto_advance()
	elif ExpeditionState.auto_advance:
		_schedule_auto_advance()
	if get_tree().root.has_meta("smoke_auto_exit") and bool(get_tree().root.get_meta("smoke_auto_exit")):
		call_deferred("_on_exit_pressed")


func _refresh_all() -> void:
	var location: Dictionary = ExpeditionState.effective_location()
	var min_diff := maxi(1, int(location.get("min_difficulty", 1)))
	var max_diff := int(location.get("max_difficulty", 0))
	var diff_text := "难度 %d" % min_diff if max_diff <= 0 or max_diff == min_diff else "难度 %d-%d" % [min_diff, max_diff]
	(%Header as Label).text = "%s · %s · 已消耗 %d 日" % [
		str(location.get("name", "")),
		diff_text,
		ExpeditionState.estimated_elapsed_days(),
	]
	_refresh_progress_dots()
	_refresh_status_panel()
	(%Step as Label).text = "第 %d 日 · %d 件事" % [ExpeditionState.days, ExpeditionState.steps]
	_sync_loot_items()
	_refresh_log_display()
	_refresh_event_presentation()
	_refresh_controls()


func _refresh_log_display() -> void:
	var log_label := %Log as RichTextLabel
	var log_lines: PackedStringArray = []
	for entry_v in ExpeditionState.event_log:
		log_lines.append(ExpeditionLogServiceScript.format_bbcode(entry_v as Dictionary))
	log_label.text = "\n\n".join(log_lines)
	_scroll_log_to_latest(log_label)


func _refresh_event_presentation() -> void:
	var is_decision: bool = not ExpeditionState.pending_decision_event.is_empty()
	var cards := %EventCards as HBoxContainer
	cards.visible = is_decision
	if is_decision:
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


func _refresh_status_panel() -> void:
	var attrs := ExpeditionState.player_snapshot.get("attrs", {}) as Dictionary
	var hp := float(ExpeditionState.runtime.get("hp", 0.0))
	var hp_max := maxf(1.0, float(attrs.get(FightAttr.HP_MAX, 100.0)))
	var mp := float(ExpeditionState.runtime.get("mp", 0.0))
	var mp_max := maxf(1.0, float(attrs.get(FightAttr.MP_MAX, 100.0)))
	(%HpLabel as Label).text = "气血  %.0f / %.0f" % [hp, hp_max]
	var hp_bar := %HpBar as ProgressBar
	hp_bar.max_value = hp_max
	hp_bar.value = clampf(hp, 0.0, hp_max)
	(%MpLabel as Label).text = "法力  %.0f / %.0f" % [mp, mp_max]
	var mp_bar := %MpBar as ProgressBar
	mp_bar.max_value = mp_max
	mp_bar.value = clampf(mp, 0.0, mp_max)
	var inv := ExpeditionState.runtime.get("inventory", {}) as Dictionary
	var slots := ExpeditionState.runtime.get("item_slots", []) as Array
	_refresh_potion_slot(%PotionSlot1 as Panel, str(slots[0]) if slots.size() > 0 else "", inv)
	_refresh_potion_slot(%PotionSlot2 as Panel, str(slots[1]) if slots.size() > 1 else "", inv)
	var stats := ExpeditionState.stats
	(%Runtime as RichTextLabel).text = "战斗 %d  胜 %d  负 %d" % [
		int(stats.get("battles", 0)),
		int(stats.get("wins", 0)),
		int(stats.get("losses", 0)),
	]


func _refresh_potion_slot(slot: Panel, item_id: String, inv: Dictionary) -> void:
	if slot == null:
		return
	var icon := slot.get_node_or_null("Icon") as TextureRect
	var count_label := slot.get_node_or_null("Count") as Label
	var iid := item_id.strip_edges()
	if iid == "":
		if icon != null:
			icon.texture = null
			icon.self_modulate = Color(1, 1, 1, 0.2)
		if count_label != null:
			count_label.text = "—"
		return
	var item_name := iid
	var tex: Texture2D = null
	if ConfigManager != null:
		item_name = ConfigManager.get_item_display_name(iid)
		var def := ConfigManager.item_def_by_id(iid)
		if def != null:
			tex = ItemDefScript.resolve_icon_texture(def.icon_path, null)
	var count := maxi(0, int(inv.get(iid, 0)))
	if icon != null:
		icon.texture = tex
		icon.self_modulate = Color.WHITE if tex != null else Color(1, 1, 1, 0.35)
	if count_label != null:
		count_label.text = "%s ×%d" % [item_name, count] if count > 1 else item_name


func _refresh_progress_dots() -> void:
	(%ProgressDots as Label).visible = false


func _refresh_controls() -> void:
	var exit_button := %ExitButton as Button
	exit_button.disabled = _locked or not ExpeditionState.can_exit()
	var advance_button := %AdvanceButton as Button
	var awaiting_manual := (
		not ExpeditionState.auto_advance
		and ExpeditionState.phase == "resolving"
		and ExpeditionState.pending_decision_event.is_empty()
		and ExpeditionState.pending_battle_event_id == ""
		and not ExpeditionState.should_go_to_result()
	)
	advance_button.visible = awaiting_manual
	advance_button.disabled = _locked or not awaiting_manual
	var auto_button := %AutoAdvanceButton as Button
	if auto_button.button_pressed != ExpeditionState.auto_advance:
		auto_button.set_pressed_no_signal(ExpeditionState.auto_advance)
	auto_button.disabled = _locked


func _continue_expedition() -> void:
	if _locked or not _auto_advance_timer.is_stopped():
		return
	if ExpeditionState.phase == "battle" and ExpeditionState.pending_battle_event_id != "":
		return
	if ExpeditionState.phase == "choosing" and not ExpeditionState.pending_decision_event.is_empty():
		_refresh_all()
		return
	_advance_auto_step()


func _advance_auto_step() -> void:
	if _locked:
		return
	_stop_auto_advance()
	_locked = true
	_refresh_controls()
	var began: Dictionary = ExpeditionState.advance_day()
	_locked = false
	if not bool(began.get("ok", false)):
		var feedback := str(began.get("feedback", began.get("error", ""))).strip_edges()
		if feedback != "":
			(%Feedback as Label).text = feedback
		_refresh_all()
		return
	_handle_step_begin(began)


func _handle_step_begin(began: Dictionary) -> void:
	if str(began.get("mode", "")) == "pass_day":
		_refresh_all()
		if ExpeditionState.auto_advance:
			call_deferred("_continue_expedition")
		return
	if str(began.get("mode", "")) == "decision":
		_stop_auto_advance()
		_refresh_all()
		return
	var scene := str(began.get("scene", "")).strip_edges()
	if str(began.get("mode", "")) == "battle":
		_stop_auto_advance()
		_refresh_all()
		_show_pending_battle_popup(began.get("event", {}) as Dictionary)
		return
	_refresh_all()
	call_deferred("_complete_current_step")


func _complete_current_step() -> void:
	if _locked:
		return
	_locked = true
	_refresh_controls()
	var result: Dictionary = ExpeditionState.complete_current_step()
	_locked = false
	if not bool(result.get("ok", false)):
		_refresh_all()
		return
	_handle_step_result(result)


func _handle_step_result(result: Dictionary) -> void:
	if str(result.get("mode", "")) == "decision":
		_stop_auto_advance()
		_refresh_all()
		return
	var event := result.get("event", {}) as Dictionary
	if str(result.get("type", "")) == "battle":
		_stop_auto_advance()
		_show_pending_battle_popup(event)
		return
	_schedule_auto_advance()
	_refresh_all()


func _auto_advance_seconds() -> float:
	return maxf(0.1, float(
		ExpeditionRulesServiceScript.rules().get("auto_event_advance_seconds", 1.0)
	))


func _schedule_auto_advance(continue_after: bool = true) -> void:
	if not ExpeditionState.auto_advance:
		_refresh_controls()
		return
	if _auto_advance_timer == null:
		return
	_auto_chain_after_timer = continue_after
	_auto_advance_timer.wait_time = _auto_advance_seconds()
	_auto_advance_timer.start()


func _stop_auto_advance() -> void:
	if _auto_advance_timer != null:
		_auto_advance_timer.stop()
	_auto_chain_after_timer = false


func _on_auto_advance_timeout() -> void:
	_refresh_controls()
	if _auto_chain_after_timer:
		_continue_expedition()


func _scroll_log_to_latest(log_label: RichTextLabel) -> void:
	if log_label == null:
		return
	log_label.scroll_following = true
	call_deferred("_finish_log_scroll")


func _finish_log_scroll() -> void:
	var log_label := %Log as RichTextLabel
	if log_label == null:
		return
	var last_line := maxi(0, log_label.get_line_count() - 1)
	log_label.scroll_to_line(last_line)


func _on_event_chosen(event_id: String) -> void:
	if _locked:
		return
	_locked = true
	_refresh_controls()
	var result: Dictionary = ExpeditionState.choose_event(event_id)
	_locked = false
	if not bool(result.get("ok", false)):
		_schedule_auto_advance(false)
		_refresh_all()
		return
	_handle_step_result(result)


func _on_exit_pressed() -> void:
	if not ExpeditionState.can_exit():
		return
	SceneManager.go_expedition_result("manual")


func _on_advance_pressed() -> void:
	if _locked or ExpeditionState.auto_advance:
		return
	_continue_expedition()


func _on_auto_advance_toggled(enabled: bool) -> void:
	ExpeditionState.auto_advance = enabled
	if enabled:
		_schedule_auto_advance()
	else:
		_stop_auto_advance()
	_refresh_controls()


func _fallback_hub() -> void:
	SceneManager.go_hub()


func _prepare_battle_popup() -> void:
	var popup := %BattlePopup as ExpeditionBattlePopupView
	if popup == null:
		return
	if not popup.fight_requested.is_connected(_on_battle_fight_requested):
		popup.fight_requested.connect(_on_battle_fight_requested)
	if not popup.retreat_requested.is_connected(_on_battle_retreat_requested):
		popup.retreat_requested.connect(_on_battle_retreat_requested)


func _show_pending_battle_popup(event: Dictionary) -> void:
	_locked = true
	if ExpeditionState.auto_advance:
		_refresh_controls()
		call_deferred("_on_battle_fight_requested")
		return
	var popup := %BattlePopup as ExpeditionBattlePopupView
	if popup == null:
		_locked = false
		return
	popup.apply_event(event, maxi(1, int(event.get("difficulty", 1))))
	popup.visible = true
	_refresh_controls()


func _on_battle_fight_requested() -> void:
	if not _locked:
		return
	var popup := %BattlePopup as ExpeditionBattlePopupView
	var battle_data := ExpeditionState.build_battle_init()
	var nav: Dictionary = SceneManager.go_fight(battle_data, "expedition")
	if not bool(nav.get("ok", false)):
		ExpeditionState.clear_pending_battle()
		_locked = false
		if popup != null:
			popup.visible = false
		_refresh_all()
		return
	if popup != null:
		popup.visible = false


func _on_battle_retreat_requested() -> void:
	if not _locked:
		return
	ExpeditionState.retreat_from_pending_battle()
	var popup := %BattlePopup as ExpeditionBattlePopupView
	if popup != null:
		popup.visible = false
	_locked = false
	SceneManager.go_expedition_result("manual")


func _prepare_loot_template() -> void:
	if _loot_item_template == null:
		return
	_loot_item_template.visible = false
	_loot_item_template.set_click_enabled(false)
	_loot_item_template.show_info_on_click = false


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
	copy.set_click_enabled(true)
	copy.show_info_on_click = true
	_loot_items.add_child(copy)
	return copy


func _apply_loot_row(view: ItemView, row: Dictionary) -> void:
	ItemView.apply_reward_row(view, row)
