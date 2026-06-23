extends Control

const LocationServiceScript := preload("res://scripts/expedition/location_service.gd")
const ExpeditionEventServiceScript := preload("res://scripts/expedition/expedition_event_service.gd")
const ExpeditionRulesServiceScript := preload("res://scripts/expedition/expedition_rules_service.gd")
const ExpeditionBattlePopupView := preload("res://scripts/expedition/expedition_battle_popup_view.gd")
const ExpeditionLogServiceScript := preload("res://scripts/expedition/expedition_log_service.gd")
const ExpeditionMapServiceScript := preload("res://scripts/expedition/expedition_map_service.gd")
var _locked := false
var _auto_chain_after_timer := false
var _map_node_template: Button = null
var _map_refresh_pending := false

@onready var _auto_advance_timer: Timer = %AutoAdvanceTimer
@onready var _map_scroll: ScrollContainer = %MapScroll
@onready var _map_world: Control = %MapWorld
@onready var _map_canvas: Control = %MapCanvas
@onready var _map_nodes: Control = %MapNodes
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
	(%StatusToggleButton as Button).pressed.connect(_on_info_toggle_pressed)
	(%bag as Button).pressed.connect(_on_bag_pressed)
	(%fightsetting as Button).pressed.connect(_on_fightsetting_pressed)
	(%StatusCloseButton as Button).pressed.connect(_hide_info_popups)
	(%Step as Label).gui_input.connect(_on_step_gui_input)
	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)
	if not _map_world.resized.is_connected(_queue_map_refresh_after_layout):
		_map_world.resized.connect(_queue_map_refresh_after_layout)
	if not _map_canvas.resized.is_connected(_queue_map_refresh_after_layout):
		_map_canvas.resized.connect(_queue_map_refresh_after_layout)
	if not _map_nodes.resized.is_connected(_queue_map_refresh_after_layout):
		_map_nodes.resized.connect(_queue_map_refresh_after_layout)
	_map_node_template = %MapNodeTemplate as Button
	if _map_node_template != null:
		_map_node_template.visible = false
	_resize_map_world()
	_refresh_all()
	_queue_map_refresh_after_layout()
	if ExpeditionState.phase == "battle" and ExpeditionState.pending_battle_event_id != "":
		var pending_event := ExpeditionEventServiceScript.by_id(ExpeditionState.pending_battle_event_id)
		if not pending_event.is_empty():
			_show_pending_battle_popup(pending_event)
	if get_tree().root.has_meta("smoke_auto_exit") and bool(get_tree().root.get_meta("smoke_auto_exit")):
		call_deferred("_on_exit_pressed")


func _refresh_all() -> void:
	var location: Dictionary = ExpeditionState.effective_location()
	var min_diff := maxi(1, int(location.get("min_difficulty", 1)))
	var max_diff := int(location.get("max_difficulty", 0))
	var diff_text := "难度 %d" % min_diff if max_diff <= 0 or max_diff == min_diff else "难度 %d-%d" % [min_diff, max_diff]
	(%Header as Label).text = "%s · %s · 已行进 %s · 预计结算 %s" % [
		str(location.get("name", "")),
		diff_text,
		GameState.time_duration_label(ExpeditionState.estimated_elapsed_days()),
		GameState.time_duration_label(ExpeditionState.planned_elapsed_days()),
	]
	_refresh_progress_dots()
	_refresh_status_panel()
	_refresh_step_label()
	_refresh_map_display()
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
	(%HudHpLabel as Label).text = "气血  %.0f / %.0f" % [hp, hp_max]
	var hud_hp_bar := %HudHpBar as ProgressBar
	hud_hp_bar.max_value = hp_max
	hud_hp_bar.value = clampf(hp, 0.0, hp_max)
	(%HudMpLabel as Label).text = "法力  %.0f / %.0f" % [mp, mp_max]
	var hud_mp_bar := %HudMpBar as ProgressBar
	hud_mp_bar.max_value = mp_max
	hud_mp_bar.value = clampf(mp, 0.0, mp_max)
	var stats := ExpeditionState.stats
	(%Runtime as RichTextLabel).text = "战斗 %d  胜 %d  负 %d" % [
		int(stats.get("battles", 0)),
		int(stats.get("wins", 0)),
		int(stats.get("losses", 0)),
	]


