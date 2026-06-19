extends Node

const CharacterStatsScript := preload("res://scripts/sim/character_stats.gd")
const KnowledgeServiceScript := preload("res://scripts/dao/knowledge_service.gd")
const AlchemyServiceScript := preload("res://scripts/sim/alchemy_service.gd")

const SAVEDATA_SCHEMA_VERSION := 2
const RUNDATA_SCHEMA_VERSION := 1

var savedata: Dictionary = {}
var rundata: Dictionary = {}


func _ready() -> void:
	ensure_initialized()


func ensure_initialized() -> void:
	if savedata.is_empty():
		reset_savedata()
	if rundata.is_empty():
		reset_rundata()


func reset_savedata() -> void:
	savedata = _default_savedata()


func coalesce_savedata(data: Dictionary) -> Dictionary:
	var out := _default_savedata()
	for key in data.keys():
		var value: Variant = data[key]
		if value is Dictionary:
			out[key] = (value as Dictionary).duplicate(true)
		elif value is Array:
			out[key] = (value as Array).duplicate(true)
		else:
			out[key] = value
	out["day"] = maxi(1, int(out.get("day", 1)))
	out["realm_index"] = maxi(0, int(out.get("realm_index", 0)))
	out["cultivation"] = maxi(0, int(out.get("cultivation", 0)))
	out["cultivation_instability"] = maxi(0, int(out.get("cultivation_instability", 0)))
	out["injury_days"] = maxi(0, int(out.get("injury_days", 0)))
	out["ling_stones"] = maxi(0, int(out.get("ling_stones", 0)))
	var equip_slots := (out.get("equip_slots", [-1, -1]) as Array).duplicate(true)
	while equip_slots.size() < 2:
		equip_slots.append(-1)
	out["equip_slots"] = equip_slots.slice(0, 2)
	var treasure_item_slots := (out.get("treasure_item_slots", ["", ""]) as Array).duplicate(true)
	while treasure_item_slots.size() < 2:
		treasure_item_slots.append("")
	out["treasure_item_slots"] = treasure_item_slots.slice(0, 2)
	var item_slots := (out.get("item_slots", ["", ""]) as Array).duplicate(true)
	while item_slots.size() < 2:
		item_slots.append("")
	out["item_slots"] = item_slots.slice(0, 2)
	var method_slots_v: Variant = out.get("cultivation_method_slots", {})
	var method_slots := method_slots_v as Dictionary if method_slots_v is Dictionary else {}
	var default_main := "method.hunyuan.1"
	var main_method := str(method_slots.get("main", default_main))
	out["cultivation_method_slots"] = {
		"main": main_method,
		"support_1": str(method_slots.get("support_1", "")),
		"support_2": str(method_slots.get("support_2", "")),
		"movement": str(method_slots.get("movement", "")),
	}
	out = _coalesce_dao_savedata(out)
	var rules_v: Variant = out.get("auto_battle_rules", {})
	out["auto_battle_rules"] = (rules_v as Dictionary).duplicate(true) if rules_v is Dictionary else {}
	if not out.get("totals") is Dictionary:
		out["totals"] = _default_totals()
	out["map"] = _coalesce_map_savedata(out.get("map", {}))
	out["foundations"] = CharacterStatsScript.normalize_foundations(out.get("foundations", {}))
	out["aptitudes"] = CharacterStatsScript.normalize_aptitudes(out.get("aptitudes", {}))
	var bonuses_v: Variant = out.get("breakthrough_bonuses", {})
	var bonuses := bonuses_v as Dictionary if bonuses_v is Dictionary else {}
	out["breakthrough_bonuses"] = {
		"pills": maxi(0, int(bonuses.get("pills", 0))),
		"mind": maxi(0, int(bonuses.get("mind", 0))),
		"other": maxi(0, int(bonuses.get("other", 0))),
	}
	var quality_v: Variant = out.get("realm_quality", {})
	var quality := quality_v as Dictionary if quality_v is Dictionary else {}
	out["realm_quality"] = {
		"foundation": maxi(0, int(quality.get("foundation", 0))),
		"core": maxi(0, int(quality.get("core", 0))),
		"nascent": maxi(0, int(quality.get("nascent", 0))),
	}
	out["breakthrough_attempt_cooldown_days"] = maxi(0, int(out.get("breakthrough_attempt_cooldown_days", 0)))
	out["alchemy"] = AlchemyServiceScript.normalize_state(out.get("alchemy", {}))
	out["story"] = _coalesce_story_savedata(out.get("story", {}))
	if data.has("tutorial"):
		out["tutorial"] = _coalesce_tutorial_savedata(data.get("tutorial", {}))
	else:
		# Existing saves predate onboarding and must not be forced through the prologue.
		out["tutorial"] = _completed_tutorial_savedata()
	return out


