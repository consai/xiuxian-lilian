extends Node

const SAVEDATA_SCHEMA_VERSION := 2
const RUNDATA_SCHEMA_VERSION := 1

signal state_replaced

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
		out["totals"] = (out["totals"] as Dictionary).duplicate(true)
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
	return out


func reset_rundata() -> void:
	rundata = {
		"game": {
			"last_rewards": [],
			"last_lilian_summary": {},
			"last_settled_lilian_id": "",
			"active_save_slot": 0,
		},
	}


func reset_all(extra_defaults: Dictionary = {}) -> void:
	reset_savedata(extra_defaults)
	reset_rundata()
	state_replaced.emit()


func export_savedata() -> Dictionary:
	ensure_initialized()
	return savedata.duplicate(true)


func import_savedata(data: Dictionary, extra_defaults: Dictionary = {}) -> bool:
	if not validate_savedata(data):
		return false
	savedata = coalesce_savedata(data, extra_defaults)
	reset_rundata()
	state_replaced.emit()
	return true


func validate_savedata(data: Dictionary) -> bool:
	for key in ["day", "realm_index", "cultivation", "attrs", "inventory"]:
		if not data.has(key):
			return false
	return data.get("attrs") is Dictionary and data.get("inventory") is Dictionary


func game_runtime() -> Dictionary:
	ensure_initialized()
	return rundata["game"] as Dictionary


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
		"attrs": {},
		"hp": 1000.0,
		"mp": 1000.0,
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


func _coalesce_dao_savedata(out: Dictionary) -> Dictionary:
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