func _refresh_controls() -> void:
	var exit_button := %ExitButton as Button
	exit_button.disabled = _locked or not _can_manual_exit()
	var utility_enabled := _can_open_utility_panels()
	(%bag as Button).disabled = not utility_enabled
	(%fightsetting as Button).disabled = not utility_enabled


## 战前弹窗已关闭且仍有待战事件：可再次打开迎战，或点主动返程走战前撤退
func _is_pending_battle_dismissed() -> bool:
	if ExpeditionState.phase != "battle" or ExpeditionState.pending_battle_event_id == "":
		return false
	if _locked:
		return false
	var popup := %BattlePopup as ExpeditionBattlePopupView
	return popup != null and not popup.visible


func _can_manual_exit() -> bool:
	return ExpeditionState.can_exit() or _is_pending_battle_dismissed()


func _refresh_step_label() -> void:
	var step := %Step as Label
	var base := "过程第 %d 日 · %d 件事" % [ExpeditionState.days, ExpeditionState.steps]
	if _is_pending_battle_dismissed():
		step.text = "%s · 遭遇战待处理（点此迎战）" % base
		step.mouse_filter = Control.MOUSE_FILTER_STOP
		step.add_theme_color_override("font_color", Color(0.635294, 0.239216, 0.168627, 1.0))
	else:
		step.text = base
		step.mouse_filter = Control.MOUSE_FILTER_IGNORE
		step.remove_theme_color_override("font_color")


func _on_step_gui_input(event: InputEvent) -> void:
	if not _is_pending_battle_dismissed():
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_reopen_pending_battle_popup()


func _reopen_pending_battle_popup() -> void:
	var pending_event := ExpeditionEventServiceScript.by_id(ExpeditionState.pending_battle_event_id)
	if pending_event.is_empty():
		return
	_show_pending_battle_popup(pending_event)
	_refresh_all()


func _can_open_utility_panels() -> bool:
	if not ExpeditionState.active:
		return false
	if SceneManager.is_expedition_fight_overlay_active():
		return false
	return true


func _refresh_progress_dots() -> void:
	var total := maxi(1, ExpeditionState.map_nodes.size())
	var visited := ExpeditionState.visited_node_ids.size()
	var switches := _route_switch_summary()
	(%ProgressDots as Label).visible = true
	(%ProgressDots as Label).text = "路线 %d / %d · 改线 %d / %d" % [
		visited,
		total,
		int(switches.get("remaining", 0)),
		int(switches.get("total", 0)),
	]


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
	_refresh_all()


func _auto_advance_seconds() -> float:
	return maxf(0.1, float(
		ExpeditionRulesServiceScript.rules().get("auto_event_advance_seconds", 1.0)
	))


func _schedule_auto_advance(continue_after: bool = true) -> void:
	_refresh_controls()


func _stop_auto_advance() -> void:
	if _auto_advance_timer != null:
		_auto_advance_timer.stop()
	_auto_chain_after_timer = false


func _on_auto_advance_timeout() -> void:
	_refresh_controls()


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
		_refresh_all()
		return
	_handle_step_result(result)


func _on_exit_pressed() -> void:
	if _is_pending_battle_dismissed():
		ExpeditionState.retreat_from_pending_battle()
		SceneManager.go_expedition_result("manual")
		return
	if not ExpeditionState.can_exit():
		return
	SceneManager.go_expedition_result("manual")


