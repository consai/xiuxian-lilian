extends Node

const SAVEDATA_SCHEMA_VERSION := 1
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
	out["injury_days"] = maxi(0, int(out.get("injury_days", 0)))
	out["ling_stones"] = maxi(0, int(out.get("ling_stones", 0)))
	var equip_slots := (out.get("equip_slots", [-1, -1]) as Array).duplicate(true)
	while equip_slots.size() < 2:
		equip_slots.append(-1)
	out["equip_slots"] = equip_slots.slice(0, 2)
	var item_slots := (out.get("item_slots", ["", ""]) as Array).duplicate(true)
	while item_slots.size() < 2:
		item_slots.append("")
	out["item_slots"] = item_slots.slice(0, 2)
	if not out.get("totals") is Dictionary:
		out["totals"] = _default_totals()
	return out


func reset_rundata() -> void:
	rundata = {
		"game": {
			"last_rewards": [],
			"last_expedition_summary": {},
			"last_settled_expedition_id": "",
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
		"breakthrough_at": 100,
		"injury_days": 0,
		"ling_stones": 0,
		"player_name": "",
		"player_icon": "",
		"attrs": {},
		"hp": 100.0,
		"mp": 100.0,
		"unlocked_skills": [],
		"equipped_skills": [],
		"owned_equips": [],
		"equip_slots": [-1, -1],
		"item_slots": ["", ""],
		"inventory": {},
		"storage": {},
		"storage_equips": [],
		"activity_log": [],
		"totals": _default_totals(),
	}


func _default_totals() -> Dictionary:
	return {
		"battles": 0,
		"wins": 0,
		"losses": 0,
		"items_gained": 0,
		"expeditions": 0,
		"expedition_steps": 0,
		"max_depth": 0,
		"bosses_defeated": 0,
	}


func _default_scene() -> Dictionary:
	return {
		"current_id": "",
		"previous_id": "",
		"transitioning": false,
		"payloads": {},
		"history": [],
	}


func _default_expedition() -> Dictionary:
	return {
		"active": false,
		"phase": "idle",
		"location_id": "",
		"depth": 1,
		"steps": 0,
		"seed": 0,
		"rng_state": 0,
		"runtime": {"hp": 0.0, "mp": 0.0, "item_slots": ["", ""], "inventory": {}},
		"loot": [],
		"current_choices": [],
		"current_event_id": "",
		"pending_battle_event_id": "",
		"pending_battle_summary": {},
		"pending_battle_rewards": [],
		"visited_once_events": [],
		"stats": {},
		"event_log": [],
		"player_snapshot": {},
		"pending_exit_reason": "",
		"expedition_id": "",
	}
