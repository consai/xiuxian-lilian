extends Node

const SIM_PATH := "res://data/simulation.json"
const HUB_SCENE := "res://scenes/sim/cave_hub.tscn"

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
	var gain := 10 if injury_days > 0 else 20
	cultivation += gain
	_finish_activity("修炼：修为 +%d" % gain, true)
	return gain


func rest() -> void:
	hp = float(attrs.get(FightAttr.HP_MAX, 100.0))
	mp = float(attrs.get(FightAttr.MP_MAX, 100.0))
	injury_days = maxi(0, injury_days - 2)
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
	var encounter := EncounterService.by_id(encounter_id)
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
		equips.append({"id": int(eid_v), "cd": 0.0})
	var player := {
		"name": player_name,
		"icon": player_icon,
		"hp": hp,
		"mp": mp,
		"attrs": attrs.duplicate(true),
		"skills": skills,
		"equips": equips,
		"items": InventoryService.build_battle_item_slots(inventory, item_slots),
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
	InventoryService.sync_battle_item_counts(inventory, item_slots, runtime.get("items", []) as Array)
	totals["battles"] = int(totals.get("battles", 0)) + 1
	var won := str(summary.get("outcome", "")) == "win"
	if won:
		totals["wins"] = int(totals.get("wins", 0)) + 1
		last_rewards = RewardService.apply_rewards(self, RewardService.roll_rewards(EncounterService.by_id(pending_encounter_id)))
		for reward in last_rewards:
			totals["items_gained"] = int(totals.get("items_gained", 0)) + int((reward as Dictionary).get("count", 0))
	else:
		totals["losses"] = int(totals.get("losses", 0)) + 1
		hp = maxf(hp, float(attrs.get(FightAttr.HP_MAX, 100.0)) * 0.25)
		injury_days = maxi(injury_days, 3)
		last_rewards = []
	_finish_activity("历练%s：%s" % [EncounterService.by_id(pending_encounter_id).get("name", ""), "胜利" if won else "战败受伤"], true)
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
		return "%s x1" % str(ConfigManager.equip_by_id(int(reward.get("id", -1))).get("name", "法宝"))
	if kind == "currency":
		return "灵石 x%d" % int(reward.get("count", 0))
	return "%s x%d" % [ConfigManager.get_item_display_name(str(reward.get("id", ""))), int(reward.get("count", 0))]


func _finish_activity(text: String, reduce_injury: bool) -> void:
	if reduce_injury and injury_days > 0:
		injury_days -= 1
	activity_log.append({"day": day, "text": text})
	if activity_log.size() > 30:
		activity_log = activity_log.slice(activity_log.size() - 30)
	day += 1


func _sync_realm() -> void:
	var root := JsonLoader._read_json_root_object(SIM_PATH)
	var realms := root.get("realms", []) as Array
	var index := mini(realm_index, maxi(0, realms.size() - 1))
	var row := realms[index] as Dictionary if not realms.is_empty() else {}
	realm_name = str(row.get("name", "炼气一层"))
	breakthrough_at = maxi(cultivation + 100, int(row.get("breakthrough_at", 100))) if realm_index >= realms.size() else int(row.get("breakthrough_at", 100))
