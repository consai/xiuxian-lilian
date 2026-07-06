extends Node

const InventoryServiceScript := preload("res://scripts/sim/inventory_service.gd")
const DidianServiceScript := preload("res://scripts/lilian/didian_service.gd")
const LilianEventServiceScript := preload("res://scripts/lilian/lilian_event_service.gd")
const LilianRewardServiceScript := preload("res://scripts/lilian/lilian_reward_service.gd")
const LilianRulesServiceScript := preload("res://scripts/lilian/lilian_rules_service.gd")
const LilianLogServiceScript := preload("res://scripts/lilian/lilian_log_service.gd")
const LilianMapServiceScript := preload("res://scripts/lilian/lilian_map_service.gd")
const EnumLilianNodeTypeScript := preload("res://scripts/enum/enum_lilian_node_type.gd")
const GameTimeServiceScript := preload("res://scripts/sim/game_time_service.gd")

signal log_updated
## 历练局内气血/法力等即时状态变化（如背包用药），供底层 HUD 同步刷新。
signal runtime_vitals_changed(feedback: String)

var _pending_log_index := -1
var _pending_step_event: Dictionary = {}

var active: bool:
	get: return bool(DataStore.lilian_runtime().get("active", false))
	set(value): DataStore.lilian_runtime()["active"] = value
var phase: String:
	get: return str(DataStore.lilian_runtime().get("phase", "idle"))
	set(value): DataStore.lilian_runtime()["phase"] = value
var location_id: String:
	get: return str(DataStore.lilian_runtime().get("location_id", ""))
	set(value): DataStore.lilian_runtime()["location_id"] = value
var auto_advance: bool:
	get: return bool(DataStore.lilian_runtime().get("auto_advance", true))
	set(value): DataStore.lilian_runtime()["auto_advance"] = value
var steps: int:
	get: return int(DataStore.lilian_runtime().get("steps", 0))
	set(value): DataStore.lilian_runtime()["steps"] = value
var days: int:
	get: return int(DataStore.lilian_runtime().get("days", 0))
	set(value): DataStore.lilian_runtime()["days"] = value
var days_without_event: int:
	get: return int(DataStore.lilian_runtime().get("days_without_event", 0))
	set(value): DataStore.lilian_runtime()["days_without_event"] = value
var seed: int:
	get: return int(DataStore.lilian_runtime().get("seed", 0))
	set(value): DataStore.lilian_runtime()["seed"] = value
var rng_state: int:
	get: return int(DataStore.lilian_runtime().get("rng_state", 0))
	set(value): DataStore.lilian_runtime()["rng_state"] = value
var runtime: Dictionary:
	get: return DataStore.lilian_runtime().get("runtime", {}) as Dictionary
	set(value): DataStore.lilian_runtime()["runtime"] = value
var loot: Array:
	get: return DataStore.lilian_runtime().get("loot", []) as Array
	set(value): DataStore.lilian_runtime()["loot"] = value
var current_choices: Array:
	get: return DataStore.lilian_runtime().get("current_choices", []) as Array
	set(value): DataStore.lilian_runtime()["current_choices"] = value
var pending_decision_event: Dictionary:
	get: return DataStore.lilian_runtime().get("pending_decision_event", {}) as Dictionary
	set(value): DataStore.lilian_runtime()["pending_decision_event"] = value
var current_event_id: String:
	get: return str(DataStore.lilian_runtime().get("current_event_id", ""))
	set(value): DataStore.lilian_runtime()["current_event_id"] = value
var pending_battle_event_id: String:
	get: return str(DataStore.lilian_runtime().get("pending_battle_event_id", ""))
	set(value): DataStore.lilian_runtime()["pending_battle_event_id"] = value
var pending_battle_summary: Dictionary:
	get: return DataStore.lilian_runtime().get("pending_battle_summary", {}) as Dictionary
	set(value): DataStore.lilian_runtime()["pending_battle_summary"] = value
