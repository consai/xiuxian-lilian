extends Node

const InventoryServiceScript := preload("res://scripts/sim/inventory_service.gd")
const LocationServiceScript := preload("res://scripts/expedition/location_service.gd")
const ExpeditionEventServiceScript := preload("res://scripts/expedition/expedition_event_service.gd")
const ExpeditionRewardServiceScript := preload("res://scripts/expedition/expedition_reward_service.gd")
const ExpeditionRulesServiceScript := preload("res://scripts/expedition/expedition_rules_service.gd")
const ExpeditionDirectorServiceScript := preload("res://scripts/expedition/expedition_director_service.gd")
const ExpeditionLogServiceScript := preload("res://scripts/expedition/expedition_log_service.gd")

signal log_updated

var _pending_log_index := -1
var _pending_step_event: Dictionary = {}

var active: bool:
	get: return bool(DataStore.expedition_runtime().get("active", false))
	set(value): DataStore.expedition_runtime()["active"] = value
var phase: String:
	get: return str(DataStore.expedition_runtime().get("phase", "idle"))
	set(value): DataStore.expedition_runtime()["phase"] = value
var location_id: String:
	get: return str(DataStore.expedition_runtime().get("location_id", ""))
	set(value): DataStore.expedition_runtime()["location_id"] = value
var active_chain_id: String:
	get: return str(DataStore.expedition_runtime().get("active_chain_id", ""))
	set(value): DataStore.expedition_runtime()["active_chain_id"] = value
var completed_events: Array:
	get: return DataStore.expedition_runtime().get("completed_events", []) as Array
	set(value): DataStore.expedition_runtime()["completed_events"] = value
var auto_advance: bool:
	get: return bool(DataStore.expedition_runtime().get("auto_advance", true))
	set(value): DataStore.expedition_runtime()["auto_advance"] = value
var steps: int:
	get: return int(DataStore.expedition_runtime().get("steps", 0))
	set(value): DataStore.expedition_runtime()["steps"] = value
var days: int:
	get: return int(DataStore.expedition_runtime().get("days", 0))
	set(value): DataStore.expedition_runtime()["days"] = value
var days_without_event: int:
	get: return int(DataStore.expedition_runtime().get("days_without_event", 0))
	set(value): DataStore.expedition_runtime()["days_without_event"] = value
var seed: int:
	get: return int(DataStore.expedition_runtime().get("seed", 0))
	set(value): DataStore.expedition_runtime()["seed"] = value
var rng_state: int:
	get: return int(DataStore.expedition_runtime().get("rng_state", 0))
	set(value): DataStore.expedition_runtime()["rng_state"] = value
var runtime: Dictionary:
	get: return DataStore.expedition_runtime().get("runtime", {}) as Dictionary
	set(value): DataStore.expedition_runtime()["runtime"] = value
var loot: Array:
	get: return DataStore.expedition_runtime().get("loot", []) as Array
	set(value): DataStore.expedition_runtime()["loot"] = value
var current_choices: Array:
	get: return DataStore.expedition_runtime().get("current_choices", []) as Array
	set(value): DataStore.expedition_runtime()["current_choices"] = value
var pending_decision_event: Dictionary:
	get: return DataStore.expedition_runtime().get("pending_decision_event", {}) as Dictionary
	set(value): DataStore.expedition_runtime()["pending_decision_event"] = value
var current_event_id: String:
	get: return str(DataStore.expedition_runtime().get("current_event_id", ""))
	set(value): DataStore.expedition_runtime()["current_event_id"] = value
var pending_battle_event_id: String:
	get: return str(DataStore.expedition_runtime().get("pending_battle_event_id", ""))
	set(value): DataStore.expedition_runtime()["pending_battle_event_id"] = value
var pending_battle_summary: Dictionary:
	get: return DataStore.expedition_runtime().get("pending_battle_summary", {}) as Dictionary
	set(value): DataStore.expedition_runtime()["pending_battle_summary"] = value
var pending_battle_rewards: Array:
	get: return DataStore.expedition_runtime().get("pending_battle_rewards", []) as Array
	set(value): DataStore.expedition_runtime()["pending_battle_rewards"] = value
var visited_once_events: Array:
	get: return DataStore.expedition_runtime().get("visited_once_events", []) as Array
	set(value): DataStore.expedition_runtime()["visited_once_events"] = value
