extends Node

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


func reset_savedata(extra_defaults: Dictionary = {}) -> void:
	savedata = _default_savedata(extra_defaults)


func start_tutorial() -> void:
	savedata["tutorial"] = _default_tutorial_savedata()


func coalesce_savedata(data: Dictionary, extra_defaults: Dictionary = {}) -> Dictionary:
	var out := _default_savedata(extra_defaults)
	_overlay_snapshot(out, data)
	# 所有读档兼容和下限修正集中在这里，业务脚本只处理当前 schema。
	out["day"] = maxi(1, int(out.get("day", 1)))
	out["realm_index"] = maxi(0, int(out.get("realm_index", 0)))
	out["cultivation"] = maxi(0, int(out.get("cultivation", 0)))
	out["cultivation_instability"] = maxi(0, int(out.get("cultivation_instability", 0)))
	out["injury_days"] = maxi(0, int(out.get("injury_days", 0)))
	out["ling_stones"] = maxi(0, int(out.get("ling_stones", 0)))
	var equip_slots := (out.get("equip_slots", [-1, -1, -1]) as Array).duplicate(true)
	while equip_slots.size() < 3:
		equip_slots.append(-1)
	out["equip_slots"] = equip_slots.slice(0, 3)
	var treasure_item_slots := (out.get("treasure_item_slots", ["", "", ""]) as Array).duplicate(true)
	while treasure_item_slots.size() < 3:
		treasure_item_slots.append("")
	out["treasure_item_slots"] = treasure_item_slots.slice(0, 3)
	var item_slots := (out.get("item_slots", ["", "", ""]) as Array).duplicate(true)
	while item_slots.size() < 3:
		item_slots.append("")
	out["item_slots"] = item_slots.slice(0, 3)
	var method_slots_v: Variant = out.get("cultivation_method_slots", {})
	var method_slots := method_slots_v as Dictionary if method_slots_v is Dictionary else {}
	var default_main := "method.hunyuan.1"
	var main_method := str(method_slots.get("main", default_main))
	# movement 旧槽位并入 support_3，保留旧存档兼容。
	out["cultivation_method_slots"] = {
		"main": main_method,
		"support_1": str(method_slots.get("support_1", "")),
		"support_2": str(method_slots.get("support_2", "")),
		"support_3": str(method_slots.get("support_3", method_slots.get("movement", ""))),
	}
	var current_method := str(out.get("current_cultivation_method_id", "")).strip_edges()
	out["current_cultivation_method_id"] = current_method if current_method != "" else main_method
	out = _coalesce_dao_savedata(out)
	var rules_v: Variant = out.get("auto_battle_rules", {})
	out["auto_battle_rules"] = (rules_v as Dictionary).duplicate(true) if rules_v is Dictionary else {}
	if not out.get("totals") is Dictionary:
		out["totals"] = _default_totals()
	else:
		var totals := (out["totals"] as Dictionary).duplicate(true)
		if totals.has("expeditions") and not totals.has("lilian_count"):
			totals["lilian_count"] = int(totals.get("expeditions", 0))
			totals.erase("expeditions")
		if totals.has("expedition_steps") and not totals.has("lilian_steps"):
			totals["lilian_steps"] = int(totals.get("expedition_steps", 0))
			totals.erase("expedition_steps")
		out["totals"] = totals
	out["map"] = _coalesce_map_savedata(out.get("map", {}))
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
		"zhuji": maxi(0, int(quality.get("zhuji", quality.get("zhuji", 0)))),
		"jindan": maxi(0, int(quality.get("jindan", quality.get("jindan", 0)))),
		"yuanying": maxi(0, int(quality.get("yuanying", quality.get("yuanying", 0)))),
	}
	out["breakthrough_attempt_cooldown_days"] = maxi(0, int(out.get("breakthrough_attempt_cooldown_days", 0)))
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
			"last_lilian_summary": {},
			"last_settled_lilian_id": "",
			"active_save_slot": 0,
		},
		"lilian": _default_lilian(),
		"zhandou": {
			"pending_init": {},
		},
		"scene": _default_scene(),
		"ui": {
			"tupo_zongjie": {},
			"lilian_exit_reason": "manual",
		},
		"map": _default_map_runtime(),
		"story": {
			"active_snapshot": {},
			"pending_event": "",
		},
	}


