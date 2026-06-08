extends Node

const SIM_PATH := "res://data/simulation.json"
const HUB_SCENE := "res://scenes/sim/cave_hub.tscn"
const InventoryServiceScript := preload("res://scripts/sim/inventory_service.gd")
const RewardServiceScript := preload("res://scripts/sim/reward_service.gd")
const LocationServiceScript := preload("res://scripts/expedition/location_service.gd")
const ExpeditionRulesServiceScript := preload("res://scripts/expedition/expedition_rules_service.gd")
const ExpeditionEventServiceScript := preload("res://scripts/expedition/expedition_event_service.gd")
func _ds() -> Node:
	return DataStore


var day: int:
	get: return int(_ds().savedata.get("day", 1))
	set(value): _ds().savedata["day"] = value
var realm_index: int:
	get: return int(_ds().savedata.get("realm_index", 0))
	set(value): _ds().savedata["realm_index"] = value
var realm_name: String:
	get: return str(_ds().savedata.get("realm_name", ""))
	set(value): _ds().savedata["realm_name"] = value
var cultivation: int:
	get: return int(_ds().savedata.get("cultivation", 0))
	set(value): _ds().savedata["cultivation"] = value
var breakthrough_at: int:
	get: return int(_ds().savedata.get("breakthrough_at", 100))
	set(value): _ds().savedata["breakthrough_at"] = value
var injury_days: int:
	get: return int(_ds().savedata.get("injury_days", 0))
	set(value): _ds().savedata["injury_days"] = value
var ling_stones: int:
	get: return int(_ds().savedata.get("ling_stones", 0))
	set(value): _ds().savedata["ling_stones"] = value
var player_name: String:
	get: return str(_ds().savedata.get("player_name", ""))
	set(value): _ds().savedata["player_name"] = value
var player_icon: String:
	get: return str(_ds().savedata.get("player_icon", ""))
	set(value): _ds().savedata["player_icon"] = value
var attrs: Dictionary:
	get: return _ds().savedata.get("attrs", {}) as Dictionary
	set(value): _ds().savedata["attrs"] = value
var hp: float:
	get: return float(_ds().savedata.get("hp", 100.0))
	set(value): _ds().savedata["hp"] = value
var mp: float:
	get: return float(_ds().savedata.get("mp", 100.0))
	set(value): _ds().savedata["mp"] = value
var unlocked_skills: Array:
	get: return _ds().savedata.get("unlocked_skills", []) as Array
	set(value): _ds().savedata["unlocked_skills"] = value
var equipped_skills: Array:
	get: return _ds().savedata.get("equipped_skills", []) as Array
	set(value): _ds().savedata["equipped_skills"] = value
var owned_equips: Array:
	get: return _ds().savedata.get("owned_equips", []) as Array
	set(value): _ds().savedata["owned_equips"] = value
var equip_slots: Array:
	get: return _ds().savedata.get("equip_slots", [-1, -1]) as Array
	set(value): _ds().savedata["equip_slots"] = value
var item_slots: Array:
	get: return _ds().savedata.get("item_slots", ["", ""]) as Array
	set(value): _ds().savedata["item_slots"] = value
var inventory: Dictionary:
	get: return _ds().savedata.get("inventory", {}) as Dictionary
	set(value): _ds().savedata["inventory"] = value
var storage: Dictionary:
	get: return _ds().savedata.get("storage", {}) as Dictionary
	set(value): _ds().savedata["storage"] = value
var storage_equips: Array:
	get: return _ds().savedata.get("storage_equips", []) as Array
	set(value): _ds().savedata["storage_equips"] = value
var activity_log: Array:
	get: return _ds().savedata.get("activity_log", []) as Array
	set(value): _ds().savedata["activity_log"] = value
var totals: Dictionary:
	get: return _ds().savedata.get("totals", {}) as Dictionary
	set(value): _ds().savedata["totals"] = value
var last_rewards: Array:
	get: return _ds().game_runtime().get("last_rewards", []) as Array
	set(value): _ds().game_runtime()["last_rewards"] = value