var stats: Dictionary:
	get: return DataStore.expedition_runtime().get("stats", {}) as Dictionary
	set(value): DataStore.expedition_runtime()["stats"] = value
var event_log: Array:
	get: return DataStore.expedition_runtime().get("event_log", []) as Array
	set(value): DataStore.expedition_runtime()["event_log"] = value
var player_snapshot: Dictionary:
	get: return DataStore.expedition_runtime().get("player_snapshot", {}) as Dictionary
	set(value): DataStore.expedition_runtime()["player_snapshot"] = value
var pending_exit_reason: String:
	get: return str(DataStore.expedition_runtime().get("pending_exit_reason", ""))
	set(value): DataStore.expedition_runtime()["pending_exit_reason"] = value
var expedition_id: String:
	get: return str(DataStore.expedition_runtime().get("expedition_id", ""))
	set(value): DataStore.expedition_runtime()["expedition_id"] = value
var start_day: int:
	get: return int(DataStore.expedition_runtime().get("start_day", 0))
	set(value): DataStore.expedition_runtime()["start_day"] = value
const _MAX_QUIET_DAY_CHAIN := 32

var _rng := RandomNumberGenerator.new()
var _game_state: Node = null


func start(location_id_value: String, game_state: Node, seed_override: int = -1) -> Dictionary:
	if active:
		return {"ok": false, "error": "已有进行中的历练"}
	var location := LocationServiceScript.by_id(location_id_value)
	if location.is_empty():
		return {"ok": false, "error": "未知地点"}
	var effective_location := location.duplicate(true)
	var override_v: Variant = DataStore.expedition_runtime().get("difficulty_override", {})
	if override_v is Dictionary:
		var override := override_v as Dictionary
		if not override.is_empty():
			var loc_min := maxi(1, int(location.get("min_difficulty", 1)))
			var loc_max := int(location.get("max_difficulty", 0))
			if loc_max <= 0:
				loc_max = loc_min
			var chosen_min := clampi(int(override.get("min_difficulty", loc_min)), loc_min, loc_max)
			var chosen_max := clampi(int(override.get("max_difficulty", loc_max)), loc_min, loc_max)
			if chosen_max < chosen_min:
				chosen_max = chosen_min
			effective_location["min_difficulty"] = chosen_min
			effective_location["max_difficulty"] = chosen_max
	reset()
	_game_state = game_state
	start_day = int(game_state.day) if game_state != null else 0
	expedition_id = _new_expedition_id()
	location_id = location_id_value
	active_chain_id = ""
	completed_events = []
	seed = seed_override if seed_override >= 0 else int(Time.get_unix_time_from_system()) % 2147483647
	_rng.seed = seed
	rng_state = _rng.state
	active = true
	phase = "resolving"
	auto_advance = true
	steps = 0
	days = 0
	days_without_event = 0
	loot = []
	current_choices = []
	pending_decision_event = {}
	visited_once_events = []
	event_log = []
	stats = {
		"steps": 0,
		"days": 0,
		"battles": 0,
		"wins": 0,
		"losses": 0,
		"max_difficulty": 0,
	}
	player_snapshot = _copy_player_snapshot(game_state)
	runtime = _copy_runtime_from_game(game_state)
	DataStore.expedition_runtime()["effective_location"] = effective_location
	DataStore.expedition_runtime().erase("difficulty_override")
	event_log.append(ExpeditionLogServiceScript.build_departure_entry(effective_location))
	return {"ok": true, "location": effective_location}


func advance_step() -> Dictionary:
	var began := advance_day()
	if not bool(began.get("ok", false)):
		return began
	if str(began.get("mode", "")) == "pass_day":
		return began
	if str(began.get("mode", "")) == "resolving":
		return complete_current_step()
	return began


func advance_day() -> Dictionary:
	var result: Dictionary = {}
	for _i in _MAX_QUIET_DAY_CHAIN:
		result = _advance_single_day()
		if not bool(result.get("ok", false)):
			return result
		if str(result.get("mode", "")) != "pass_day":
			return result
	return result


