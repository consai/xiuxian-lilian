extends Node

const LOOP_SCENE := "res://scenes/expedition/expedition_loop.tscn"
const RESULT_SCENE := "res://scenes/expedition/expedition_result.tscn"
const InventoryServiceScript := preload("res://scripts/sim/inventory_service.gd")
const LocationServiceScript := preload("res://scripts/expedition/location_service.gd")
const ExpeditionEventServiceScript := preload("res://scripts/expedition/expedition_event_service.gd")
const ExpeditionRewardServiceScript := preload("res://scripts/expedition/expedition_reward_service.gd")
const ExpeditionRulesServiceScript := preload("res://scripts/expedition/expedition_rules_service.gd")

var active := false
var phase := "idle"
var location_id := ""
var depth := 1
var steps := 0
var seed := 0
var rng_state := 0
var runtime := {"hp": 0.0, "mp": 0.0, "item_slots": ["", ""], "inventory": {}}
var loot: Array = []
var current_choices: Array = []
var current_event_id := ""
var pending_battle_event_id := ""
var pending_battle_summary: Dictionary = {}
var pending_battle_rewards: Array = []
var visited_once_events: Array = []
var stats := {}
var event_log: Array = []
var player_snapshot := {}
var pending_exit_reason := ""
var last_finish_result: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _game_state: Node = null


func start(location_id_value: String, game_state: Node, seed_override: int = -1) -> Dictionary:
	if active:
		return {"ok": false, "error": "已有进行中的历练"}
	var location := LocationServiceScript.by_id(location_id_value)
	if location.is_empty():
		return {"ok": false, "error": "未知地点"}
	reset()
	_game_state = game_state
	location_id = location_id_value
	seed = seed_override if seed_override >= 0 else int(Time.get_unix_time_from_system()) % 2147483647
	_rng.seed = seed
	rng_state = _rng.state
	active = true
	phase = "choosing"
	depth = 1
	steps = 0
	loot = []
	current_choices = []
	visited_once_events = []
	event_log = []
	stats = {
		"steps": 0,
		"battles": 0,
		"wins": 0,
		"losses": 0,
		"max_depth": 1,
		"boss_defeated": false,
	}
	player_snapshot = _copy_player_snapshot(game_state)
	runtime = _copy_runtime_from_game(game_state)
	current_choices = generate_choices()
	return {"ok": true, "location": location, "choices": current_choices.duplicate(true)}


func generate_choices() -> Array:
	if not active:
		return []
	_restore_rng()
	var location := LocationServiceScript.by_id(location_id)
	current_choices = ExpeditionEventServiceScript.generate_choices(
		location, depth, visited_once_events, _rng
	)
	_save_rng()
	phase = "choosing"
	current_event_id = ""
	return current_choices.duplicate(true)


func choose_event(event_id: String) -> Dictionary:
	if not active or phase != "choosing":
		return {"ok": false, "error": "当前无法选择事件"}
	var chosen: Dictionary = {}
	for choice_v in current_choices:
		var choice := choice_v as Dictionary
		if str(choice.get("id", "")) == event_id:
			chosen = choice
			break
	if chosen.is_empty():
		return {"ok": false, "error": "无效的事件选择"}
	current_event_id = event_id
	current_choices = [chosen]
	var event_type := str(chosen.get("type", ""))
	if ExpeditionRulesServiceScript.is_battle_type(event_type):
		pending_battle_event_id = event_id
		phase = "battle"
		return {"ok": true, "type": "battle", "event": chosen}
	phase = "resolving"
	_restore_rng()
	var result := ExpeditionEventServiceScript.resolve_non_battle_event(
		chosen, runtime, player_snapshot.get("attrs", {}) as Dictionary, depth, _rng
	)
	_save_rng()
	if not bool(result.get("ok", false)):
		return result
	_apply_step_after_event(chosen, result.get("rewards", []) as Array, str(result.get("feedback", "")))
	phase = "choosing"
	generate_choices()
	result["choices"] = current_choices.duplicate(true)
	return result


func build_battle_init() -> Dictionary:
	if pending_battle_event_id == "":
		return {}
	var event := ExpeditionEventServiceScript.by_id(pending_battle_event_id)
	if event.is_empty():
		return {}
	var player: Dictionary = {}
	if _game_state != null:
		player = _game_state.build_player_battle_snapshot(runtime)
	var enemy := ExpeditionEventServiceScript.build_battle_enemy(event, depth)
	return {
		"player": player,
		"enemy": enemy,
		"battle_time_limit": 200.0,
		"auto_battle": {"player": false, "enemy": true},
		"spd_jitter_ratio": 0.0,
	}