func reset_rundata() -> void:
	rundata = {
		"game": {
			"last_rewards": [],
			"last_expedition_summary": {},
			"last_settled_expedition_id": "",
			"active_save_slot": 0,
		},
		"expedition": _default_expedition(),
		"battle": {
			"pending_init": {},
		},
		"scene": _default_scene(),
		"ui": {
			"breakthrough_summary": {},
			"expedition_exit_reason": "manual",
		},
		"map": _default_map_runtime(),
		"story": {
			"active_snapshot": {},
			"pending_event": "",
		},
	}


func reset_all() -> void:
	reset_savedata()
	reset_rundata()


func export_savedata() -> Dictionary:
	ensure_initialized()
	return savedata.duplicate(true)


func import_savedata(data: Dictionary) -> bool:
	if not validate_savedata(data):
		return false
	savedata = coalesce_savedata(data)
	reset_rundata()
	return true


func validate_savedata(data: Dictionary) -> bool:
	for key in ["day", "realm_index", "cultivation", "attrs", "inventory"]:
		if not data.has(key):
			return false
	return data.get("attrs") is Dictionary and data.get("inventory") is Dictionary


func game_runtime() -> Dictionary:
	ensure_initialized()
	return rundata["game"] as Dictionary


func expedition_runtime() -> Dictionary:
	ensure_initialized()
	return rundata["expedition"] as Dictionary


func battle_runtime() -> Dictionary:
	ensure_initialized()
	return rundata["battle"] as Dictionary


func ui_runtime() -> Dictionary:
	ensure_initialized()
	return rundata["ui"] as Dictionary


func map_savedata() -> Dictionary:
	ensure_initialized()
	return _coalesce_map_savedata(savedata.get("map", {}))


func map_runtime() -> Dictionary:
	ensure_initialized()
	if not rundata.has("map"):
		rundata["map"] = _default_map_runtime()
	return rundata["map"] as Dictionary


func story_runtime() -> Dictionary:
	ensure_initialized()
	if not rundata.has("story"):
		rundata["story"] = {"active_snapshot": {}, "pending_event": ""}
	return rundata["story"] as Dictionary


func scene_runtime() -> Dictionary:
	ensure_initialized()
	if not rundata.has("scene"):
		rundata["scene"] = _default_scene()
	return rundata["scene"] as Dictionary


func reset_scene_runtime() -> void:
	ensure_initialized()
	rundata["scene"] = _default_scene()


func set_scene_payload(scene_id: String, payload: Dictionary) -> void:
	ensure_initialized()
	var payloads_v: Variant = scene_runtime().get("payloads", {})
	var payloads: Dictionary = payloads_v as Dictionary if payloads_v is Dictionary else {}
	payloads[scene_id] = payload.duplicate(true)
	scene_runtime()["payloads"] = payloads


func take_scene_payload(scene_id: String) -> Dictionary:
	ensure_initialized()
	var payloads_v: Variant = scene_runtime().get("payloads", {})
	var payloads: Dictionary = payloads_v as Dictionary if payloads_v is Dictionary else {}
	var payload_v: Variant = payloads.get(scene_id, {})
	payloads.erase(scene_id)
	scene_runtime()["payloads"] = payloads
	if payload_v is Dictionary:
		return (payload_v as Dictionary).duplicate(true)
	return {}


func peek_scene_payload(scene_id: String) -> Dictionary:
	ensure_initialized()
	var payloads_v: Variant = scene_runtime().get("payloads", {})
	var payloads: Dictionary = payloads_v as Dictionary if payloads_v is Dictionary else {}
	var payload_v: Variant = payloads.get(scene_id, {})
	if payload_v is Dictionary:
		return (payload_v as Dictionary).duplicate(true)
	return {}


func clear_scene_payload(scene_id: String) -> void:
	ensure_initialized()
	var payloads_v: Variant = scene_runtime().get("payloads", {})
	var payloads: Dictionary = payloads_v as Dictionary if payloads_v is Dictionary else {}
	payloads.erase(scene_id)
	scene_runtime()["payloads"] = payloads


func reset_expedition_runtime() -> void:
	ensure_initialized()
	rundata["expedition"] = _default_expedition()


func set_battle_pending_init(envelope: Dictionary) -> void:
	ensure_initialized()
	battle_runtime()["pending_init"] = envelope.duplicate(true)


func take_battle_pending_init() -> Dictionary:
	ensure_initialized()
	var envelope_v: Variant = battle_runtime().get("pending_init", {})
	battle_runtime()["pending_init"] = {}
	if envelope_v is Dictionary:
		return envelope_v as Dictionary
	return {}


