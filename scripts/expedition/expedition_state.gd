extends Node

const LOOP_SCENE := "res://scenes/expedition/expedition_loop.tscn"
const RESULT_SCENE := "res://scenes/expedition/expedition_result.tscn"
const InventoryServiceScript := preload("res://scripts/sim/inventory_service.gd")
const LocationServiceScript := preload("res://scripts/expedition/location_service.gd")
const ExpeditionEventServiceScript := preload("res://scripts/expedition/expedition_event_service.gd")
const ExpeditionRewardServiceScript := preload("res://scripts/expedition/expedition_reward_service.gd")
const ExpeditionRulesServiceScript := preload("res://scripts/expedition/expedition_rules_service.gd")
func _ds() -> Node:
	return DataStore


var active: bool:
	get: return bool(_ds().expedition_runtime().get("active", false))
	set(value): _ds().expedition_runtime()["active"] = value
var phase: String:
	get: return str(_ds().expedition_runtime().get("phase", "idle"))
	set(value): _ds().expedition_runtime()["phase"] = value
var location_id: String:
	get: return str(_ds().expedition_runtime().get("location_id", ""))
	set(value): _ds().expedition_runtime()["location_id"] = value
var depth: int:
	get: return int(_ds().expedition_runtime().get("depth", 1))
	set(value): _ds().expedition_runtime()["depth"] = value
var steps: int:
	get: return int(_ds().expedition_runtime().get("steps", 0))
	set(value): _ds().expedition_runtime()["steps"] = value
var seed: int:
	get: return int(_ds().expedition_runtime().get("seed", 0))
	set(value): _ds().expedition_runtime()["seed"] = value
var rng_state: int:
	get: return int(_ds().expedition_runtime().get("rng_state", 0))
	set(value): _ds().expedition_runtime()["rng_state"] = value
var runtime: Dictionary:
	get: return _ds().expedition_runtime().get("runtime", {}) as Dictionary
	set(value): _ds().expedition_runtime()["runtime"] = value
var loot: Array:
	get: return _ds().expedition_runtime().get("loot", []) as Array
	set(value): _ds().expedition_runtime()["loot"] = value
var current_choices: Array:
	get: return _ds().expedition_runtime().get("current_choices", []) as Array
	set(value): _ds().expedition_runtime()["current_choices"] = value
var current_event_id: String:
	get: return str(_ds().expedition_runtime().get("current_event_id", ""))
	set(value): _ds().expedition_runtime()["current_event_id"] = value
var pending_battle_event_id: String:
	get: return str(_ds().expedition_runtime().get("pending_battle_event_id", ""))
	set(value): _ds().expedition_runtime()["pending_battle_event_id"] = value
var pending_battle_summary: Dictionary:
	get: return _ds().expedition_runtime().get("pending_battle_summary", {}) as Dictionary
	set(value): _ds().expedition_runtime()["pending_battle_summary"] = value
var pending_battle_rewards: Array:
	get: return _ds().expedition_runtime().get("pending_battle_rewards", []) as Array
	set(value): _ds().expedition_runtime()["pending_battle_rewards"] = value
var visited_once_events: Array:
	get: return _ds().expedition_runtime().get("visited_once_events", []) as Array
	set(value): _ds().expedition_runtime()["visited_once_events"] = value
var stats: Dictionary:
	get: return _ds().expedition_runtime().get("stats", {}) as Dictionary
	set(value): _ds().expedition_runtime()["stats"] = value
var event_log: Array:
	get: return _ds().expedition_runtime().get("event_log", []) as Array
	set(value): _ds().expedition_runtime()["event_log"] = value
var player_snapshot: Dictionary:
	get: return _ds().expedition_runtime().get("player_snapshot", {}) as Dictionary
	set(value): _ds().expedition_runtime()["player_snapshot"] = value
var pending_exit_reason: String:
	get: return str(_ds().expedition_runtime().get("pending_exit_reason", ""))
	set(value): _ds().expedition_runtime()["pending_exit_reason"] = value