func reset_all(extra_defaults: Dictionary = {}) -> void:
	reset_savedata(extra_defaults)
	reset_rundata()


func export_savedata() -> Dictionary:
	ensure_initialized()
	return savedata.duplicate(true)


func import_savedata(data: Dictionary, extra_defaults: Dictionary = {}) -> bool:
	if not validate_savedata(data):
		return false
	savedata = coalesce_savedata(data, extra_defaults)
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


func lilian_runtime() -> Dictionary:
	ensure_initialized()
	if not rundata.has("lilian") and rundata.has("expedition"):
		rundata["lilian"] = rundata["expedition"]
		rundata.erase("expedition")
	if not rundata.has("lilian"):
		rundata["lilian"] = _default_lilian()
	# ponytail: 读档/热重载时合并旧 game 摘要键名
	var game_rt_v: Variant = rundata.get("game", {})
	if game_rt_v is Dictionary:
		var game_rt := game_rt_v as Dictionary
		if game_rt.has("last_expedition_summary") and not game_rt.has("last_lilian_summary"):
			game_rt["last_lilian_summary"] = game_rt.get("last_expedition_summary", {})
			game_rt.erase("last_expedition_summary")
		if game_rt.has("last_settled_expedition_id") and not game_rt.has("last_settled_lilian_id"):
			game_rt["last_settled_lilian_id"] = game_rt.get("last_settled_expedition_id", "")
			game_rt.erase("last_settled_expedition_id")
		rundata["game"] = game_rt
	return rundata["lilian"] as Dictionary


func zhandou_runtime() -> Dictionary:
	ensure_initialized()
	if not rundata.has("zhandou") and rundata.has("battle"):
		rundata["zhandou"] = rundata["battle"]
		rundata.erase("battle")
	if not rundata.has("zhandou"):
		rundata["zhandou"] = {"pending_init": {}}
	return rundata["zhandou"] as Dictionary


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
	# payload 是跨场景一次性信封；写入副本避免来源场景后续修改串味。
	var payloads_v: Variant = scene_runtime().get("payloads", {})
	var payloads: Dictionary = payloads_v as Dictionary if payloads_v is Dictionary else {}
	payloads[scene_id] = payload.duplicate(true)
	scene_runtime()["payloads"] = payloads


func take_scene_payload(scene_id: String) -> Dictionary:
	ensure_initialized()
	# take 语义：读取后立即清除，防止返回上个界面时重复消费。
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


func reset_lilian_runtime() -> void:
	ensure_initialized()
	rundata["lilian"] = _default_lilian()


func set_zhandou_pending_init(envelope: Dictionary) -> void:
	ensure_initialized()
	zhandou_runtime()["pending_init"] = envelope.duplicate(true)


func take_zhandou_pending_init() -> Dictionary:
	ensure_initialized()
	var envelope_v: Variant = zhandou_runtime().get("pending_init", {})
	zhandou_runtime()["pending_init"] = {}
	if envelope_v is Dictionary:
		return envelope_v as Dictionary
	return {}


func set_ui_lilian_exit_reason(reason: String) -> void:
	ensure_initialized()
	set_scene_payload("lilian_jiesuan", {"reason": reason})
	ui_runtime()["lilian_exit_reason"] = reason


func peek_ui_lilian_exit_reason(default_reason: String = "manual") -> String:
	ensure_initialized()
	var payload := peek_scene_payload("lilian_jiesuan")
	if not payload.is_empty():
		return str(payload.get("reason", default_reason))
	return str(ui_runtime().get("lilian_exit_reason", default_reason))


func clear_ui_lilian_exit_reason() -> void:
	ensure_initialized()
	clear_scene_payload("lilian_jiesuan")
	ui_runtime()["lilian_exit_reason"] = "manual"