var pending_battle_rewards: Array:
	get: return DataStore.lilian_runtime().get("pending_battle_rewards", []) as Array
	set(value): DataStore.lilian_runtime()["pending_battle_rewards"] = value
var visited_once_events: Array:
	get: return DataStore.lilian_runtime().get("visited_once_events", []) as Array
	set(value): DataStore.lilian_runtime()["visited_once_events"] = value
var map_nodes: Array:
	get: return DataStore.lilian_runtime().get("map_nodes", []) as Array
	set(value): DataStore.lilian_runtime()["map_nodes"] = value
var map_edges: Array:
	get: return DataStore.lilian_runtime().get("map_edges", []) as Array
	set(value): DataStore.lilian_runtime()["map_edges"] = value
var current_node_id: String:
	get: return str(DataStore.lilian_runtime().get("current_node_id", ""))
	set(value): DataStore.lilian_runtime()["current_node_id"] = value
var available_node_ids: Array:
	get: return DataStore.lilian_runtime().get("available_node_ids", []) as Array
	set(value): DataStore.lilian_runtime()["available_node_ids"] = value
var visited_node_ids: Array:
	get: return DataStore.lilian_runtime().get("visited_node_ids", []) as Array
	set(value): DataStore.lilian_runtime()["visited_node_ids"] = value
var resolved_node_events: Dictionary:
	get: return DataStore.lilian_runtime().get("resolved_node_events", {}) as Dictionary
	set(value): DataStore.lilian_runtime()["resolved_node_events"] = value
var stats: Dictionary:
	get: return DataStore.lilian_runtime().get("stats", {}) as Dictionary
	set(value): DataStore.lilian_runtime()["stats"] = value
var event_log: Array:
	get: return DataStore.lilian_runtime().get("event_log", []) as Array
	set(value): DataStore.lilian_runtime()["event_log"] = value
var player_snapshot: Dictionary:
	get: return DataStore.lilian_runtime().get("player_snapshot", {}) as Dictionary
	set(value): DataStore.lilian_runtime()["player_snapshot"] = value
var pending_exit_reason: String:
	get: return str(DataStore.lilian_runtime().get("pending_exit_reason", ""))
	set(value): DataStore.lilian_runtime()["pending_exit_reason"] = value
var lilian_id: String:
	get: return str(DataStore.lilian_runtime().get("lilian_id", ""))
	set(value): DataStore.lilian_runtime()["lilian_id"] = value
var start_day: int:
	get: return int(DataStore.lilian_runtime().get("start_day", 0))
	set(value): DataStore.lilian_runtime()["start_day"] = value
const _MAX_QUIET_DAY_CHAIN := 32

var _rng := RandomNumberGenerator.new()
var _game_state: Node = null


func start(location_id_value: String, game_state: Node, seed_override: int = -1) -> Dictionary:
	if active:
		return {"ok": false, "error": "已有进行中的历练"}
	var location := DidianServiceScript.by_id(location_id_value)
	if location.is_empty():
		return {"ok": false, "error": "未知地点"}
	var effective_location := location.duplicate(true)
	effective_location["id"] = location_id_value
	var override_v: Variant = DataStore.lilian_runtime().get("difficulty_override", {})
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
	lilian_id = _new_lilian_id()
	location_id = location_id_value
	seed = seed_override if seed_override >= 0 else int(Time.get_unix_time_from_system()) % 2147483647
	_rng.seed = seed
	rng_state = _rng.state
	active = true
	phase = "resolving"
	auto_advance = false
	steps = 0
	days = 0
	days_without_event = 0
	loot = []
	current_choices = []
	pending_decision_event = {}
	visited_once_events = []
	var generated_map := (
		LilianMapServiceScript.generate_tutorial(effective_location)
		if TutorialService.should_use_tutorial_lilian_map()
		else LilianMapServiceScript.generate(effective_location, seed)
	)
	map_nodes = generated_map.get("nodes", []) as Array
	map_edges = generated_map.get("edges", []) as Array
	var start_node_id := str(generated_map.get("start_node_id", "start"))
	current_node_id = start_node_id
	visited_node_ids = [start_node_id]
	available_node_ids = LilianMapServiceScript.next_node_ids(
		{"nodes": map_nodes, "edges": map_edges, "start_node_id": start_node_id},
		start_node_id,
		visited_node_ids
	)
	resolved_node_events = {}
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
	DataStore.lilian_runtime()["effective_location"] = effective_location
	DataStore.lilian_runtime().erase("difficulty_override")
	event_log.append(LilianLogServiceScript.build_departure_entry(effective_location))
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
	if not active:
		return {"ok": false, "error": "历练未进行"}
	if phase == "battle":
		return {"ok": false, "error": "战斗进行中"}
	if available_node_ids.is_empty():
		return {"ok": false, "error": "没有可前往的路线节点"}
	return choose_map_node(str(available_node_ids[0]))


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
	if not LilianRulesServiceScript.should_trigger_event_today(days_without_event, _rng):
		days_without_event += 1
		_save_rng()
		return {"ok": true, "mode": "pass_day"}
	var event := LilianEventServiceScript.roll_next_event(
		effective_location(),
		visited_once_events,
		_rng
	)
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