var expedition_id: String:
	get: return str(_ds().expedition_runtime().get("expedition_id", ""))
	set(value): _ds().expedition_runtime()["expedition_id"] = value
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
	expedition_id = _new_expedition_id()
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
	if not PlayerBattleSnapshot.collect_errors(player).is_empty():
		return {}
	var enemy := ExpeditionEventServiceScript.build_battle_enemy(event, depth)
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
		_apply_session_rewards(pending_battle_rewards)
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


func clear_pending_battle() -> void:
	pending_battle_event_id = ""
	pending_battle_summary = {}
	pending_battle_rewards = []
	if phase == "battle":
		phase = "choosing"
		generate_choices()


func finish(exit_reason: String) -> Dictionary:
	if not active:
		return {"ok": false, "error": "没有可结算的历练"}
	var reason := exit_reason
	if reason == "manual" and bool(stats.get("boss_defeated", false)):
		reason = "boss_complete"
	var elapsed_days: int = ExpeditionRulesServiceScript.elapsed_days(steps)
	var loot_lost: Array = []
	if reason == "defeated":
		if _game_state != null:
			_restore_rng()
			var loss := ExpeditionRewardServiceScript.apply_inventory_loss_on_defeat(
				_game_state.inventory, _rng
			)
			_save_rng()
			loot_lost = loss.get("lost", []) as Array
			_sync_runtime_inventory_from_game()
		var rules: Dictionary = ExpeditionRulesServiceScript.rules()
		var hp_max := float((player_snapshot.get("attrs", {}) as Dictionary).get(FightAttr.HP_MAX, 100.0))
		runtime["hp"] = maxf(float(runtime.get("hp", 0.0)), hp_max * float(rules.get("defeat_hp_floor_ratio", 0.25)))
	var result := ExpeditionResult.to_dict({
		"ok": true,
		"settlement_id": expedition_id,
		"exit_reason": reason,
		"elapsed_days": maxi(1, elapsed_days),
		"hp": float(runtime.get("hp", 0.0)),
		"mp": float(runtime.get("mp", 0.0)),
		"items": _runtime_items_for_settlement(),
		"loot": loot.duplicate(true),
		"loot_lost": loot_lost,
		"location_name": str(LocationServiceScript.by_id(location_id).get("name", location_id)),
		"stats": stats.duplicate(true),
	})
	var result_errors := ExpeditionResult.collect_errors(result)
	if not result_errors.is_empty():
		return {"ok": false, "error": result_errors[0]}
	reset()
	return result


func reset() -> void:
	_ds().reset_expedition_runtime()
	_game_state = null


func estimated_elapsed_days() -> int:
	return ExpeditionRulesServiceScript.elapsed_days(steps)


func should_go_to_result() -> bool:
	return pending_exit_reason != "" or phase == "result"


func _apply_step_after_event(event: Dictionary, extra_rewards: Array, feedback: String) -> void:
	_apply_session_rewards(extra_rewards)
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


func _apply_session_rewards(rewards: Array) -> void:
	if rewards.is_empty():
		return
	if _game_state == null:
		ExpeditionRewardServiceScript.merge_into_loot(loot, rewards)
		return
	ExpeditionRewardServiceScript.grant_to_player(_game_state, loot, rewards)
	_sync_runtime_inventory_from_game()


func _sync_runtime_inventory_from_game() -> void:
	if _game_state == null:
		return
	var inv := runtime.get("inventory", {}) as Dictionary
	for slot_v in runtime.get("item_slots", []) as Array:
		var iid := str(slot_v)
		if iid == "":
			continue
		var count := int(_game_state.inventory.get(iid, 0))
		if count > 0:
			inv[iid] = count
		else:
			inv.erase(iid)
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


func _new_expedition_id() -> String:
	return "expedition_%d_%d" % [int(Time.get_unix_time_from_system() * 1000.0), randi()]


func _rng_from_state() -> RandomNumberGenerator:
	_restore_rng()
	return _rng