func set_ui_expedition_exit_reason(reason: String) -> void:
	ensure_initialized()
	set_scene_payload("expedition_result", {"reason": reason})
	ui_runtime()["expedition_exit_reason"] = reason


func peek_ui_expedition_exit_reason(default_reason: String = "manual") -> String:
	ensure_initialized()
	var payload := peek_scene_payload("expedition_result")
	if not payload.is_empty():
		return str(payload.get("reason", default_reason))
	return str(ui_runtime().get("expedition_exit_reason", default_reason))


func clear_ui_expedition_exit_reason() -> void:
	ensure_initialized()
	clear_scene_payload("expedition_result")
	ui_runtime()["expedition_exit_reason"] = "manual"


func set_ui_breakthrough_summary(summary: Dictionary) -> void:
	ensure_initialized()
	set_scene_payload("breakthrough_summary", summary)
	ui_runtime()["breakthrough_summary"] = summary.duplicate(true)


func take_ui_breakthrough_summary() -> Dictionary:
	ensure_initialized()
	var summary := take_scene_payload("breakthrough_summary")
	ui_runtime()["breakthrough_summary"] = {}
	if not summary.is_empty():
		return summary
	var summary_v: Variant = ui_runtime().get("breakthrough_summary", {})
	if summary_v is Dictionary:
		return summary_v as Dictionary
	return {}


func _default_savedata() -> Dictionary:
	return {
		"day": 1,
		"realm_index": 0,
		"realm_name": "",
		"cultivation": 0,
		"cultivation_instability": 0,
		"breakthrough_at": 300,
		"injury_days": 0,
		"ling_stones": 0,
		"player_name": "",
		"player_icon": "",
		"foundations": CharacterStatsScript.default_foundations(),
		"aptitudes": CharacterStatsScript.default_aptitudes(),
		"attrs": {},
		"hp": 1000.0,
		"mp": 1000.0,
		"knowledge": {},
		"method_mastery": {},
		"unlocked_abilities": ["ability.combat.qi_bolt"],
		"equipped_abilities": ["", "ability.combat.qi_bolt", "", "", ""],
		"unlocked_methods": ["method.hunyuan.1"],
		"cultivation_method_slots": {
			"main": "method.hunyuan.1", "support_1": "", "support_2": "", "movement": ""
		},
		"auto_battle_enabled": true,
		"auto_battle_preset": "balanced",
		"auto_battle_rules": {},
		"owned_equips": [],
		"equip_slots": [-1, -1],
		"treasure_item_slots": ["", ""],
		"item_slots": ["", ""],
		"inventory": {},
		"storage": {},
		"storage_equips": [],
		"activity_log": [],
		"map": _default_map_savedata(),
		"totals": _default_totals(),
		"breakthrough_bonuses": {
			"pills": 0,
			"mind": 0,
			"other": 0,
		},
		"realm_quality": {
			"foundation": 0,
			"core": 0,
			"nascent": 0,
		},
		"breakthrough_attempt_cooldown_days": 0,
		"alchemy": AlchemyServiceScript.default_state(),
		"story": {
			"completed": [],
			"flags": {},
			"history": [],
			"active_snapshot": {},
		},
		"tutorial": _default_tutorial_savedata(),
	}


func _default_map_savedata() -> Dictionary:
	return {
		"current_city_id": "qingshi_market",
		"discovered_cities": ["qingshi_market"],
		"discovered_regions": [],
		"discovered_locations": [],
		"vanished_nodes": [],
		"route_states": {},
		"region_exploration": {},
	}


func _coalesce_map_savedata(data: Variant) -> Dictionary:
	var out := _default_map_savedata()
	if not data is Dictionary:
		return out
	var src := data as Dictionary
	for key in ["current_city_id"]:
		if src.has(key):
			out[key] = str(src.get(key, out[key]))
	for key in ["discovered_cities", "discovered_regions", "discovered_locations", "vanished_nodes"]:
		if src.get(key) is Array:
			out[key] = (src.get(key) as Array).duplicate()
	if src.get("route_states") is Dictionary:
		out["route_states"] = (src.get("route_states") as Dictionary).duplicate(true)
	if src.get("region_exploration") is Dictionary:
		out["region_exploration"] = (src.get("region_exploration") as Dictionary).duplicate(true)
	return out


func _default_map_runtime() -> Dictionary:
	return {
		"selected_city_id": "",
		"selected_region_id": "",
		"selected_location_id": "",
		"pending_travel": {},
		"wilderness_options": {},
	}


func _default_totals() -> Dictionary:
	return {
		"battles": 0,
		"wins": 0,
		"losses": 0,
		"items_gained": 0,
		"expeditions": 0,
		"expedition_steps": 0,
		"max_difficulty": 0,
	}