func choose_map_node(node_id: String) -> Dictionary:
	if not active:
		return {"ok": false, "error": "历练未进行"}
	if phase == "battle":
		return {"ok": false, "error": "战斗进行中"}
	if not _pending_step_event.is_empty():
		return {"ok": false, "error": "上一步事件尚未结算"}
	var target_id := node_id.strip_edges()
	if target_id == "" or not available_node_ids.has(target_id):
		return {"ok": false, "error": "当前路线不可前往"}
	var node := LilianMapServiceScript.node_by_id(map_nodes, target_id)
	if node.is_empty():
		return {"ok": false, "error": "未知路线节点"}
	current_node_id = target_id
	available_node_ids = []
	days += 1
	stats["days"] = days
	_restore_rng()
	var event := LilianEventServiceScript.roll_event_for_node(
		effective_location(),
		node,
		visited_once_events,
		_rng
	)
	_save_rng()
	if event.is_empty():
		_complete_current_node()
		return {
			"ok": true,
			"mode": "pass_day",
			"node": node,
			"feedback": "%s一带风平浪静，你继续向前。" % str(node.get("label", "此处")),
		}
	resolved_node_events[target_id] = str(event.get("id", ""))
	var began := _start_event(event)
	began["node"] = node
	return began


func complete_current_step() -> Dictionary:
	if _pending_step_event.is_empty():
		return {"ok": false, "error": "没有待结算的事件"}
	var event := _pending_step_event.duplicate(true)
	_pending_step_event = {}
	return _resolve_auto_event_finish(event)


