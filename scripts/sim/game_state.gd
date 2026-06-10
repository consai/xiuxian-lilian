extends Node

const SIM_PATH := "res://data/simulation.json"
const HUB_SCENE := "res://scenes/sim/cave_hub.tscn"
const InventoryServiceScript := preload("res://scripts/sim/inventory_service.gd")
const RewardServiceScript := preload("res://scripts/sim/reward_service.gd")
const LocationServiceScript := preload("res://scripts/expedition/location_service.gd")
const WorldMapServiceScript := preload("res://scripts/map/world_map_service.gd")
const ExpeditionRulesServiceScript := preload("res://scripts/expedition/expedition_rules_service.gd")
const ExpeditionEventServiceScript := preload("res://scripts/expedition/expedition_event_service.gd")


var day: int:
	get: return int(DataStore.savedata.get("day", 1))
	set(value): DataStore.savedata["day"] = value
var realm_index: int:
	get: return int(DataStore.savedata.get("realm_index", 0))
	set(value): DataStore.savedata["realm_index"] = value
var realm_name: String:
	get: return str(DataStore.savedata.get("realm_name", ""))
	set(value): DataStore.savedata["realm_name"] = value
var cultivation: int:
	get: return int(DataStore.savedata.get("cultivation", 0))
	set(value): DataStore.savedata["cultivation"] = value
var breakthrough_at: int:
	get: return int(DataStore.savedata.get("breakthrough_at", 100))
	set(value): DataStore.savedata["breakthrough_at"] = value
var injury_days: int:
	get: return int(DataStore.savedata.get("injury_days", 0))
	set(value): DataStore.savedata["injury_days"] = value
var ling_stones: int:
	get: return int(DataStore.savedata.get("ling_stones", 0))
	set(value): DataStore.savedata["ling_stones"] = value
var player_name: String:
	get: return str(DataStore.savedata.get("player_name", ""))
	set(value): DataStore.savedata["player_name"] = value
var player_icon: String:
	get: return str(DataStore.savedata.get("player_icon", ""))
	set(value): DataStore.savedata["player_icon"] = value
var attrs: Dictionary:
	get: return DataStore.savedata.get("attrs", {}) as Dictionary
	set(value): DataStore.savedata["attrs"] = value
var hp: float:
	get: return float(DataStore.savedata.get("hp", 100.0))
	set(value): DataStore.savedata["hp"] = value
var mp: float:
	get: return float(DataStore.savedata.get("mp", 100.0))
	set(value): DataStore.savedata["mp"] = value
var unlocked_skills: Array:
	get: return DataStore.savedata.get("unlocked_skills", []) as Array
	set(value): DataStore.savedata["unlocked_skills"] = value
var equipped_skills: Array:
	get: return DataStore.savedata.get("equipped_skills", []) as Array
	set(value): DataStore.savedata["equipped_skills"] = value
var owned_equips: Array:
	get: return DataStore.savedata.get("owned_equips", []) as Array
	set(value): DataStore.savedata["owned_equips"] = value
var equip_slots: Array:
	get: return DataStore.savedata.get("equip_slots", [-1, -1]) as Array
	set(value): DataStore.savedata["equip_slots"] = value
var item_slots: Array:
	get: return DataStore.savedata.get("item_slots", ["", ""]) as Array
	set(value): DataStore.savedata["item_slots"] = value
var inventory: Dictionary:
	get: return DataStore.savedata.get("inventory", {}) as Dictionary
	set(value): DataStore.savedata["inventory"] = value
var world_state: Dictionary:
	get: return DataStore.savedata.get("world_state", {}) as Dictionary
	set(value): DataStore.savedata["world_state"] = value
var storage: Dictionary:
	get: return DataStore.savedata.get("storage", {}) as Dictionary
	set(value): DataStore.savedata["storage"] = value
var storage_equips: Array:
	get: return DataStore.savedata.get("storage_equips", []) as Array
	set(value): DataStore.savedata["storage_equips"] = value
var activity_log: Array:
	get: return DataStore.savedata.get("activity_log", []) as Array
	set(value): DataStore.savedata["activity_log"] = value
var totals: Dictionary:
	get: return DataStore.savedata.get("totals", {}) as Dictionary
	set(value): DataStore.savedata["totals"] = value
var last_rewards: Array:
	get: return DataStore.game_runtime().get("last_rewards", []) as Array
	set(value): DataStore.game_runtime()["last_rewards"] = value
var last_expedition_summary: Dictionary:
	get: return DataStore.game_runtime().get("last_expedition_summary", {}) as Dictionary
	set(value): DataStore.game_runtime()["last_expedition_summary"] = value
var last_settled_expedition_id: String:
	get: return str(DataStore.game_runtime().get("last_settled_expedition_id", ""))
	set(value): DataStore.game_runtime()["last_settled_expedition_id"] = value
var active_save_slot: int:
	get: return int(DataStore.game_runtime().get("active_save_slot", 0))
	set(value): DataStore.game_runtime()["active_save_slot"] = value