func _advance_single_day() -> Dictionary:
	if not active:
		return {"ok": false, "error": "历练未进行"}
	if phase == "battle":
		return {"ok": false, "error": "战斗进行中"}
	if not _pending_step_event.is_empty():
		return {"ok": false, "error": "上一步事件尚未结算"}
	days += 1
	stats["days"] = days
	_restore_rng()
	if not ExpeditionRulesServiceScript.should_trigger_event_today(days_without_event, _rng):
		days_without_event += 1
		_save_rng()
		return {"ok": true, "mode": "pass_day"}
	var event := ExpeditionDirectorServiceScript.select_next_event(_director_context(), _rng)
	if event.is_empty():
		days_without_event += 1
		_save_rng()
		return {"ok": true, "mode": "pass_day"}
	days_without_event = 0
	var began := _start_event(event)
	_save_rng()
	return began


func begin_next_step() -> Dictionary:
	return advance_day()


func complete_current_step() -> Dictionary:
	if _pending_step_event.is_empty():
		return {"ok": false, "error": "没有待结算的事件"}
	var event := _pending_step_event.duplicate(true)
	_pending_step_event = {}
	return _resolve_auto_event_finish(event)


func _start_event(event: Dictionary) -> Dictionary:
	if ExpeditionEventServiceScript.is_decision_event(event):
		_begin_log_event(event)
		pending_decision_event = event.duplicate(true)
		current_choices = ExpeditionEventServiceScript.decision_options_as_choices(event)
		current_event_id = ""
		phase = "choosing"
		return {
			"ok": true,
			"mode": "decision",
			"event": event,
			"scene": ExpeditionLogServiceScript.event_scene(event),
			"choices": current_choices.duplicate(true),
		}
	_pending_step_event = event.duplicate(true)
	return _begin_auto_event(event)


func _begin_auto_event(event: Dictionary) -> Dictionary:
	var chosen := event.duplicate(true)
	current_event_id = str(chosen.get("id", ""))
	current_choices = []
	pending_decision_event = {}
	phase = "resolving"
	_begin_log_event(chosen)
	var scene := ExpeditionLogServiceScript.event_scene(chosen)
	var event_type := str(chosen.get("type", ""))
	if ExpeditionRulesServiceScript.is_battle_type(event_type):
		pending_battle_event_id = current_event_id
		phase = "battle"
		_pending_step_event = {}
		var enemy_name := str((chosen.get("enemy", {}) as Dictionary).get("name", chosen.get("name", "强敌")))
		var encounter := "%s拦住了去路，杀气扑面！" % enemy_name
		return {
			"ok": true,
			"mode": "battle",
			"type": "battle",
			"event": chosen,
			"scene": scene,
			"outcome": encounter,
			"feedback": encounter,
		}
	return {
		"ok": true,
		"mode": "resolving",
		"event": chosen,
		"scene": scene,
	}


func _resolve_auto_event_finish(event: Dictionary) -> Dictionary:
	var chosen := event.duplicate(true)
	current_event_id = str(chosen.get("id", ""))
	_restore_rng()
	var result := ExpeditionEventServiceScript.resolve_non_battle_event(
		chosen, runtime, player_snapshot.get("attrs", {}) as Dictionary, _rng
	)
	_save_rng()
	if not bool(result.get("ok", false)):
		_cancel_pending_log_entry()
		phase = "choosing"
		return result
	var resolved_event := result.get("event", chosen) as Dictionary
	_apply_step_after_event(
		resolved_event,
		result.get("rewards", []) as Array,
		str(result.get("outcome", result.get("feedback", "")))
	)
	result["mode"] = "auto_done"
	result["event"] = resolved_event
	if pending_exit_reason == "":
		phase = "resolving"
	return result


func choose_event(choice_id: String) -> Dictionary:
	if not active:
		return {"ok": false, "error": "当前无法选择事件"}
	if phase == "resolving" and pending_decision_event.is_empty():
		return _resolve_manual_event_choice(choice_id)
	if phase != "choosing":
		return {"ok": false, "error": "当前无法选择事件"}
	if not pending_decision_event.is_empty():
		return _resolve_decision_choice(choice_id)
	return _resolve_manual_event_choice(choice_id)