func set_ui_tupo_zongjie(summary: Dictionary) -> void:
	ensure_initialized()
	set_scene_payload("tupo_zongjie", summary)
	ui_runtime()["tupo_zongjie"] = summary.duplicate(true)


func take_ui_tupo_zongjie() -> Dictionary:
	ensure_initialized()
	var summary := take_scene_payload("tupo_zongjie")
	ui_runtime()["tupo_zongjie"] = {}
	if not summary.is_empty():
		return summary
	var summary_v: Variant = ui_runtime().get("tupo_zongjie", {})
	if summary_v is Dictionary:
		return summary_v as Dictionary
	return {}


func _default_savedata(extra_defaults: Dictionary = {}) -> Dictionary:
	var out := {
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
		"character_origin_id": "",
		"character_root_id": "",
		"character_talent_id": "",
		"attrs": {},
		"hp": 1000.0,
		"mp": 1000.0,
		"knowledge": {},
		"method_mastery": {},
		"unlocked_abilities": [
			"ability.combat.qi_bolt",
			"ability.combat.wind_step",
			"ability.combat.sword_qi",
		],
		"equipped_abilities": [
			"ability.combat.qi_bolt",
			"ability.combat.wind_step",
			"ability.combat.sword_qi",
			"",
			"",
		],
		"unlocked_methods": ["method.hunyuan.1"],
		"current_cultivation_method_id": "method.hunyuan.1",
		"cultivation_method_slots": {
			"main": "method.hunyuan.1", "support_1": "", "support_2": "", "support_3": ""
		},
		"auto_battle_enabled": false,
		"auto_battle_preset": "balanced",
		"auto_battle_rules": {},
		"owned_equips": [],
		"equip_slots": [-1, -1, -1],
		"treasure_item_slots": ["", "", ""],
		"item_slots": ["", "", ""],
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
			"zhuji": 0,
			"jindan": 0,
			"yuanying": 0,
		},
		"breakthrough_attempt_cooldown_days": 0,
		"story": {
			"completed": [],
			"flags": {},
			"history": [],
			"active_snapshot": {},
		},
		"tutorial": _completed_tutorial_savedata(),
	}
	_overlay_snapshot(out, extra_defaults)
	return out


func _overlay_snapshot(target: Dictionary, overlay: Dictionary) -> void:
	for key in overlay.keys():
		var value: Variant = overlay[key]
		if value is Dictionary:
			target[key] = (value as Dictionary).duplicate(true)
		elif value is Array:
			target[key] = (value as Array).duplicate(true)
		else:
			target[key] = value


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
		"lilian_count": 0,
		"lilian_steps": 0,
		"max_difficulty": 0,
	}


func _default_tutorial_savedata() -> Dictionary:
	return {
		"chapter": "prologue_morning_practice",
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
	if (out.get("unlocked_methods", []) as Array).is_empty():
		out["unlocked_methods"] = ["method.hunyuan.1"]
	var current_method := str(out.get("current_cultivation_method_id", "")).strip_edges()
	if current_method == "":
		current_method = str((out.get("unlocked_methods", []) as Array)[0])
	out["current_cultivation_method_id"] = current_method
	var unlocked_abilities_v: Variant = out.get("unlocked_abilities")
	if not unlocked_abilities_v is Array or (unlocked_abilities_v as Array).is_empty():
		out["unlocked_abilities"] = [
			"ability.combat.qi_bolt",
			"ability.combat.wind_step",
			"ability.combat.sword_qi",
		]
	var equipped_abilities_v: Variant = out.get("equipped_abilities")
	if not equipped_abilities_v is Array or (equipped_abilities_v as Array).is_empty():
		out["equipped_abilities"] = _normalize_ability_slots(equipped_abilities_v)
	else:
		out["equipped_abilities"] = _normalize_ability_slots(equipped_abilities_v)
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


func _default_lilian() -> Dictionary:
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
		"runtime": {"hp": 0.0, "mp": 0.0, "item_slots": ["", "", ""], "inventory": {}},
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
		"generated_events": {},
		"stats": {},
		"event_log": [],
		"player_snapshot": {},
		"pending_exit_reason": "",
		"lilian_id": "",
		"start_day": 0,
	}