func _on_bag_pressed() -> void:
	if not _can_open_utility_panels():
		return
	var nav: Dictionary = SceneManager.go_backpack_panel()
	if not bool(nav.get("ok", false)):
		var err := str(nav.get("error", "无法打开储物袋")).strip_edges()
		if err != "":
			(%Feedback as Label).text = err


func _on_fightsetting_pressed() -> void:
	if not _can_open_utility_panels():
		return
	var nav: Dictionary = SceneManager.go_combat_loadout_panel()
	if not bool(nav.get("ok", false)):
		var err := str(nav.get("error", "无法打开战斗设置")).strip_edges()
		if err != "":
			(%Feedback as Label).text = err


func _on_info_toggle_pressed() -> void:
	var panel := %StatusPanel as Control
	if panel == null:
		return
	var will_show := not panel.visible
	_hide_info_popups()
	panel.visible = will_show
	if will_show:
		_scroll_log_to_latest(%Log as RichTextLabel)


func _hide_info_popups() -> void:
	var panel := %StatusPanel as Control
	if panel != null:
		panel.visible = false


func _route_switch_summary() -> Dictionary:
	var nodes_by_id := {}
	var current_layer := 0
	var current_node := ExpeditionMapServiceScript.node_by_id(ExpeditionState.map_nodes, ExpeditionState.current_node_id)
	if not current_node.is_empty():
		current_layer = int(current_node.get("layer", 0))
	for node_v in ExpeditionState.map_nodes:
		if not node_v is Dictionary:
			continue
		var node := node_v as Dictionary
		nodes_by_id[str(node.get("id", ""))] = node
	var outgoing_count_by_node := {}
	for edge_v in ExpeditionState.map_edges:
		if not edge_v is Dictionary:
			continue
		var edge := edge_v as Dictionary
		var from_id := str(edge.get("from", ""))
		outgoing_count_by_node[from_id] = int(outgoing_count_by_node.get(from_id, 0)) + 1
	var switch_layers := {}
	for from_id in outgoing_count_by_node.keys():
		if int(outgoing_count_by_node.get(from_id, 0)) <= 1:
			continue
		if not nodes_by_id.has(from_id):
			continue
		var node := nodes_by_id[from_id] as Dictionary
		var layer := int(node.get("layer", 0))
		if layer <= 0:
			continue
		switch_layers[layer] = true
	var total := 0
	var remaining := 0
	for layer_v in switch_layers.keys():
		total += 1
		if int(layer_v) >= current_layer:
			remaining += 1
	return {"total": total, "remaining": remaining}


func _resize_map_world() -> void:
	if _map_world == null or not is_inside_tree():
		return
	var viewport_size := get_viewport_rect().size
	var target_width := maxf(1500.0, viewport_size.x * 1.55)
	var target_height := maxf(500.0, viewport_size.y - 260.0)
	_map_world.custom_minimum_size = Vector2(target_width, target_height)
	if _map_scroll != null:
		_map_scroll.scroll_horizontal = clampi(
			_map_scroll.scroll_horizontal,
			0,
			maxi(0, int(target_width - _map_scroll.size.x))
		)


func _on_resized() -> void:
	_resize_map_world()
	_queue_map_refresh_after_layout()


func _queue_map_refresh_after_layout() -> void:
	if _map_refresh_pending:
		return
	_map_refresh_pending = true
	call_deferred("_refresh_map_after_layout")


func _refresh_map_after_layout() -> void:
	await get_tree().process_frame
	_map_refresh_pending = false
	_resize_map_world()
	_refresh_map_display()


func _fallback_hub() -> void:
	SceneManager.go_hub()


func _go_completed_result() -> void:
	var reason := ExpeditionState.pending_exit_reason
	if reason == "":
		reason = "defeated"
	SceneManager.go_expedition_result(reason)