func receive_battle_summary(summary: Dictionary) -> void:
	pending_battle_summary = summary.duplicate(true)
	pending_battle_rewards = []
	if str(summary.get("outcome", "")) != "win" or pending_battle_event_id == "":
		return
	var event := ExpeditionEventServiceScript.by_id(pending_battle_event_id)
	if event.is_empty():
		return
	_restore_rng()
	pending_battle_rewards = ExpeditionRewardServiceScript.roll_event_rewards(event, depth, _rng)
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
		ExpeditionRewardServiceScript.merge_into_loot(loot, pending_battle_rewards)
		pending_battle_rewards = []
		if str(event.get("type", "")) == "boss":
			stats["boss_defeated"] = true
			if bool(event.get("once_per_expedition", false)):
				visited_once_events.append(pending_battle_event_id)
		_apply_step_after_event(event, [], "战斗胜利")
		pending_battle_event_id = ""
		pending_battle_summary = {}
		phase = "choosing"
		generate_choices()
		return {"ok": true, "won": true, "choices": current_choices.duplicate(true)}
	stats["losses"] = int(stats.get("losses", 0)) + 1
	pending_exit_reason = "defeated"
	pending_battle_event_id = ""
	pending_battle_summary = {}
	pending_battle_rewards = []
	current_choices = []
	phase = "result"
	return {"ok": true, "won": false, "forced_exit": true}


func can_exit() -> bool:
	return active and phase in ["choosing", "resolving"] and pending_exit_reason == ""


func finish(exit_reason: String) -> Dictionary:
	if not active and last_finish_result.is_empty():
		return {"ok": false, "error": "没有可结算的历练"}
	var reason := exit_reason
	if reason == "manual" and bool(stats.get("boss_defeated", false)):
		reason = "boss_complete"
	var elapsed_days: int = ExpeditionRulesServiceScript.elapsed_days(steps)
	var loot_for_settlement := loot.duplicate(true)
	var loot_lost: Array = []
	if reason == "defeated":
		var loss := ExpeditionRewardServiceScript.apply_loot_loss_on_defeat(loot)
		loot_for_settlement = loss.get("kept", []) as Array
		loot_lost = loss.get("lost", []) as Array
		var rules: Dictionary = ExpeditionRulesServiceScript.rules()
		var hp_max := float((player_snapshot.get("attrs", {}) as Dictionary).get(FightAttr.HP_MAX, 100.0))
		runtime["hp"] = maxf(float(runtime.get("hp", 0.0)), hp_max * float(rules.get("defeat_hp_floor_ratio", 0.25)))
	var result := {
		"ok": true,
		"exit_reason": reason,
		"elapsed_days": elapsed_days,
		"hp": float(runtime.get("hp", 0.0)),
		"mp": float(runtime.get("mp", 0.0)),
		"items": _runtime_items_for_settlement(),
		"loot": loot_for_settlement,
		"loot_lost": loot_lost,
		"location_name": str(LocationServiceScript.by_id(location_id).get("name", location_id)),
		"stats": stats.duplicate(true),
	}
	last_finish_result = result.duplicate(true)
	reset()
	return result


func reset() -> void:
	active = false
	phase = "idle"
	location_id = ""
	depth = 1
	steps = 0
	seed = 0
	rng_state = 0
	runtime = {"hp": 0.0, "mp": 0.0, "item_slots": ["", ""], "inventory": {}}
	loot = []
	current_choices = []
	current_event_id = ""
	pending_battle_event_id = ""
	pending_battle_summary = {}
	pending_battle_rewards = []
	visited_once_events = []
	stats = {}
	event_log = []
	player_snapshot = {}
	pending_exit_reason = ""
	_game_state = null


func estimated_elapsed_days() -> int:
	return ExpeditionRulesServiceScript.elapsed_days(steps)


func should_go_to_result() -> bool:
	return pending_exit_reason != "" or phase == "result"


func _apply_step_after_event(event: Dictionary, extra_rewards: Array, feedback: String) -> void:
	ExpeditionRewardServiceScript.merge_into_loot(loot, extra_rewards)
	if bool(event.get("once_per_expedition", false)):
		var event_id := str(event.get("id", ""))
		if event_id != "" and not visited_once_events.has(event_id):
			visited_once_events.append(event_id)
	steps += 1
	depth += 1
	stats["steps"] = steps
	stats["max_depth"] = maxi(int(stats.get("max_depth", 1)), depth - 1)
	event_log.append({
		"depth": depth - 1,
		"event_id": str(event.get("id", "")),
		"name": str(event.get("name", "")),
		"feedback": feedback,
	})


func _sync_runtime_from_summary(summary: Dictionary) -> void:
	var runtime_summary := summary.get("player_runtime", {}) as Dictionary
	runtime["hp"] = float(runtime_summary.get("hp", runtime.get("hp", 0.0)))
	runtime["mp"] = float(runtime_summary.get("mp", runtime.get("mp", 0.0)))
	var inv := runtime.get("inventory", {}) as Dictionary
	var slots := runtime.get("item_slots", ["", ""]) as Array
	InventoryServiceScript.sync_battle_item_counts(inv, slots, runtime_summary.get("items", []) as Array)
	runtime["inventory"] = inv


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


func _rng_from_state() -> RandomNumberGenerator:
	_restore_rng()
	return _rng