func _resolve_decision_choice(choice_id: String) -> Dictionary:
	var parent := pending_decision_event.duplicate(true)
	var parsed := ExpeditionEventServiceScript.parse_decision_choice_id(choice_id)
	var option_id := str(parsed.get("option_id", ""))
	if option_id == "":
		return {"ok": false, "error": "无效的抉择"}
	var option := ExpeditionEventServiceScript.find_decision_option(parent, option_id)
	if option.is_empty():
		return {"ok": false, "error": "无效的抉择选项"}
	pending_decision_event = {}
	current_choices = []
	current_event_id = str(parent.get("id", ""))
	if pending_exit_reason == "":
		phase = "resolving"
	_restore_rng()
	var result := ExpeditionEventServiceScript.resolve_decision_option(
		parent,
		option,
		runtime,
		player_snapshot.get("attrs", {}) as Dictionary,
		_rng
	)
	_save_rng()
	if not bool(result.get("ok", false)):
		phase = "choosing"
		pending_decision_event = parent
		current_choices = ExpeditionEventServiceScript.decision_options_as_choices(parent)
		return result
	if str(result.get("type", "")) == "battle":
		var battle_event := result.get("event", {}) as Dictionary
		pending_battle_event_id = str(battle_event.get("id", ""))
		phase = "battle"
		result["mode"] = "battle"
		_mark_once_per_expedition(parent)
		return result
	_mark_once_per_expedition(parent)
	var log_event := result.get("event", parent) as Dictionary
	_apply_step_after_event(
		log_event,
		result.get("rewards", []) as Array,
		str(result.get("outcome", result.get("feedback", ""))),
		str(result.get("log_name", log_event.get("name", "")))
	)
	result["mode"] = "auto_done"
	result["event"] = log_event
	if pending_exit_reason == "":
		phase = "resolving"
	return result


func _resolve_manual_event_choice(event_id: String) -> Dictionary:
	var chosen: Dictionary = {}
	for choice_v in current_choices:
		var choice := choice_v as Dictionary
		if str(choice.get("id", "")) == event_id:
			chosen = choice
			break
	if chosen.is_empty():
		chosen = ExpeditionEventServiceScript.by_id(event_id)
	if chosen.is_empty():
		return {"ok": false, "error": "无效的事件选择"}
	current_choices = []
	_begin_log_event(chosen)
	var event_type := str(chosen.get("type", ""))
	if ExpeditionRulesServiceScript.is_battle_type(event_type):
		current_event_id = str(chosen.get("id", ""))
		pending_battle_event_id = current_event_id
		phase = "battle"
		var enemy_name := str((chosen.get("enemy", {}) as Dictionary).get("name", chosen.get("name", "强敌")))
		var encounter := "%s拦住了去路，杀气扑面！" % enemy_name
		return {
			"ok": true,
			"mode": "battle",
			"type": "battle",
			"event": chosen,
			"scene": ExpeditionLogServiceScript.event_scene(chosen),
			"outcome": encounter,
			"feedback": encounter,
		}
	_pending_step_event = chosen.duplicate(true)
	return complete_current_step()


func build_battle_init() -> Dictionary:
	if pending_battle_event_id == "":
		return {}
	var event := ExpeditionEventServiceScript.by_id(pending_battle_event_id)
	if event.is_empty():
		return {}
	var player: Dictionary = {}
	if _game_state != null:
		player = _game_state.build_player_battle_snapshot(runtime)
	if not PlayerBattleSnapshot.collect_errors(player).is_empty():
		return {}
	var enemy := ExpeditionEventServiceScript.build_battle_enemy(event)
	var init_data := {
		"player": player,
		"enemy": enemy,
		"battle_time_limit": 200.0,
		"auto_battle": {"player": false, "enemy": true},
		"spd_jitter_ratio": 0.0,
	}
	var init_errors := BattleInitData.collect_errors(init_data)
	if not init_errors.is_empty():
		push_error("build_battle_init: %s" % init_errors[0])
		return {}
	return init_data


func receive_battle_summary(summary: Dictionary) -> void:
	var summary_errors := BattleSummary.collect_errors(summary)
	if not summary_errors.is_empty():
		push_error("BattleSummary: %s" % summary_errors[0])
		return
	pending_battle_summary = BattleSummary.to_dict(summary)
	pending_battle_rewards = []
	if str(summary.get("outcome", "")) != "win" or pending_battle_event_id == "":
		return
	var event := ExpeditionEventServiceScript.by_id(pending_battle_event_id)
	if event.is_empty():
		return
	_restore_rng()
	pending_battle_rewards = ExpeditionRewardServiceScript.roll_event_rewards(event, _rng)
	_save_rng()