func _start_event(event: Dictionary) -> Dictionary:
	if LilianEventServiceScript.is_decision_event(event):
		_begin_log_event(event)
		pending_decision_event = event.duplicate(true)
		current_choices = LilianEventServiceScript.decision_options_as_choices(event)
		current_event_id = ""
		phase = "choosing"
		return {
			"ok": true,
			"mode": "decision",
			"event": event,
			"scene": LilianLogServiceScript.event_scene(event),
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
	var scene := LilianLogServiceScript.event_scene(chosen)
	var event_type := str(chosen.get("type", ""))
	if LilianRulesServiceScript.is_battle_type(event_type):
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
	var result := LilianEventServiceScript.resolve_non_battle_event(
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
	var parsed := LilianEventServiceScript.parse_decision_choice_id(choice_id)
	var option_id := str(parsed.get("option_id", ""))
	if option_id == "":
		return {"ok": false, "error": "无效的抉择"}
	var option := LilianEventServiceScript.find_decision_option(parent, option_id)
	if option.is_empty():
		return {"ok": false, "error": "无效的抉择选项"}
	pending_decision_event = {}
	current_choices = []
	current_event_id = str(parent.get("id", ""))
	if pending_exit_reason == "":
		phase = "resolving"
	_restore_rng()
	var result := LilianEventServiceScript.resolve_decision_option(
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
		current_choices = LilianEventServiceScript.decision_options_as_choices(parent)
		return result
	if str(result.get("type", "")) == "battle":
		var battle_event := result.get("event", {}) as Dictionary
		pending_battle_event_id = str(battle_event.get("id", ""))
		phase = "battle"
		result["mode"] = "battle"
		_mark_once_per_lilian(parent)
		return result
	_mark_once_per_lilian(parent)
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
		chosen = LilianEventServiceScript.by_id(event_id)
	if chosen.is_empty():
		return {"ok": false, "error": "无效的事件选择"}
	current_choices = []
	_restore_rng()
	var node := LilianMapServiceScript.node_by_id(map_nodes, current_node_id)
	if str(node.get("type", "")) == EnumLilianNodeTypeScript.ID_START:
		node = {}
	chosen = LilianEventServiceScript.materialize_event_for_context(effective_location(), node, chosen, _rng)
	_save_rng()
	_begin_log_event(chosen)
	var event_type := str(chosen.get("type", ""))
	if LilianRulesServiceScript.is_battle_type(event_type):
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
			"scene": LilianLogServiceScript.event_scene(chosen),
			"outcome": encounter,
			"feedback": encounter,
		}
	_pending_step_event = chosen.duplicate(true)
	return complete_current_step()


func build_battle_init() -> Dictionary:
	if pending_battle_event_id == "":
		return {}
	var event := LilianEventServiceScript.by_id(pending_battle_event_id)
	if event.is_empty():
		return {}
	var player: Dictionary = {}
	if _game_state != null:
		player = _game_state.build_player_battle_snapshot(runtime)
	if not PlayerBattleSnapshot.collect_errors(player).is_empty():
		return {}
	var enemy := LilianEventServiceScript.build_battle_enemy(event)
	var enemies := LilianEventServiceScript.build_battle_enemies(event)
	var enemy_formation := LilianEventServiceScript.build_enemy_formation(event, enemies)
	var event_type := str(event.get("type", "")).strip_edges()
	var init_data := {
		"player": player,
		"enemy": enemy,
		"enemies": enemies,
		"enemy_formation": enemy_formation,
		"battle_time_limit": 200.0,
		"auto_battle": {"player": bool(_game_state.auto_battle_enabled), "enemy": true},
		"spd_jitter_ratio": 0.0,
		"flags": {"can_flee": event_type != "boss"},
		"escape_bonus": _escape_bonus_from_player(player),
	}
	var init_errors := ZhandouInitData.collect_errors(init_data)
	if not init_errors.is_empty():
		push_error("build_battle_init: %s" % init_errors[0])
		return {}
	return init_data


func receive_battle_summary(summary: Dictionary) -> void:
	var summary_errors := ZhandouSummary.collect_errors(summary)
	if not summary_errors.is_empty():
		push_error("ZhandouSummary: %s" % summary_errors[0])
		return
	pending_battle_summary = ZhandouSummary.to_dict(summary)
	pending_battle_rewards = []
	if str(summary.get("outcome", "")) != "win" or pending_battle_event_id == "":
		return
	var event := LilianEventServiceScript.by_id(pending_battle_event_id)
	if event.is_empty():
		return
	_restore_rng()
	pending_battle_rewards = LilianRewardServiceScript.roll_event_rewards(event, _rng)
	_save_rng()


func settle_pending_battle() -> Dictionary:
	if pending_battle_summary.is_empty() or pending_battle_event_id == "":
		return {"ok": false, "error": "没有待结算的战斗"}
	var summary := pending_battle_summary
	var event := LilianEventServiceScript.by_id(pending_battle_event_id)
	_sync_runtime_from_summary(summary)
	var won := str(summary.get("outcome", "")) == "win"
	var fled := str(summary.get("outcome", "")) == ZhandouSummary.OUTCOME_ESCAPED
	stats["battles"] = int(stats.get("battles", 0)) + 1
	if won:
		stats["wins"] = int(stats.get("wins", 0)) + 1
		var battle_rewards := pending_battle_rewards.duplicate(true)
		if TutorialService.is_active() and StoryDirector.is_waiting_for("tutorial.first_battle_won"):
			battle_rewards.append({"kind": "item", "id": "items_LingCao", "count": 2})
		_apply_session_rewards(battle_rewards)
		pending_battle_rewards = []
		_apply_step_after_event(
			event,
			[],
			LilianLogServiceScript.build_battle_victory_outcome(event, battle_rewards)
		)
		pending_battle_event_id = ""
		pending_battle_summary = {}
		if pending_exit_reason == "":
			phase = "resolving"
		current_choices = []
		pending_decision_event = {}
		TutorialService.game_event("tutorial.first_battle_won")
		return {"ok": true, "won": true, "mode": "auto_done", "event": event}
	if fled:
		if not event.is_empty():
			_apply_event_duration(event)
			var fled_outcome := LilianLogServiceScript.build_battle_fled_outcome(event)
			if _pending_log_index >= 0:
				_finish_pending_log_outcome(fled_outcome)
			else:
				event_log.append(
					LilianLogServiceScript.build_battle_fled_entry(
						event,
						days,
						_event_difficulty(event)
					)
				)
				log_updated.emit()
		pending_exit_reason = "fled"
		pending_battle_event_id = ""
		pending_battle_summary = {}
		pending_battle_rewards = []
		current_choices = []
		phase = "result"
		return {"ok": true, "won": false, "fled": true, "forced_exit": true}
	stats["losses"] = int(stats.get("losses", 0)) + 1
	if not event.is_empty():
		_apply_event_duration(event)
		var defeat_outcome := LilianLogServiceScript.build_battle_defeat_outcome(event)
		if _pending_log_index >= 0:
			_finish_pending_log_outcome(defeat_outcome)
		else:
			event_log.append(
				LilianLogServiceScript.build_battle_defeat_entry(
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
	var event := LilianEventServiceScript.by_id(pending_battle_event_id)
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
	var elapsed_days: int = LilianRulesServiceScript.elapsed_days(days, _major_realm_id())
	var settlement_loot := loot.duplicate(true)
	var loot_lost: Array = []
	if reason == "defeated":
		var loot_loss := LilianRewardServiceScript.apply_loot_loss_on_defeat(settlement_loot)
		loot_lost.append_array(loot_loss.get("lost", []) as Array)
		var rules: Dictionary = LilianRulesServiceScript.rules()
		var hp_max := float((player_snapshot.get("attrs", {}) as Dictionary).get(ZhandouAttr.HP_MAX, 100.0))
		runtime["hp"] = maxf(float(runtime.get("hp", 0.0)), hp_max * float(rules.get("defeat_hp_floor_ratio", 0.25)))
	var result := LilianResult.to_dict({
		"ok": true,
		"settlement_id": lilian_id,
		"exit_reason": reason,
		"start_day": start_day,
		"elapsed_days": maxi(1, elapsed_days),
		"duration_label": GameTimeServiceScript.duration_label(maxi(1, elapsed_days)),
		"hp": float(runtime.get("hp", 0.0)),
		"mp": float(runtime.get("mp", 0.0)),
		"items": _runtime_items_for_settlement(),
		"loot": settlement_loot,
		"loot_lost": loot_lost,
		"location_name": str(DidianServiceScript.by_id(location_id).get("name", location_id)),
		"location_id": location_id,
		"stats": stats.duplicate(true),
		"event_log": _duplicate_event_log(),
		"chronicle": _build_chronicle(),
	})
	var result_errors := LilianResult.collect_errors(result)
	if not result_errors.is_empty():
		return {"ok": false, "error": result_errors[0]}
	reset()
	return result


func reset() -> void:
	_pending_log_index = -1
	_pending_step_event = {}
	DataStore.reset_lilian_runtime()
	_game_state = null


func planned_elapsed_days() -> int:
	return LilianRulesServiceScript.elapsed_days(days, _major_realm_id())


func estimated_elapsed_days() -> int:
	return maxi(0, days)


func should_go_to_result() -> bool:
	return pending_exit_reason != "" or phase == "result"


func _mark_once_per_lilian(event: Dictionary) -> void:
	if not bool(event.get("once_per_lilian", false)):
		return
	var event_id := str(event.get("id", ""))
	if event_id != "" and not visited_once_events.has(event_id):
		visited_once_events.append(event_id)


func _begin_log_event(event: Dictionary, log_name: String = "") -> void:
	var title := log_name.strip_edges()
	if title == "":
		title = str(event.get("name", ""))
	var entry := LilianLogServiceScript.build_event_entry(
		event,
		days,
		_event_difficulty(event),
		LilianLogServiceScript.event_scene(event),
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
	LilianLogServiceScript.apply_outcome(entry, outcome)
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
	_mark_once_per_lilian(event)
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
		LilianLogServiceScript.apply_outcome(entry, outcome)
		_pending_log_index = -1
	else:
		var title := log_name if log_name.strip_edges() != "" else str(event.get("name", ""))
		event_log.append(
			LilianLogServiceScript.build_event_entry(
				event,
				days,
				event_difficulty,
				LilianLogServiceScript.event_scene(event),
				outcome,
				title
			)
		)
	log_updated.emit()
	_complete_current_node()


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
	var slots := runtime.get("item_slots", ["", "", ""]) as Array
	InventoryServiceScript.sync_battle_item_counts(inv, slots, runtime_summary.get("items", []) as Array)
	runtime["inventory"] = inv


func use_runtime_item_slot(slot_index: int) -> Dictionary:
	if not active:
		return {"ok": false, "error": "历练未进行"}
	if slot_index < 0 or slot_index >= 3:
		return {"ok": false, "error": "无效丹药槽"}
	var slots := (runtime.get("item_slots", ["", "", ""]) as Array).duplicate(true)
	while slots.size() < 3:
		slots.append("")
	var item_id := str(slots[slot_index]).strip_edges()
	if item_id == "":
		return {"ok": false, "error": "该槽位未装备丹药"}
	return use_runtime_inventory_item(item_id)


## 历练背包中右键/使用消耗品：扣减 runtime 库存并恢复气血法力。
func use_runtime_inventory_item(item_id: String) -> Dictionary:
	if not active:
		return {"ok": false, "error": "历练未进行"}
	if _blocks_runtime_item_use():
		return {"ok": false, "error": "战斗中无法使用丹药"}
	var iid := item_id.strip_edges()
	if iid == "":
		return {"ok": false, "error": "无效物品"}
	var inv := (runtime.get("inventory", {}) as Dictionary).duplicate(true)
	if int(inv.get(iid, 0)) <= 0:
		return {"ok": false, "error": "背包中没有该物品"}
	var def: ItemDef = null
	if ConfigManager != null:
		def = ConfigManager.item_def_by_id(iid)
	if def == null:
		return {"ok": false, "error": "未知物品"}
	var mp_cost := maxf(0.0, float(def.fight_mp_cost))
	if mp_cost > 0.0 and float(runtime.get("mp", 0.0)) < mp_cost:
		return {"ok": false, "error": "法力不足，无法催动丹药"}
	var attrs := player_snapshot.get("attrs", {}) as Dictionary
	var feedback_parts := _apply_runtime_item_effects(def, attrs)
	if feedback_parts.is_empty():
		return {"ok": false, "error": "该物品无法在此使用"}
	if mp_cost > 0.0:
		runtime["mp"] = maxf(0.0, float(runtime.get("mp", 0.0)) - mp_cost)
	var remaining := maxi(0, int(inv.get(iid, 0)) - 1)
	if remaining > 0:
		inv[iid] = remaining
	else:
		inv.erase(iid)
	var slots := (runtime.get("item_slots", ["", "", ""]) as Array).duplicate(true)
	while slots.size() < 3:
		slots.append("")
	for slot_index in slots.size():
		if str(slots[slot_index]) == iid and remaining <= 0:
			slots[slot_index] = ""
	runtime["inventory"] = inv
	runtime["item_slots"] = slots
	var item_name := iid
	if ConfigManager != null:
		item_name = ConfigManager.get_item_display_name(iid)
	var feedback_text := "使用 %s，%s" % [item_name, "，".join(feedback_parts)]
	runtime_vitals_changed.emit(feedback_text)
	return {
		"ok": true,
		"feedback": feedback_text,
		"item_id": iid,
	}


func _blocks_runtime_item_use() -> bool:
	if SceneManager != null and SceneManager.has_method("is_lilian_zhandou_overlay_active"):
		return SceneManager.is_lilian_zhandou_overlay_active()
	return phase == "battle"


func _apply_runtime_item_effects(def: ItemDef, player_attrs: Dictionary) -> PackedStringArray:
	var feedback_parts: PackedStringArray = []
	var hp_max := maxf(1.0, float(player_attrs.get(ZhandouAttr.HP_MAX, 100.0)))
	var mp_max := maxf(1.0, float(player_attrs.get(ZhandouAttr.MP_MAX, 100.0)))
	if def.has_fight_config():
		for effect_v in def.fight_effect:
			if not effect_v is Dictionary:
				continue
			var effect := effect_v as Dictionary
			if str(effect.get("target", "self")).strip_edges() not in ["", "self"]:
				continue
			var value := float(effect.get("value", 0.0))
			match str(effect.get("type", "")):
				"heal":
					var hp_before := float(runtime.get("hp", 0.0))
					var healed := minf(hp_max - hp_before, value)
					runtime["hp"] = hp_before + healed
					if healed >= 1.0:
						feedback_parts.append("气血回升 %d 点" % int(round(healed)))
					else:
						feedback_parts.append("气血已满")
				"restore_mp":
					var mp_before := float(runtime.get("mp", 0.0))
					var restored := minf(mp_max - mp_before, value)
					runtime["mp"] = mp_before + restored
					if restored >= 1.0:
						feedback_parts.append("法力恢复 %d 点" % int(round(restored)))
					else:
						feedback_parts.append("法力已满")
	elif def.has_use_effect():
		for row_v in def.use_effect:
			if not row_v is Dictionary:
				continue
			var row := row_v as Dictionary
			var op := str(row.get("op", "")).strip_edges().to_lower()
			var args_v: Variant = row.get("args", [])
			var amount := 0.0
			if args_v is Array and not (args_v as Array).is_empty():
				amount = float((args_v as Array)[0])
			match op:
				"hp":
					var hp_before := float(runtime.get("hp", 0.0))
					var healed := minf(hp_max - hp_before, amount)
					runtime["hp"] = hp_before + healed
					if healed >= 1.0:
						feedback_parts.append("气血回升 %d 点" % int(round(healed)))
					else:
						feedback_parts.append("气血已满")
				"mp":
					var mp_before := float(runtime.get("mp", 0.0))
					var restored := minf(mp_max - mp_before, amount)
					runtime["mp"] = mp_before + restored
					if restored >= 1.0:
						feedback_parts.append("法力恢复 %d 点" % int(round(restored)))
					else:
						feedback_parts.append("法力已满")
	return feedback_parts


func _apply_session_rewards(rewards: Array) -> void:
	if rewards.is_empty():
		return
	LilianRewardServiceScript.merge_into_loot(loot, rewards)


func _project_inventory_for_settlement() -> Dictionary:
	return (runtime.get("inventory", {}) as Dictionary).duplicate(true)


func _runtime_items_for_settlement() -> Array:
	var out: Array = []
	var inv := runtime.get("inventory", {}) as Dictionary
	for iid_v in inv.keys():
		var iid := str(iid_v).strip_edges()
		if iid == "":
			continue
		out.append({"inventory_id": iid, "count": int(inv.get(iid_v, 0))})
	return out


func _copy_runtime_from_game(game_state: Node) -> Dictionary:
	return {
		"hp": float(game_state.hp),
		"mp": float(game_state.mp),
		"item_slots": (game_state.item_slots as Array).duplicate(true),
		"inventory": (game_state.inventory as Dictionary).duplicate(true),
		"owned_equips": (game_state.owned_equips as Array).duplicate(true),
	}


## 历练中调整战备后，把洞府道具槽写回 runtime，供下一场战斗读取。
func sync_runtime_peizhi_from_game() -> void:
	if _game_state == null:
		return
	runtime["item_slots"] = (_game_state.item_slots as Array).duplicate(true)


func _copy_player_snapshot(game_state: Node) -> Dictionary:
	return {
		"name": str(game_state.player_name),
		"icon": str(game_state.player_icon),
		"major_realm_id": str(game_state.major_realm_id()) if game_state.has_method("major_realm_id") else "",
		"attrs": (game_state.attrs as Dictionary).duplicate(true),
		"equipped_abilities": (game_state.equipped_abilities as Array).duplicate(true),
		"equip_slots": (game_state.equip_slots as Array).duplicate(true),
	}


func _major_realm_id() -> String:
	return str(player_snapshot.get("major_realm_id", ""))


func _restore_rng() -> void:
	_rng.seed = seed
	if rng_state != 0:
		_rng.state = rng_state


func _save_rng() -> void:
	rng_state = _rng.state


func _new_lilian_id() -> String:
	return "lilian_%d_%d" % [int(Time.get_unix_time_from_system() * 1000.0), randi()]


func _event_difficulty(event: Dictionary) -> int:
	return maxi(1, int(event.get("difficulty", 1)))


func effective_location() -> Dictionary:
	var stored_v: Variant = DataStore.lilian_runtime().get("effective_location", {})
	if stored_v is Dictionary and not (stored_v as Dictionary).is_empty():
		return (stored_v as Dictionary).duplicate(true)
	return DidianServiceScript.by_id(location_id)


func _duplicate_event_log() -> Array:
	var out: Array = []
	for entry_v in event_log:
		if entry_v is Dictionary:
			out.append((entry_v as Dictionary).duplicate(true))
	return out


func _build_chronicle() -> Array:
	var lines: Array = []
	for entry_v in event_log:
		var entry := entry_v as Dictionary
		lines.append(LilianLogServiceScript.format_plain(entry))
	return lines


func current_available_nodes() -> Array:
	var out: Array = []
	for node_id_v in available_node_ids:
		var node := LilianMapServiceScript.node_by_id(map_nodes, str(node_id_v))
		if not node.is_empty():
			out.append(node)
	return out


func map_snapshot() -> Dictionary:
	return {
		"nodes": map_nodes.duplicate(true),
		"edges": map_edges.duplicate(true),
		"current_node_id": current_node_id,
		"available_node_ids": available_node_ids.duplicate(),
		"visited_node_ids": visited_node_ids.duplicate(),
	}


## 出手速度越高，战中逃跑额外成功率略增（ponytail: 待 escape_success 养成接入后替换）。
func _escape_bonus_from_player(player: Dictionary) -> float:
	var attrs_v: Variant = player.get("attrs", {})
	if not attrs_v is Dictionary:
		return 0.0
	var spd := ZhandouAttr.get_attr(attrs_v as Dictionary, ZhandouAttr.SPD, 100.0)
	return clampf(spd / 2500.0, 0.0, 0.12)


func _complete_current_node() -> void:
	var node_id := current_node_id.strip_edges()
	if node_id == "":
		return
	if not visited_node_ids.has(node_id):
		visited_node_ids.append(node_id)
	available_node_ids = LilianMapServiceScript.next_node_ids(
		{"nodes": map_nodes, "edges": map_edges, "start_node_id": "start"},
		node_id,
		visited_node_ids
	)


func _rng_from_state() -> RandomNumberGenerator:
	_restore_rng()
	return _rng