func _default_tutorial_savedata() -> Dictionary:
	return {
		"chapter": "prologue_lost_master",
		"step": "T00",
		"completed": false,
		"skipped": false,
		"flags": {},
		"seen_context_tips": [],
	}


func _completed_tutorial_savedata() -> Dictionary:
	var out := _default_tutorial_savedata()
	out["step"] = "T10"
	out["completed"] = true
	return out


func _coalesce_tutorial_savedata(data: Variant) -> Dictionary:
	var out := _default_tutorial_savedata()
	if not data is Dictionary:
		return out
	var src := data as Dictionary
	for key in ["chapter", "step"]:
		out[key] = str(src.get(key, out[key]))
	for key in ["completed", "skipped"]:
		out[key] = bool(src.get(key, out[key]))
	if src.get("flags") is Dictionary:
		out["flags"] = (src.get("flags") as Dictionary).duplicate(true)
	if src.get("seen_context_tips") is Array:
		out["seen_context_tips"] = (src.get("seen_context_tips") as Array).duplicate()
	return out


func _coalesce_story_savedata(data: Variant) -> Dictionary:
	var out := {"completed": [], "flags": {}, "history": [], "active_snapshot": {}}
	if not data is Dictionary:
		return out
	var src := data as Dictionary
	if src.get("completed") is Array:
		out["completed"] = (src.get("completed") as Array).duplicate()
	if src.get("flags") is Dictionary:
		out["flags"] = (src.get("flags") as Dictionary).duplicate(true)
	if src.get("history") is Array:
		out["history"] = (src.get("history") as Array).duplicate(true)
	if src.get("active_snapshot") is Dictionary:
		out["active_snapshot"] = (src.get("active_snapshot") as Dictionary).duplicate(true)
	return out


func _default_scene() -> Dictionary:
	return {
		"current_id": "",
		"previous_id": "",
		"transitioning": false,
		"payloads": {},
		"history": [],
	}


func _coalesce_dao_savedata(out: Dictionary) -> Dictionary:
	if not out.get("knowledge") is Dictionary:
		out["knowledge"] = {}
	if not out.get("method_mastery") is Dictionary:
		out["method_mastery"] = {}
	var methods_v: Variant = out.get("unlocked_methods", [])
	if methods_v is Array:
		var methods: Array = []
		for method_id_v in methods_v as Array:
			var method_id := str(method_id_v)
			if method_id != "" and not methods.has(method_id):
				methods.append(method_id)
		out["unlocked_methods"] = methods
	var unlocked_abilities_v: Variant = out.get("unlocked_abilities")
	if not unlocked_abilities_v is Array or (unlocked_abilities_v as Array).is_empty():
		out["unlocked_abilities"] = ["ability.combat.qi_bolt"]
	var equipped_abilities_v: Variant = out.get("equipped_abilities")
	if not equipped_abilities_v is Array or (equipped_abilities_v as Array).is_empty():
		out["equipped_abilities"] = _normalize_ability_slots(equipped_abilities_v)
	else:
		out["equipped_abilities"] = _normalize_ability_slots(equipped_abilities_v)
	if (out.get("knowledge", {}) as Dictionary).is_empty():
		KnowledgeServiceScript.grant_level(out, "foundation.breathing", 1)
	return out


static func _normalize_ability_slots(raw: Variant) -> Array:
	var slots: Array = []
	if raw is Array:
		for entry_v in raw as Array:
			var entry := str(entry_v).strip_edges()
			if entry == "-1" or entry == "":
				slots.append("")
			else:
				slots.append(entry)
	while slots.size() < 5:
		slots.append("")
	return slots.slice(0, 5)


func _default_expedition() -> Dictionary:
	return {
		"active": false,
		"phase": "idle",
		"location_id": "",
		"journey_step": 0,
		"auto_advance": true,
		"steps": 0,
		"days": 0,
		"days_without_event": 0,
		"seed": 0,
		"rng_state": 0,
		"runtime": {"hp": 0.0, "mp": 0.0, "item_slots": ["", ""], "inventory": {}},
		"loot": [],
		"current_choices": [],
		"pending_decision_event": {},
		"current_event_id": "",
		"pending_battle_event_id": "",
		"pending_battle_summary": {},
		"pending_battle_rewards": [],
		"visited_once_events": [],
		"map_nodes": [],
		"map_edges": [],
		"current_node_id": "",
		"available_node_ids": [],
		"visited_node_ids": [],
		"resolved_node_events": {},
		"stats": {},
		"event_log": [],
		"player_snapshot": {},
		"pending_exit_reason": "",
		"expedition_id": "",
		"start_day": 0,
	}