func settle_pending_battle() -> Dictionary:
	if pending_battle_summary.is_empty() or pending_battle_event_id == "":
		return {"ok": false, "error": "没有待结算的战斗"}
	var summary := pending_battle_summary
	var event := ExpeditionEventServiceScript.by_id(pending_battle_event_id)
	_sync_runtime_from_summary(summary)
	var won := str(summary.get("outcome", "")) == "win"
	stats["battles"] = int(stats.get("battles", 0)) + 1
	if won:
		stats["wins"] = int(stats.get("wins", 0)) + 1
		var battle_rewards := pending_battle_rewards.duplicate(true)
		_apply_session_rewards(battle_rewards)
		pending_battle_rewards = []
		_apply_step_after_event(
			event,
			[],
			ExpeditionLogServiceScript.build_battle_victory_outcome(event, battle_rewards)
		)
		pending_battle_event_id = ""
		pending_battle_summary = {}
		if pending_exit_reason == "":
			phase = "resolving"
		current_choices = []
		pending_decision_event = {}
		return {"ok": true, "won": true, "mode": "auto_done", "event": event}
	stats["losses"] = int(stats.get("losses", 0)) + 1
	if not event.is_empty():
		_apply_event_duration(event)
		var defeat_outcome := ExpeditionLogServiceScript.build_battle_defeat_outcome(event)
		if _pending_log_index >= 0:
			_finish_pending_log_outcome(defeat_outcome)
		else:
			event_log.append(
				ExpeditionLogServiceScript.build_battle_defeat_entry(
					event,
					days,
					_event_difficulty(event)
				)
			)
			log_updated.emit()
	pending_exit_reason = "defeated"
	pending_battle_event_id = ""
	pending_battle_summary = {}
	pending_battle_rewards = []
	current_choices = []
	phase = "result"
	return {"ok": true, "won": false, "forced_exit": true}


func can_exit() -> bool:
	if not active or pending_exit_reason != "":
		return false
	if phase == "battle":
		return false
	if phase == "choosing":
		return true
	if phase == "resolving":
		return pending_decision_event.is_empty() and pending_battle_event_id == ""
	return false


func clear_pending_battle() -> void:
	pending_battle_event_id = ""
	pending_battle_summary = {}
	pending_battle_rewards = []
	if phase == "battle":
		phase = "resolving"
		current_choices = []
		pending_decision_event = {}


func retreat_from_pending_battle() -> Dictionary:
	if pending_battle_event_id == "" or phase != "battle":
		return {"ok": false, "error": "没有待处理的战斗"}
	var event := ExpeditionEventServiceScript.by_id(pending_battle_event_id)
	clear_pending_battle()
	if not event.is_empty():
		var enemy_name := str((event.get("enemy", {}) as Dictionary).get("name", event.get("name", "强敌")))
		_finish_pending_log_outcome(
			"见%s来势凶猛，你当机立断，抽身撤退，结束本次历练。" % enemy_name
		)
	return {"ok": true, "event": event}


func finish(exit_reason: String) -> Dictionary:
	if not active:
		return {"ok": false, "error": "没有可结算的历练"}
	var reason := exit_reason
	var elapsed_days: int = ExpeditionRulesServiceScript.elapsed_days(days)
	var loot_lost: Array = []
	if reason == "defeated":
		_restore_rng()
		var loss := ExpeditionRewardServiceScript.apply_inventory_loss_on_defeat(
			_project_inventory_for_settlement(), _rng
		)
		_save_rng()
		loot_lost = loss.get("lost", []) as Array
		var rules: Dictionary = ExpeditionRulesServiceScript.rules()
		var hp_max := float((player_snapshot.get("attrs", {}) as Dictionary).get(FightAttr.HP_MAX, 100.0))
		runtime["hp"] = maxf(float(runtime.get("hp", 0.0)), hp_max * float(rules.get("defeat_hp_floor_ratio", 0.25)))
	var result := ExpeditionResult.to_dict({
		"ok": true,
		"settlement_id": expedition_id,
		"exit_reason": reason,
		"start_day": start_day,
		"elapsed_days": maxi(1, elapsed_days),
		"hp": float(runtime.get("hp", 0.0)),
		"mp": float(runtime.get("mp", 0.0)),
		"items": _runtime_items_for_settlement(),
		"loot": loot.duplicate(true),
		"loot_lost": loot_lost,
		"location_name": str(LocationServiceScript.by_id(location_id).get("name", location_id)),
		"stats": stats.duplicate(true),
		"chronicle": _build_chronicle(),
		"world_changes": _world_changes(),
	})
	var result_errors := ExpeditionResult.collect_errors(result)
	if not result_errors.is_empty():
		return {"ok": false, "error": result_errors[0]}
	reset()
	return result