func _prepare_battle_popup() -> void:
	var popup := %BattlePopup as ExpeditionBattlePopupView
	if popup == null:
		return
	if not popup.fight_requested.is_connected(_on_battle_fight_requested):
		popup.fight_requested.connect(_on_battle_fight_requested)
	if not popup.close_requested.is_connected(_on_battle_popup_close_requested):
		popup.close_requested.connect(_on_battle_popup_close_requested)


func _show_pending_battle_popup(event: Dictionary) -> void:
	_locked = true
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


## 历练叠层战斗结束后由 SceneManager 回调：解锁 UI 并刷新状态，不重建场景。
func resume_after_battle() -> void:
	_locked = false
	var popup := %BattlePopup as ExpeditionBattlePopupView
	if popup != null:
		popup.visible = false
	_refresh_all()


## 历练浮层面板（背包/战斗设置）关闭后刷新界面。
func resume_after_panel() -> void:
	var ui_rt: Dictionary = DataStore.ui_runtime()
	var feedback := str(ui_rt.get("expedition_bag_feedback", "")).strip_edges()
	ui_rt["expedition_bag_feedback"] = ""
	if feedback != "":
		(%Feedback as Label).text = feedback
	ExpeditionState.sync_runtime_loadout_from_game()
	_refresh_all()


## 取消按钮：仅关闭战前弹窗，不触发撤退结算
func _on_battle_popup_close_requested() -> void:
	if not _locked:
		return
	var popup := %BattlePopup as ExpeditionBattlePopupView
	if popup != null:
		popup.visible = false
	_locked = false
	_refresh_all()


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


func _refresh_map_display() -> void:
	if _map_canvas == null or _map_nodes == null:
		return
	var snapshot := ExpeditionState.map_snapshot()
	var nodes := snapshot.get("nodes", []) as Array
	var edges := snapshot.get("edges", []) as Array
	_map_canvas.setup(nodes, edges)
	_clear_generated_map_nodes()
	var available := snapshot.get("available_node_ids", []) as Array
	var visited := snapshot.get("visited_node_ids", []) as Array
	var current := str(snapshot.get("current_node_id", ""))
	for node_v in nodes:
		if not node_v is Dictionary:
			continue
		var node := node_v as Dictionary
		var view: Button = _make_map_node()
		if view == null:
			continue
		var node_id := str(node.get("id", ""))
		var state := "locked"
		if node_id == current:
			state = "pending_battle" if _is_pending_battle_dismissed() else "current"
		if visited.has(node_id) and state != "pending_battle":
			state = "visited"
		if available.has(node_id):
			state = "available"
		view.call("setup", node, state)
		var pos: Vector2 = _map_canvas.call("node_position", node)
		view.position = pos - view.custom_minimum_size * 0.5
		view.visible = true
		var callback := Callable(self, "_on_map_node_selected")
		if not view.is_connected("node_selected", callback):
			view.connect("node_selected", callback)


func _clear_generated_map_nodes() -> void:
	if _map_nodes == null:
		return
	for child in _map_nodes.get_children():
		if child == _map_node_template:
			child.visible = false
			continue
		child.queue_free()


func _make_map_node() -> Button:
	if _map_nodes == null or _map_node_template == null:
		return null
	var copy_v: Variant = _map_node_template.duplicate()
	if not copy_v is Button:
		return null
	var copy := copy_v as Button
	_map_nodes.add_child(copy)
	return copy


func _on_map_node_selected(node_id: String) -> void:
	if _locked:
		return
	# 取消战前弹窗后，点当前遭遇节点重新打开
	if _is_pending_battle_dismissed() and node_id == ExpeditionState.current_node_id:
		_reopen_pending_battle_popup()
		return
	_locked = true
	_refresh_controls()
	var began: Dictionary = ExpeditionState.choose_map_node(node_id)
	_locked = false
	if not bool(began.get("ok", false)):
		var feedback := str(began.get("feedback", began.get("error", ""))).strip_edges()
		if feedback != "":
			(%Feedback as Label).text = feedback
		_refresh_all()
		return
	_handle_step_begin(began)