var current_city_id: String:
	get: return str(DataStore.map_savedata().get("current_city_id", ""))
	set(value): _map_savedata()["current_city_id"] = value
var map_discovered_cities: Array:
	get: return DataStore.map_savedata().get("discovered_cities", []) as Array
	set(value): _map_savedata()["discovered_cities"] = value
var map_discovered_regions: Array:
	get: return DataStore.map_savedata().get("discovered_regions", []) as Array
	set(value): _map_savedata()["discovered_regions"] = value
var map_discovered_locations: Array:
	get: return DataStore.map_savedata().get("discovered_locations", []) as Array
	set(value): _map_savedata()["discovered_locations"] = value


func _ready() -> void:
	if attrs.is_empty():
		new_game()


func new_game() -> void:
	DataStore.reset_all()
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
	world_state = {"wolf_threat": 35, "sword_tomb_opening": 0, "sect_unrest": 30}
	totals = {
		"battles": 0, "wins": 0, "losses": 0, "items_gained": 0,
		"expeditions": 0, "expedition_steps": 0, "max_difficulty": 0,
	}
	last_rewards = []
	last_expedition_summary = {}
	last_settled_expedition_id = ""
	active_save_slot = 0
	if ExpeditionState != null and ExpeditionState.has_method("reset"):
		ExpeditionState.reset()
	_initialize_map_state()
	_sync_realm()


func can_persist() -> bool:
	return ExpeditionState == null or not ExpeditionState.active


func save_game(slot: int) -> Dictionary:
	if slot == SaveService.AUTO_SAVE_SLOT:
		return {"ok": false, "error": "槽位 1 为自动存档，无法手动存入"}
	return _persist_slot(slot)


func auto_save() -> Dictionary:
	var result := _persist_slot(SaveService.AUTO_SAVE_SLOT)
	if bool(result.get("ok", false)):
		DataEvents.emit_tip_intent({
			"type": "toast",
			"text": "自动存档成功",
			"tone": "gain",
			"channel": "bar",
			"source": "auto_save",
			"ttl_ms": 2200,
			"dedupe_key": "auto_save_success",
			"dedupe_window_ms": 800,
		})
	return result


func _persist_slot(slot: int) -> Dictionary:
	if not can_persist():
		return {"ok": false, "error": "历练中无法存档，请先完成或结算"}
	var result: Dictionary = SaveService.save_slot(slot, to_dict())
	if bool(result.get("ok", false)):
		active_save_slot = slot
	return result


func load_game(slot: int) -> Dictionary:
	if not can_persist():
		return {"ok": false, "error": "历练中无法读档，请先完成或结算"}
	var loaded: Dictionary = SaveService.load_slot(slot)
	if not bool(loaded.get("ok", false)):
		return loaded
	if not apply_dict(loaded.get("game", {}) as Dictionary):
		return {"ok": false, "error": "存档数据无效"}
	active_save_slot = slot
	return {"ok": true, "slot": slot}


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


func map_data() -> Dictionary:
	return DataStore.map_savedata()


func set_map_data(data: Dictionary) -> void:
	DataStore.savedata["map"] = data.duplicate(true)


func discover_map_node(node_id: String, category: String) -> void:
	set_map_data(WorldMapServiceScript.discover_map_node(map_data(), node_id, category))


func travel_to_city(target_city_id: String, path: Array, total_days: int) -> Dictionary:
	if target_city_id == "":
		return {"ok": false, "error": "缺少目标城市"}
	var preview := WorldMapServiceScript.build_travel_preview(current_city_id, target_city_id, map_data())
	if not bool(preview.get("ok", false)):
		return preview
	var expected_path: Array = preview.get("path", []) as Array
	if expected_path.size() != path.size():
		return {"ok": false, "error": "旅行路径已变化，请重新确认"}
	for i in range(path.size()):
		if str(path[i]) != str(expected_path[i]):
			return {"ok": false, "error": "旅行路径已变化，请重新确认"}
	var elapsed := maxi(0, total_days)
	if elapsed != int(preview.get("total_days", -1)):
		return {"ok": false, "error": "旅行耗时已变化，请重新确认"}
	var next_map := WorldMapServiceScript.discover_along_path(map_data(), path)
	next_map["current_city_id"] = target_city_id
	set_map_data(next_map)
	if elapsed > 0:
		day += elapsed
		injury_days = maxi(0, injury_days - elapsed)
	activity_log.append({
		"day": day,
		"text": "旅行至%s，耗时 %d 日" % [
			str(WorldMapServiceScript.city_by_id(target_city_id).get("name", target_city_id)),
			elapsed,
		],
	})
	if activity_log.size() > 30:
		activity_log = activity_log.slice(activity_log.size() - 30)
	return {"ok": true, "city_id": target_city_id, "elapsed_days": elapsed}