func reset() -> void:
	_pending_log_index = -1
	_pending_step_event = {}
	DataStore.reset_expedition_runtime()
	_game_state = null


func estimated_elapsed_days() -> int:
	return ExpeditionRulesServiceScript.elapsed_days(days)


func should_go_to_result() -> bool:
	return pending_exit_reason != "" or phase == "result"


func _mark_once_per_expedition(event: Dictionary) -> void:
	if not bool(event.get("once_per_expedition", false)):
		return
	var event_id := str(event.get("id", ""))
	if event_id != "" and not visited_once_events.has(event_id):
		visited_once_events.append(event_id)


func _begin_log_event(event: Dictionary, log_name: String = "") -> void:
	var title := log_name.strip_edges()
	if title == "":
		title = str(event.get("name", ""))
	var entry := ExpeditionLogServiceScript.build_event_entry(
		event,
		days,
		_event_difficulty(event),
		ExpeditionLogServiceScript.event_scene(event),
		"",
		title
	)
	event_log.append(entry)
	_pending_log_index = event_log.size() - 1
	log_updated.emit()


func _finish_pending_log_outcome(outcome: String) -> void:
	if _pending_log_index < 0 or _pending_log_index >= event_log.size():
		return
	var entry := event_log[_pending_log_index] as Dictionary
	ExpeditionLogServiceScript.apply_outcome(entry, outcome)
	_pending_log_index = -1
	log_updated.emit()


func _cancel_pending_log_entry() -> void:
	if _pending_log_index >= 0 and _pending_log_index < event_log.size():
		event_log.remove_at(_pending_log_index)
	_pending_log_index = -1
	log_updated.emit()


func _apply_step_after_event(
		event: Dictionary,
		extra_rewards: Array,
		outcome: String,
		log_name: String = ""
) -> void:
	_apply_session_rewards(extra_rewards)
	_mark_once_per_expedition(event)
	steps += 1
	_apply_event_duration(event)
	var event_difficulty := _event_difficulty(event)
	stats["steps"] = steps
	stats["max_difficulty"] = maxi(int(stats.get("max_difficulty", 0)), event_difficulty)
	if _pending_log_index >= 0 and _pending_log_index < event_log.size():
		var entry := event_log[_pending_log_index] as Dictionary
		entry["difficulty"] = event_difficulty
		entry["journey_step"] = days
		if log_name.strip_edges() != "":
			entry["name"] = log_name
		ExpeditionLogServiceScript.apply_outcome(entry, outcome)
		_pending_log_index = -1
	else:
		var title := log_name if log_name.strip_edges() != "" else str(event.get("name", ""))
		event_log.append(
			ExpeditionLogServiceScript.build_event_entry(
				event,
				days,
				event_difficulty,
				ExpeditionLogServiceScript.event_scene(event),
				outcome,
				title
			)
		)
	log_updated.emit()
	var event_id := str(event.get("id", ""))
	if event_id != "" and not completed_events.has(event_id):
		completed_events.append(event_id)
	var chain_id := str(event.get("chain_id", ""))
	if active_chain_id == "" and chain_id != "":
		active_chain_id = chain_id


func _apply_event_duration(event: Dictionary) -> void:
	var duration_days := maxi(1, int(event.get("duration_days", 1)))
	if duration_days > 1:
		days += duration_days - 1
	stats["days"] = days


