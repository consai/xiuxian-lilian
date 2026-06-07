extends Node

const SIM_PATH := "res://data/simulation.json"
const HUB_SCENE := "res://scenes/sim/cave_hub.tscn"
const InventoryServiceScript := preload("res://scripts/sim/inventory_service.gd")
const EncounterServiceScript := preload("res://scripts/sim/encounter_service.gd")
const RewardServiceScript := preload("res://scripts/sim/reward_service.gd")

var day := 1
var realm_index := 0
var realm_name := ""
var cultivation := 0
var breakthrough_at := 100
var injury_days := 0
var ling_stones := 0
var player_name := ""
var player_icon := ""
var attrs: Dictionary = {}
var hp := 100.0
var mp := 100.0
var unlocked_skills: Array = []
var equipped_skills: Array = []
var owned_equips: Array = []
var equip_slots: Array = [-1, -1]
var item_slots: Array = ["", ""]
var inventory: Dictionary = {}
var activity_log: Array = []
var totals := {"battles": 0, "wins": 0, "losses": 0, "items_gained": 0}
var pending_encounter_id := ""
var pending_battle_summary: Dictionary = {}
var last_rewards: Array = []


func _ready() -> void:
	if attrs.is_empty():
		new_game()


func new_game() -> void:
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
	activity_log = []
	totals = {"battles": 0, "wins": 0, "losses": 0, "items_gained": 0}
	pending_encounter_id = ""
	pending_battle_summary = {}
	last_rewards = []
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


func start_encounter(encounter_id: String, tree: SceneTree) -> bool:
	var encounter: Dictionary = EncounterServiceScript.by_id(encounter_id)
	if encounter.is_empty():
		return false
	pending_encounter_id = encounter_id
	pending_battle_summary = {}
	last_rewards = []
	return BattleInitData.goto_fight_scene(tree, build_battle_init(encounter), "res://scenes/fightScene.tscn")


func build_battle_init(encounter: Dictionary) -> Dictionary:
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
	var player := {
		"name": player_name,
		"icon": player_icon,
		"hp": hp,
		"mp": mp,
		"attrs": attrs.duplicate(true),
		"skills": skills,
		"equips": equips,
		"items": InventoryServiceScript.build_battle_item_slots(inventory, item_slots),
	}
	var enemy := (encounter.get("enemy", {}) as Dictionary).duplicate(true)
	var enemy_skills: Array = []
	for sid_v in enemy.get("skills", [0]) as Array:
		enemy_skills.append({"id": int(sid_v), "cd": 0.0})
	enemy["skills"] = enemy_skills
	enemy["items"] = []
	enemy["equips"] = []
	return {
		"player": player,
		"enemy": enemy,
		"battle_time_limit": 200.0,
		"auto_battle": {"player": false, "enemy": true},
		"spd_jitter_ratio": 0.0,
	}


func receive_battle_summary(summary: Dictionary) -> void:
	pending_battle_summary = summary.duplicate(true)


func settle_pending_battle() -> Dictionary:
	if pending_battle_summary.is_empty() or pending_encounter_id == "":
		return {"ok": false}
	var summary := pending_battle_summary
	var runtime := summary.get("player_runtime", {}) as Dictionary
	hp = float(runtime.get("hp", hp))
	mp = float(runtime.get("mp", mp))
	InventoryServiceScript.sync_battle_item_counts(inventory, item_slots, runtime.get("items", []) as Array)
	totals["battles"] = int(totals.get("battles", 0)) + 1
	var won := str(summary.get("outcome", "")) == "win"
	if won:
		totals["wins"] = int(totals.get("wins", 0)) + 1
		last_rewards = RewardServiceScript.apply_rewards(
			self,
			RewardServiceScript.roll_rewards(EncounterServiceScript.by_id(pending_encounter_id))
		)
		for reward in last_rewards:
			totals["items_gained"] = int(totals.get("items_gained", 0)) + int((reward as Dictionary).get("count", 0))
		_finish_activity("历练%s：胜利" % EncounterServiceScript.by_id(pending_encounter_id).get("name", ""), true)
	else:
		totals["losses"] = int(totals.get("losses", 0)) + 1
		var rules := _simulation_root().get("rules", {}) as Dictionary
		hp = maxf(hp, float(attrs.get(FightAttr.HP_MAX, 100.0)) * float(rules.get("battle_loss_hp_floor_ratio", 0.25)))
		injury_days = maxi(injury_days, int(rules.get("battle_loss_injury_days", 3)))
		last_rewards = []
		_finish_activity("历练%s：战败受伤" % EncounterServiceScript.by_id(pending_encounter_id).get("name", ""), false)
	pending_encounter_id = ""
	pending_battle_summary = {}
	return {"ok": true, "won": won, "rewards": last_rewards.duplicate(true)}


func to_dict() -> Dictionary:
	return {
		"day": day, "realm_index": realm_index, "realm_name": realm_name,
		"cultivation": cultivation, "breakthrough_at": breakthrough_at,
		"injury_days": injury_days, "ling_stones": ling_stones,
		"player_name": player_name, "player_icon": player_icon,
		"attrs": attrs.duplicate(true), "hp": hp, "mp": mp,
		"unlocked_skills": unlocked_skills.duplicate(true),
		"equipped_skills": equipped_skills.duplicate(true),
		"owned_equips": owned_equips.duplicate(true),
		"equip_slots": equip_slots.duplicate(true), "item_slots": item_slots.duplicate(true),
		"inventory": inventory.duplicate(true), "activity_log": activity_log.duplicate(true),
		"totals": totals.duplicate(true)
	}


func apply_dict(data: Dictionary) -> bool:
	for key in ["day", "realm_index", "cultivation", "attrs", "inventory"]:
		if not data.has(key):
			return false
	day = maxi(1, int(data["day"]))
	realm_index = maxi(0, int(data["realm_index"]))
	cultivation = maxi(0, int(data["cultivation"]))
	injury_days = maxi(0, int(data.get("injury_days", 0)))
	ling_stones = maxi(0, int(data.get("ling_stones", 0)))
	player_name = str(data.get("player_name", "修士"))
	player_icon = str(data.get("player_icon", ""))
	attrs = (data["attrs"] as Dictionary).duplicate(true)
	hp = clampf(float(data.get("hp", attrs.get(FightAttr.HP_MAX, 100.0))), 0.0, float(attrs.get(FightAttr.HP_MAX, 100.0)))
	mp = clampf(float(data.get("mp", attrs.get(FightAttr.MP_MAX, 100.0))), 0.0, float(attrs.get(FightAttr.MP_MAX, 100.0)))
	unlocked_skills = (data.get("unlocked_skills", []) as Array).duplicate(true)
	equipped_skills = (data.get("equipped_skills", unlocked_skills) as Array).duplicate(true)
	owned_equips = (data.get("owned_equips", []) as Array).duplicate(true)
	equip_slots = (data.get("equip_slots", [-1, -1]) as Array).duplicate(true)
	item_slots = (data.get("item_slots", ["", ""]) as Array).duplicate(true)
	while equip_slots.size() < 2:
		equip_slots.append(-1)
	equip_slots = equip_slots.slice(0, 2)
	while item_slots.size() < 2:
		item_slots.append("")
	item_slots = item_slots.slice(0, 2)
	inventory = (data["inventory"] as Dictionary).duplicate(true)
	activity_log = (data.get("activity_log", []) as Array).duplicate(true)
	totals = (data.get("totals", {}) as Dictionary).duplicate(true)
	pending_encounter_id = ""
	pending_battle_summary = {}
	last_rewards = []
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