var last_expedition_summary: Dictionary:
	get: return _ds().game_runtime().get("last_expedition_summary", {}) as Dictionary
	set(value): _ds().game_runtime()["last_expedition_summary"] = value
var last_settled_expedition_id: String:
	get: return str(_ds().game_runtime().get("last_settled_expedition_id", ""))
	set(value): _ds().game_runtime()["last_settled_expedition_id"] = value


func _ready() -> void:
	if attrs.is_empty():
		new_game()


func new_game() -> void:
	_ds().reset_all()
	var root := JsonLoader._read_json_root_object(SIM_PATH)
	var initial := root.get("initial_player", {}) as Dictionary
	day = 1
	realm_index = 0
	cultivation = 0
	injury_days = 0
	ling_stones = 0
	player_name = str(initial.get("name", "修士"))
	player_icon = str(initial.get("icon", ""))
	attrs = (initial.get("attrs", {}) as Dictionary).duplicate(true)
	hp = float(attrs.get(FightAttr.HP_MAX, 100.0))
	mp = float(attrs.get(FightAttr.MP_MAX, 100.0))
	unlocked_skills = (initial.get("skills", []) as Array).duplicate(true)
	equipped_skills = unlocked_skills.duplicate(true)
	owned_equips = (initial.get("equips", []) as Array).duplicate(true)
	equip_slots = (initial.get("equip_slots", [-1, -1]) as Array).duplicate(true)
	item_slots = (initial.get("item_slots", ["", ""]) as Array).duplicate(true)
	inventory = (initial.get("inventory", {}) as Dictionary).duplicate(true)
	storage = (initial.get("storage", {}) as Dictionary).duplicate(true)
	storage_equips = (initial.get("storage_equips", []) as Array).duplicate(true)
	activity_log = []
	totals = {
		"battles": 0, "wins": 0, "losses": 0, "items_gained": 0,
		"expeditions": 0, "expedition_steps": 0, "max_depth": 0,
		"bosses_defeated": 0,
	}
	last_rewards = []
	last_expedition_summary = {}
	last_settled_expedition_id = ""
	_sync_realm()


func cultivate() -> int:
	var cfg := _activity_cfg("cultivate")
	var base_gain := maxi(0, int(cfg.get("cultivation_gain", 20)))
	var gain := base_gain / 2 if injury_days > 0 else base_gain
	cultivation += gain
	_finish_activity("修炼：修为 +%d" % gain, true)
	return gain


func rest() -> void:
	hp = float(attrs.get(FightAttr.HP_MAX, 100.0))
	mp = float(attrs.get(FightAttr.MP_MAX, 100.0))
	injury_days = maxi(0, injury_days - maxi(0, int(_activity_cfg("rest").get("injury_recovery", 2))))
	_finish_activity("休息：恢复气血与法力", false)


func can_breakthrough() -> bool:
	return cultivation >= breakthrough_at


func breakthrough() -> Dictionary:
	if not can_breakthrough():
		return {"ok": false, "error": "修为尚未达到突破门槛"}
	var old_name := realm_name
	realm_index += 1
	_sync_realm()
	return {
		"ok": true,
		"old_realm": old_name,
		"new_realm": realm_name,
		"day": day,
		"totals": totals.duplicate(true),
	}


func begin_expedition(location_id: String) -> Dictionary:
	var location := LocationServiceScript.by_id(location_id)
	if location.is_empty():
		return {"ok": false, "error": "未知地点"}
	return {"ok": true, "location": location}