func _sync_runtime_from_summary(summary: Dictionary) -> void:
	var runtime_summary := summary.get("player_runtime", {}) as Dictionary
	runtime["hp"] = float(runtime_summary.get("hp", runtime.get("hp", 0.0)))
	runtime["mp"] = float(runtime_summary.get("mp", runtime.get("mp", 0.0)))
	var inv := runtime.get("inventory", {}) as Dictionary
	var slots := runtime.get("item_slots", ["", ""]) as Array
	InventoryServiceScript.sync_battle_item_counts(inv, slots, runtime_summary.get("items", []) as Array)
	runtime["inventory"] = inv


func _apply_session_rewards(rewards: Array) -> void:
	if rewards.is_empty():
		return
	ExpeditionRewardServiceScript.merge_into_loot(loot, rewards)


func _project_inventory_for_settlement() -> Dictionary:
	if _game_state == null:
		return (runtime.get("inventory", {}) as Dictionary).duplicate(true)
	var inv := (_game_state.inventory as Dictionary).duplicate(true)
	var runtime_inv := runtime.get("inventory", {}) as Dictionary
	for slot_v in runtime.get("item_slots", []) as Array:
		var iid := str(slot_v)
		if iid == "":
			continue
		var remaining := int(runtime_inv.get(iid, 0))
		if remaining > 0:
			inv[iid] = remaining
		else:
			inv.erase(iid)
	return inv


func _runtime_items_for_settlement() -> Array:
	var out: Array = []
	var inv := runtime.get("inventory", {}) as Dictionary
	for slot_v in runtime.get("item_slots", []) as Array:
		var iid := str(slot_v)
		if iid == "":
			continue
		out.append({"inventory_id": iid, "count": int(inv.get(iid, 0))})
	return out


func _copy_runtime_from_game(game_state: Node) -> Dictionary:
	var inv := {}
	for slot_v in game_state.item_slots as Array:
		var iid := str(slot_v)
		if iid != "":
			inv[iid] = int(game_state.inventory.get(iid, 0))
	return {
		"hp": float(game_state.hp),
		"mp": float(game_state.mp),
		"item_slots": (game_state.item_slots as Array).duplicate(true),
		"inventory": inv,
	}


func _copy_player_snapshot(game_state: Node) -> Dictionary:
	return {
		"name": str(game_state.player_name),
		"icon": str(game_state.player_icon),
		"attrs": (game_state.attrs as Dictionary).duplicate(true),
		"equipped_skills": (game_state.equipped_skills as Array).duplicate(true),
		"equip_slots": (game_state.equip_slots as Array).duplicate(true),
	}


func _restore_rng() -> void:
	_rng.seed = seed
	if rng_state != 0:
		_rng.state = rng_state


func _save_rng() -> void:
	rng_state = _rng.state


func _new_expedition_id() -> String:
	return "expedition_%d_%d" % [int(Time.get_unix_time_from_system() * 1000.0), randi()]


func _event_difficulty(event: Dictionary) -> int:
	return maxi(1, int(event.get("difficulty", 1)))


func effective_location() -> Dictionary:
	var stored_v: Variant = DataStore.expedition_runtime().get("effective_location", {})
	if stored_v is Dictionary and not (stored_v as Dictionary).is_empty():
		return (stored_v as Dictionary).duplicate(true)
	return LocationServiceScript.by_id(location_id)


func _director_context() -> Dictionary:
	return {
		"location": effective_location(),
		"active_chain_id": active_chain_id,
		"completed_events": completed_events,
		"runtime": runtime,
		"player_attrs": player_snapshot.get("attrs", {}) as Dictionary,
		"world_state": _game_state.world_state if _game_state != null else {},
		"stats": stats,
	}


func _world_changes() -> Array:
	var changes: Array = []
	for event_id_v in completed_events:
		var event := ExpeditionEventServiceScript.by_id(str(event_id_v))
		for change_v in event.get("world_effects", []) as Array:
			if change_v is Dictionary:
				changes.append((change_v as Dictionary).duplicate(true))
	return changes


func _build_chronicle() -> Array:
	var lines: Array = []
	for entry_v in event_log:
		var entry := entry_v as Dictionary
		lines.append(ExpeditionLogServiceScript.format_plain(entry))
	return lines


func _rng_from_state() -> RandomNumberGenerator:
	_restore_rng()
	return _rng