func apply_battle_player_runtime(summary: Dictionary) -> void:
	var runtime_summary := summary.get("player_runtime", {}) as Dictionary
	if runtime_summary.is_empty():
		return
	if runtime_summary.has("hp"):
		hp = float(runtime_summary.get("hp", hp))
	if runtime_summary.has("mp"):
		mp = float(runtime_summary.get("mp", mp))
	var battle_items_v: Variant = runtime_summary.get("items", [])
	if battle_items_v is Array:
		InventoryServiceScript.sync_battle_item_counts(
			inventory, item_slots, battle_items_v as Array
		)


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
			var cfg: Dictionary = ConfigManager.equip_by_id(eid)
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
	var enemy := ExpeditionEventServiceScript.build_battle_enemy(event)
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
	var start_day := int(result.get("start_day", 0))
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
	var applied_loot := RewardServiceScript.apply_rewards(self, result.get("loot", []) as Array)
	last_rewards = applied_loot if not applied_loot.is_empty() else (result.get("loot", []) as Array).duplicate(true)
	for lost_v in result.get("loot_lost", []) as Array:
		if not lost_v is Dictionary:
			continue
		var lost := lost_v as Dictionary
		InventoryServiceScript.remove_item(
			inventory,
			str(lost.get("id", "")),
			int(lost.get("count", 0))
		)
	for reward in last_rewards:
		totals["items_gained"] = int(totals.get("items_gained", 0)) + int((reward as Dictionary).get("count", 0))
	var stats := result.get("stats", {}) as Dictionary
	totals["expeditions"] = int(totals.get("expeditions", 0)) + 1
	totals["expedition_steps"] = int(totals.get("expedition_steps", 0)) + int(stats.get("steps", 0))
	var max_diff := maxi(int(stats.get("max_difficulty", 0)), int(stats.get("max_depth", 0)))
	totals["max_difficulty"] = maxi(int(totals.get("max_difficulty", totals.get("max_depth", 0))), max_diff)
	totals["battles"] = int(totals.get("battles", 0)) + int(stats.get("battles", 0))
	totals["wins"] = int(totals.get("wins", 0)) + int(stats.get("wins", 0))
	totals["losses"] = int(totals.get("losses", 0)) + int(stats.get("losses", 0))
	if start_day > 0:
		day = start_day + elapsed_days
	else:
		day += elapsed_days
	var location_name := str(result.get("location_name", "未知地点"))
	var reward_labels: PackedStringArray = []
	for reward in last_rewards:
		reward_labels.append(reward_label(reward))
	var peak_diff := maxi(int(stats.get("max_difficulty", 0)), int(stats.get("max_depth", 0)))
	var log_text := "第 %d 日：%s历练，最高难度 %d，胜 %d 场" % [
		day - elapsed_days,
		location_name,
		peak_diff,
		int(stats.get("wins", 0)),
	]
	if not reward_labels.is_empty():
		log_text += "，带回 %s" % "、".join(reward_labels)
	if exit_reason == "defeated":
		log_text += "（战败撤退）"
	activity_log.append({"day": day, "text": log_text})
	if activity_log.size() > 30:
		activity_log = activity_log.slice(activity_log.size() - 30)
	last_settled_expedition_id = settlement_id
	last_expedition_summary = result.duplicate(true)
	_apply_world_changes(result.get("world_changes", []) as Array)
	auto_save()
	return {"ok": true, "rewards": last_rewards.duplicate(true), "elapsed_days": elapsed_days}


func to_dict() -> Dictionary:
	return DataStore.export_savedata()


func apply_dict(data: Dictionary) -> bool:
	if not DataStore.import_savedata(data):
		return false
	var attrs_dict := attrs
	hp = clampf(hp, 0.0, float(attrs_dict.get(FightAttr.HP_MAX, 100.0)))
	mp = clampf(mp, 0.0, float(attrs_dict.get(FightAttr.MP_MAX, 100.0)))
	if Engine.get_main_loop() is SceneTree:
		var expedition := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("ExpeditionState")
		if expedition != null and expedition.has_method("reset"):
			expedition.reset()
	_initialize_map_state()
	_sync_realm()
	return true


func reward_label(reward: Dictionary) -> String:
	var kind := str(reward.get("kind", "item"))
	if kind == "equip":
		return "%s x1" % str(ConfigManager.equip_by_id(int(reward.get("id", -1))).get("name", "法宝"))
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


func _config_manager() -> Node:
	var loop := Engine.get_main_loop()
	if not loop is SceneTree:
		return null
	return (loop as SceneTree).root.get_node_or_null("ConfigManager")


func _map_savedata() -> Dictionary:
	return DataStore.map_savedata()


func _initialize_map_state() -> void:
	var map_state := map_data()
	if str(map_state.get("current_city_id", "")) == "":
		map_state["current_city_id"] = WorldMapServiceScript.starter_city_id()
	set_map_data(WorldMapServiceScript.apply_starter_discovery(map_data()))


func _apply_world_changes(changes: Array) -> void:
	for change_v in changes:
		if not change_v is Dictionary:
			continue
		var change := change_v as Dictionary
		var key := str(change.get("state", ""))
		if not world_state.has(key):
			continue
		world_state[key] = clampi(int(world_state.get(key, 0)) + int(change.get("value", 0)), 0, 100)