func build_player_battle_snapshot(runtime: Dictionary) -> Dictionary:
	var runtime_inv := (runtime.get("inventory", {}) as Dictionary).duplicate(true)
	var runtime_slots := (runtime.get("item_slots", item_slots) as Array).duplicate(true)
	var skills: Array = []
	for sid_v in equipped_skills:
		skills.append({"id": int(sid_v), "cd": 0.0})
	while skills.size() < 5:
		skills.append({"id": -1, "cd": 0.0})
	var equips: Array = []
	for eid_v in equip_slots:
		var eid := int(eid_v)
		var equip_row := {"id": eid, "cd": 0.0}
		if eid > 0:
			var cfg: Dictionary = _equip_cfg(eid)
			equip_row["effects"] = (cfg.get("effects", []) as Array).duplicate(true)
			equip_row["cd_total"] = float(cfg.get("cd_total", cfg.get("cd", 0.0)))
		equips.append(equip_row)
	return {
		"name": player_name,
		"icon": player_icon,
		"hp": float(runtime.get("hp", hp)),
		"mp": float(runtime.get("mp", mp)),
		"attrs": attrs.duplicate(true),
		"skills": skills,
		"equips": equips,
		"items": InventoryServiceScript.build_battle_item_slots(runtime_inv, runtime_slots),
	}


func build_battle_init(event: Dictionary) -> Dictionary:
	var player := build_player_battle_snapshot({
		"hp": hp,
		"mp": mp,
		"inventory": inventory,
		"item_slots": item_slots,
	})
	var enemy := ExpeditionEventServiceScript.build_battle_enemy(event, int(event.get("depth", 1)))
	return {
		"player": player,
		"enemy": enemy,
		"battle_time_limit": 200.0,
		"auto_battle": {"player": false, "enemy": true},
		"spd_jitter_ratio": 0.0,
	}


func settle_expedition(result: Dictionary) -> Dictionary:
	if result.is_empty():
		return {"ok": false, "error": "缺少历练结算数据"}
	var result_errors := ExpeditionResult.collect_errors(result)
	if not result_errors.is_empty():
		return {"ok": false, "error": result_errors[0]}
	var settlement_id := str(result.get("settlement_id", "")).strip_edges()
	if settlement_id == "":
		return {"ok": false, "error": "缺少 settlement_id"}
	if settlement_id == last_settled_expedition_id:
		return {"ok": false, "error": "duplicate", "duplicate": true}
	last_settled_expedition_id = settlement_id
	var elapsed_days := maxi(1, int(result.get("elapsed_days", 1)))
	injury_days = maxi(0, injury_days - elapsed_days)
	var exit_reason := str(result.get("exit_reason", "manual"))
	hp = float(result.get("hp", hp))
	mp = float(result.get("mp", mp))
	if exit_reason == "defeated":
		var rules := ExpeditionRulesServiceScript.rules()
		hp = maxf(hp, float(attrs.get(FightAttr.HP_MAX, 100.0)) * float(rules.get("defeat_hp_floor_ratio", 0.25)))
		injury_days = maxi(injury_days, int(rules.get("defeat_injury_days", 3)))
	for item_row_v in result.get("items", []) as Array:
		if not item_row_v is Dictionary:
			continue
		var item_row := item_row_v as Dictionary
		var iid := str(item_row.get("inventory_id", ""))
		if iid == "":
			continue
		var remaining := maxi(0, int(item_row.get("count", 0)))
		if remaining > 0:
			inventory[iid] = remaining
		else:
			inventory.erase(iid)
	last_rewards = (result.get("loot", []) as Array).duplicate(true)
	for reward in last_rewards:
		totals["items_gained"] = int(totals.get("items_gained", 0)) + int((reward as Dictionary).get("count", 0))
	var stats := result.get("stats", {}) as Dictionary
	totals["expeditions"] = int(totals.get("expeditions", 0)) + 1
	totals["expedition_steps"] = int(totals.get("expedition_steps", 0)) + int(stats.get("steps", 0))
	totals["max_depth"] = maxi(int(totals.get("max_depth", 0)), int(stats.get("max_depth", 0)))
	if bool(stats.get("boss_defeated", false)):
		totals["bosses_defeated"] = int(totals.get("bosses_defeated", 0)) + 1
	totals["battles"] = int(totals.get("battles", 0)) + int(stats.get("battles", 0))
	totals["wins"] = int(totals.get("wins", 0)) + int(stats.get("wins", 0))
	totals["losses"] = int(totals.get("losses", 0)) + int(stats.get("losses", 0))
	day += elapsed_days
	var location_name := str(result.get("location_name", "未知地点"))
	var reward_labels: PackedStringArray = []
	for reward in last_rewards:
		reward_labels.append(reward_label(reward))
	var log_text := "第 %d 日：%s历练，深入 %d 层，胜 %d 场" % [
		day - elapsed_days,
		location_name,
		int(stats.get("max_depth", 0)),
		int(stats.get("wins", 0)),
	]
	if not reward_labels.is_empty():
		log_text += "，带回 %s" % "、".join(reward_labels)
	if exit_reason == "defeated":
		log_text += "（战败撤退）"
	activity_log.append({"day": day - elapsed_days, "text": log_text})
	if activity_log.size() > 30:
		activity_log = activity_log.slice(activity_log.size() - 30)
	last_settled_expedition_id = settlement_id
	last_expedition_summary = result.duplicate(true)
	return {"ok": true, "rewards": last_rewards.duplicate(true), "elapsed_days": elapsed_days}


func to_dict() -> Dictionary:
	return _ds().export_savedata()


func apply_dict(data: Dictionary) -> bool:
	if not _ds().import_savedata(data):
		return false
	var attrs_dict := attrs
	hp = clampf(hp, 0.0, float(attrs_dict.get(FightAttr.HP_MAX, 100.0)))
	mp = clampf(mp, 0.0, float(attrs_dict.get(FightAttr.MP_MAX, 100.0)))
	if Engine.get_main_loop() is SceneTree:
		var expedition := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("ExpeditionState")
		if expedition != null and expedition.has_method("reset"):
			expedition.reset()
	_sync_realm()
	return true


func reward_label(reward: Dictionary) -> String:
	var kind := str(reward.get("kind", "item"))
	if kind == "equip":
		return "%s x1" % str(_equip_cfg(int(reward.get("id", -1))).get("name", "法宝"))
	if kind == "currency":
		return "灵石 x%d" % int(reward.get("count", 0))
	var cm := _config_manager()
	var name := str(reward.get("id", ""))
	if cm != null and cm.has_method("get_item_display_name"):
		name = str(cm.call("get_item_display_name", name))
	return "%s x%d" % [name, int(reward.get("count", 0))]


func _finish_activity(text: String, reduce_injury: bool) -> void:
	if reduce_injury and injury_days > 0:
		injury_days -= 1
	activity_log.append({"day": day, "text": text})
	if activity_log.size() > 30:
		activity_log = activity_log.slice(activity_log.size() - 30)
	day += 1


func _sync_realm() -> void:
	var root := _simulation_root()
	var realms := root.get("realms", []) as Array
	var index := mini(realm_index, maxi(0, realms.size() - 1))
	var row := realms[index] as Dictionary if not realms.is_empty() else {}
	realm_name = str(row.get("name", "炼气一层"))
	breakthrough_at = maxi(cultivation + 100, int(row.get("breakthrough_at", 100))) if realm_index >= realms.size() else int(row.get("breakthrough_at", 100))


func _activity_cfg(activity_id: String) -> Dictionary:
	var activities := _simulation_root().get("activities", {}) as Dictionary
	var cfg_v: Variant = activities.get(activity_id, {})
	return cfg_v as Dictionary if cfg_v is Dictionary else {}


func _simulation_root() -> Dictionary:
	return JsonLoader._read_json_root_object(SIM_PATH)


func _equip_cfg(equip_id: int) -> Dictionary:
	var cm := _config_manager()
	if cm != null and cm.has_method("equip_by_id"):
		return cm.call("equip_by_id", equip_id) as Dictionary
	return {}


func _config_manager() -> Node:
	var loop := Engine.get_main_loop()
	if not loop is SceneTree:
		return null
	return (loop as SceneTree).root.get_node_or_null("ConfigManager")
